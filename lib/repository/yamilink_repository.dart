import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/protocol/frame.dart';
import '../core/state/peer_manager.dart';
import '../core/state/session_manager.dart';
import '../core/transport/mock_simulator.dart';
import '../core/transport/transport_interface.dart';
import '../core/transport/win_udp_transport.dart';
import '../ffi_bridge.dart';
import '../models.dart';

class YamiLinkRepository extends ChangeNotifier {
  final EphemeralProfile profile;

  late final PeerManager _peerManager;
  late final SessionManager _sessionManager;

  late final DiscoveryTransport _discoveryTransport;
  late final MessageTransport _messageTransport;

  bool _isScanning = false;
  bool _relayEnabled = true;
  int _packetsProcessed = 0;
  double _signalStrength = 1.0;

  Timer? _sweepTimer;
  Timer? _simStrengthTimer;
  final String _sessionId = List.generate(16, (_) => Random().nextInt(16).toRadixString(16)).join();
  int _nextMessageId = 100;

  YamiLinkRepository({required this.profile}) {
    // 1. Initialize FFI core if supported, otherwise fallback to simulator
    YamiLinkFfiBridge.instance.load();

    if (YamiLinkFfiBridge.instance.isSupported) {
      final winTransport = WinUdpTransport();
      _discoveryTransport = winTransport;
      _messageTransport = winTransport;

      YamiLinkFfiBridge.instance.start(profile.alias, profile.avatarSeed);
      _packetsProcessed = 5;
    } else {
      final sim = MockSimulatorTransport(
        userAlias: profile.alias,
        userSeed: profile.avatarSeed,
        userNodeId: profile.id,
      );
      _discoveryTransport = sim;
      _messageTransport = sim;
      _packetsProcessed = 142;

      _simStrengthTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _signalStrength = 0.75 + Random().nextDouble() * 0.2;
        notifyListeners();
      });
    }

    // 2. Initialize State managers
    _peerManager = PeerManager(onChanged: notifyListeners);
    _sessionManager = SessionManager(
      onChanged: notifyListeners,
      onRetransmit: (Frame frame) {
        final frameBytes = utf8.encode(frame.serialize());
        _messageTransport.sendDirect(frame.recipientId, frameBytes);
        _packetsProcessed++;
      },
    );

    // 3. Register Data Receiver Callback
    _messageTransport.registerReceiveCallback((String senderHash, Uint8List packetBytes) {
      _packetsProcessed++;
      
      final rawText = utf8.decode(packetBytes);
      try {
        final frame = Frame.deserialize(rawText);
        
        // Skip loopback messages from ourselves
        if (frame.senderId == profile.id) return;

        // Retrieve sender alias from current discovered peers
        String senderAlias = 'External Peer';
        for (var p in _peerManager.peers) {
          if (p.id == frame.senderId) {
            senderAlias = p.alias;
            break;
          }
        }
        
        _sessionManager.processIncomingFrame(frame, senderAlias);
      } catch (e) {
        debugPrint('Failed to parse incoming protocol frame: $e');
      }
    });

    // 4. Launch simulated history (fallback only)
    if (!YamiLinkFfiBridge.instance.isSupported) {
      _loadInitialSimulatedHistory();
    }

    // Start liveness sweep checks
    _sweepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _peerManager.sweepStalePeers();
    });
  }

  // --- Getters mirroring SimulationService interface ---
  List<Peer> get peers => _peerManager.peers;
  List<Message> get roomMessages => _sessionManager.roomMessages;
  List<Message> getDirectMessages(String peerId) => _sessionManager.getDirectMessages(peerId);
  bool get isScanning => _isScanning;
  bool get relayEnabled => _relayEnabled;
  int get packetsProcessed => _packetsProcessed;
  double get signalStrength => _signalStrength;

  // --- Actions ---

  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    _discoveryTransport.startDiscovery(
      onPeerFound: (nodeHash, alias, seed, rssi) {
        _peerManager.handlePeerFound(id: nodeHash, alias: alias, seed: seed, signal: rssi);
        _packetsProcessed++;
      },
      onPeerLost: (nodeHash) {
        _peerManager.handlePeerLost(nodeHash);
        _packetsProcessed++;
      },
    );
  }

  void stopScanning() {
    _isScanning = false;
    _discoveryTransport.stopDiscovery();
    notifyListeners();
  }

  void toggleRelay() {
    _relayEnabled = !_relayEnabled;
    _packetsProcessed += 2;
    notifyListeners();
  }

  void sendBroadcastMessage(String content) {
    if (content.trim().isEmpty) return;

    final frame = Frame(
      type: FrameType.roomMsg,
      senderId: profile.id,
      recipientId: '*',
      sessionId: _sessionId,
      messageId: _nextMessageId++,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payloadBody: content,
    );

    final frameBytes = utf8.encode(frame.serialize());
    _messageTransport.sendBroadcast(frameBytes);

    final userMsg = Message(
      id: 'msg_user_${frame.timestamp}_${frame.messageId}',
      senderId: profile.id,
      senderAlias: profile.alias,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );

    _sessionManager.addOutgoingMessage(userMsg, frame);
    _packetsProcessed++;
  }

  void sendDirectMessage(String peerId, String content) {
    if (content.trim().isEmpty) return;

    final frame = Frame(
      type: FrameType.directMsg,
      senderId: profile.id,
      recipientId: peerId,
      sessionId: _sessionId,
      messageId: _nextMessageId++,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payloadBody: content,
    );

    final frameBytes = utf8.encode(frame.serialize());
    _messageTransport.sendDirect(peerId, frameBytes);

    final userMsg = Message(
      id: 'msg_dm_user_${frame.timestamp}_${frame.messageId}',
      senderId: profile.id,
      senderAlias: profile.alias,
      recipientId: peerId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _sessionManager.addOutgoingMessage(userMsg, frame);
    _packetsProcessed++;
  }

  void togglePeerTrust(String peerId) {
    _peerManager.toggleTrust(peerId);
  }

  void _loadInitialSimulatedHistory() {
    final now = DateTime.now();
    _sessionManager.loadInitialHistory([
      Message(
        id: 'msg_init_1',
        senderId: 'peer_atlas',
        senderAlias: 'AtlasNode',
        content: 'Welcome to YamiLink local room. Is the UX workshop starting?',
        timestamp: now.subtract(const Duration(minutes: 5)),
        status: MessageStatus.delivered,
      ),
      Message(
        id: 'msg_init_2',
        senderId: 'peer_nebula',
        senderAlias: 'NebulaSeeker',
        content: 'Yes! Room B. It is quite crowded already.',
        timestamp: now.subtract(const Duration(minutes: 3)),
        status: MessageStatus.delivered,
      ),
    ]);
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    _simStrengthTimer?.cancel();
    _messageTransport.clearReceiveCallback();
    _discoveryTransport.stopDiscovery();
    
    if (YamiLinkFfiBridge.instance.isSupported) {
      YamiLinkFfiBridge.instance.stop();
    }
    
    _sessionManager.clear();
    _peerManager.clear();
    super.dispose();
  }
}

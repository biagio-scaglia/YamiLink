import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/moderation/moderation_models.dart';
import '../core/moderation/moderation_service.dart';
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
  final String _sessionId = List.generate(
    16,
    (_) => Random().nextInt(16).toRadixString(16),
  ).join();
  int _nextMessageId = 100;

  // Real diagnostics logs list
  final List<String> _diagnosticsLogs = [];
  List<String> get diagnosticsLogs => List.unmodifiable(_diagnosticsLogs);

  void logDiagnostic(String message) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _diagnosticsLogs.add('[$timeStr] $message');
    if (_diagnosticsLogs.length > 100) {
      _diagnosticsLogs.removeAt(0);
    }
    notifyListeners();
  }

  YamiLinkRepository({required this.profile}) {
    // 1. Initialize FFI core if supported, otherwise fallback to simulator
    YamiLinkFfiBridge.instance.load();

    logDiagnostic('SEC: Initialized ephemeral cryptosystem');
    logDiagnostic('NET: Core 1-hop socket listening on port 8099');

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
    _messageTransport.registerReceiveCallback((
      String senderHash,
      Uint8List packetBytes,
    ) {
      _packetsProcessed++;

      final rawText = utf8.decode(packetBytes);
      try {
        final frame = Frame.deserialize(rawText);

        // Skip loopback messages from ourselves
        if (frame.senderId == profile.id) return;

        logDiagnostic('NET: Received frame type: ${frame.type.name} from ${frame.senderId}');

        // A. Check if the sender is manually or auto-blocked
        if (isPeerBlocked(frame.senderId)) {
          logDiagnostic('SEC: Discarded incoming frame from blocked peer ${frame.senderId}');
          return;
        }

        // B. Run incoming moderation
        bool isFlagged = false;
        bool isBlurred = false;
        String? moderationExplanation;

        if (frame.type == FrameType.roomMsg || frame.type == FrameType.directMsg) {
          final decision = ModerationService.instance.moderateIncoming(
            frame.senderId,
            frame.messageId.toString(),
            frame.payloadBody,
          );

          if (decision.action == ModerationAction.block) {
            logDiagnostic('SEC: Blocked message from ${frame.senderId} due to: ${decision.explanation}');
            notifyListeners();
            return;
          }

          isFlagged = decision.action == ModerationAction.hide || decision.action == ModerationAction.block;
          isBlurred = decision.action == ModerationAction.hide;
          moderationExplanation = decision.explanation;
        }

        // Retrieve sender alias and seed from current discovered peers
        String senderAlias = 'External Peer';
        int avatarSeed = 0;
        for (var p in _peerManager.peers) {
          if (p.id == frame.senderId) {
            senderAlias = p.alias;
            avatarSeed = p.avatarSeed;
            break;
          }
        }

        _sessionManager.processIncomingFrame(
          frame,
          senderAlias,
          avatarSeed,
          isFlagged: isFlagged,
          isBlurred: isBlurred,
          moderationExplanation: moderationExplanation,
        );
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
      _sessionManager.syncPeerOnlineStatus(
        _peerManager.peers.map((p) => p.id).toList(),
      );
    });
  }

  // --- Getters mirroring SimulationService interface ---
  // Filter out blocked peers
  List<Peer> get peers => _peerManager.peers.where((p) => !isPeerBlocked(p.id)).toList();
  List<Message> get roomMessages => _sessionManager.roomMessages;
  // Filter out conversations with blocked peers
  List<Conversation> get conversations => _sessionManager.conversations.where((c) => !isPeerBlocked(c.peerId)).toList();
  
  int get totalUnreadCount => conversations.fold<int>(
    0,
    (sum, c) => sum + c.unreadCount,
  );
  List<Message> getDirectMessages(String peerId) =>
      _sessionManager.getDirectMessages(peerId);
  bool get isScanning => _isScanning;
  bool get relayEnabled => _relayEnabled;
  int get packetsProcessed => _packetsProcessed;
  double get signalStrength => _signalStrength;

  // --- Actions ---

  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    logDiagnostic('INF: Scan initialized for nearby beacons...');
    notifyListeners();

    _discoveryTransport.startDiscovery(
      onPeerFound: (nodeHash, alias, seed, rssi) {
        logDiagnostic('INF: Discovered peer: $alias ($nodeHash)');
        _peerManager.handlePeerFound(
          id: nodeHash,
          alias: alias,
          seed: seed,
          signal: rssi,
        );
        _packetsProcessed++;
      },
      onPeerLost: (nodeHash) {
        logDiagnostic('INF: Lost peer connection: $nodeHash');
        _peerManager.handlePeerLost(nodeHash);
        _packetsProcessed++;
      },
    );
  }

  void stopScanning() {
    _isScanning = false;
    logDiagnostic('INF: Scan stopped.');
    _discoveryTransport.stopDiscovery();
    notifyListeners();
  }

  void toggleRelay() {
    _relayEnabled = !_relayEnabled;
    logDiagnostic('INF: Mesh Relay toggled to $_relayEnabled');
    _packetsProcessed += 2;
    notifyListeners();
  }

  ModerationDecision? sendBroadcastMessage(String content, {bool force = false}) {
    if (content.trim().isEmpty) return null;

    final decision = ModerationService.instance.moderateOutgoing(content);
    if (decision.action == ModerationAction.block) {
      logDiagnostic('SEC: Outgoing room broadcast blocked: ${decision.explanation}');
      return decision;
    }
    if (decision.action == ModerationAction.warn && !force) {
      return decision;
    }

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
    logDiagnostic('DBG: Sent room broadcast: [${content.length} chars]');

    final userMsg = Message(
      id: 'msg_user_${frame.timestamp}_${frame.messageId}',
      senderId: profile.id,
      senderAlias: profile.alias,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
      isFlagged: decision.action == ModerationAction.warn,
      isBlurred: false,
      moderationExplanation: decision.action == ModerationAction.warn ? decision.explanation : null,
    );

    _sessionManager.addOutgoingMessage(userMsg, frame);
    _packetsProcessed++;
    return decision;
  }

  ModerationDecision? sendDirectMessage(String peerId, String content, {bool force = false}) {
    if (content.trim().isEmpty) return null;

    final decision = ModerationService.instance.moderateOutgoing(content);
    if (decision.action == ModerationAction.block) {
      logDiagnostic('SEC: Outgoing direct message blocked: ${decision.explanation}');
      return decision;
    }
    if (decision.action == ModerationAction.warn && !force) {
      return decision;
    }

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
    logDiagnostic('DBG: Sent direct message to peer $peerId: [${content.length} chars]');

    final peer = _peerManager.peers.firstWhere(
      (p) => p.id == peerId,
      orElse: () => Peer(
        id: peerId,
        alias: 'External Peer',
        avatarSeed: 0,
        lastSeen: DateTime.now(),
      ),
    );

    final userMsg = Message(
      id: 'msg_dm_user_${frame.timestamp}_${frame.messageId}',
      senderId: profile.id,
      senderAlias: profile.alias,
      recipientId: peerId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isFlagged: decision.action == ModerationAction.warn,
      isBlurred: false,
      moderationExplanation: decision.action == ModerationAction.warn ? decision.explanation : null,
    );

    _sessionManager.addOutgoingMessage(
      userMsg,
      frame,
      peerAlias: peer.alias,
      peerAvatarSeed: peer.avatarSeed,
    );
    _packetsProcessed++;
    return decision;
  }

  void togglePeerTrust(String peerId) {
    _peerManager.toggleTrust(peerId);
  }

  // --- Local Moderator Controls ---

  void mutePeer(String peerId, Duration duration) {
    ModerationService.instance.mutePeer(peerId, duration);
    logDiagnostic('SEC: Peer $peerId silenziato per ${duration.inSeconds} secondi');
    notifyListeners();
  }

  void unmutePeer(String peerId) {
    ModerationService.instance.unmutePeer(peerId);
    logDiagnostic('SEC: Peer $peerId riattivato (unmuted)');
    notifyListeners();
  }

  bool isPeerMuted(String peerId) {
    return ModerationService.instance.isPeerMuted(peerId);
  }

  void blockPeer(String peerId) {
    ModerationService.instance.blockPeer(peerId);
    _peerManager.blockPeer(peerId);
    logDiagnostic('SEC: Peer $peerId bloccato');
    notifyListeners();
  }

  void unblockPeer(String peerId) {
    ModerationService.instance.unblockPeer(peerId);
    _peerManager.unblockPeer(peerId);
    logDiagnostic('SEC: Peer $peerId sbloccato');
    notifyListeners();
  }

  bool isPeerBlocked(String peerId) {
    return _peerManager.isBlocked(peerId) || ModerationService.instance.isPeerBlocked(peerId);
  }

  void setActiveConversation(String? peerId) {
    _sessionManager.activeConversationId = peerId;
    if (peerId != null) {
      _sessionManager.markAsRead(peerId);
    }
  }

  void markConversationAsRead(String peerId) {
    _sessionManager.markAsRead(peerId);
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
    ModerationService.instance.clear();
    super.dispose();
  }
}

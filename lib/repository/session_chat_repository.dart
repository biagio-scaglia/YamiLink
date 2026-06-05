import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:yamilink/core/transport/multicast_manager.dart';

import '../core/moderation/moderation_models.dart';
import '../core/moderation/moderation_service.dart';
import '../core/protocol/frame.dart';
import '../core/security/tesla_engine.dart';
import '../core/state/peer_manager.dart';
import '../core/state/session_room.dart';
import '../core/transport/noop_transport.dart';
import '../core/transport/transport_interface.dart';
import '../core/transport/win_udp_transport.dart';
import '../ffi_bridge.dart';
import '../models.dart';

class SessionChatRepository extends ChangeNotifier {
  final EphemeralProfile profile;

  late final PeerManager _peerManager;
  late final SessionRoom _sessionRoom;

  late final DiscoveryTransport _discoveryTransport;
  late final MessageTransport _messageTransport;

  bool _isScanning = false;
  bool _relayEnabled = true;
  int _packetsProcessed = 0;
  double _signalStrength = 1.0;

  Timer? _sweepTimer;
  final String _sessionId = List.generate(
    16,
    (_) => Random().nextInt(16).toRadixString(16),
  ).join();
  int _nextMessageId = 100;
  final Set<String> _relayedMessageKeys = {};

  final List<String> _diagnosticsLogs = [];
  List<String> get diagnosticsLogs => List.unmodifiable(_diagnosticsLogs);

  void logDiagnostic(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _diagnosticsLogs.add('[$timeStr] $message');
    if (_diagnosticsLogs.length > 100) {
      _diagnosticsLogs.removeAt(0);
    }
    notifyListeners();
  }

  SessionChatRepository({
    required this.profile,
    DiscoveryTransport? discoveryTransport,
    MessageTransport? messageTransport,
  }) {
    // Acquire Android MulticastLock early to ensure UDP binds can receive
    MulticastManager.acquire();

    final loadError = YamiLinkFfiBridge.instance.load();
    if (loadError != null) {
      logDiagnostic('ERR: FFI Load Failed: $loadError');
    } else {
      logDiagnostic('SEC: FFI Bridge Loaded Successfully');
    }

    logDiagnostic('SEC: Initialized ephemeral public local cryptosystem');
    logDiagnostic('NET: Core 1-hop socket listening on port 8099');

    if (discoveryTransport != null && messageTransport != null) {
      _discoveryTransport = discoveryTransport;
      _messageTransport = messageTransport;
      _packetsProcessed = 0;
    } else if (YamiLinkFfiBridge.instance.isSupported) {
      final winTransport = WinUdpTransport();
      _discoveryTransport = winTransport;
      _messageTransport = winTransport;

      final startRes = YamiLinkFfiBridge.instance.start(profile.alias, profile.avatarSeed);
      if (startRes == 0) {
        logDiagnostic('NET: UDP Socket Bound Successfully on 8099');
      } else {
        logDiagnostic('ERR: UDP Socket Bind Failed. Code: $startRes');
      }
      _packetsProcessed = 0;
    } else {
      final noOp = NoOpTransport();
      _discoveryTransport = noOp;
      _messageTransport = noOp;
      _packetsProcessed = 0;
      _signalStrength = 1.0;
    }

    _peerManager = PeerManager(onChanged: notifyListeners);
    _sessionRoom = SessionRoom(
      localNodeId: profile.id,
      onChanged: notifyListeners,
    );

    _messageTransport.registerReceiveCallback((
      String senderHash,
      Uint8List packetBytes,
    ) async {
      _packetsProcessed++;

      final rawDecision = TeslaEngine.instance.inspectRawPacket(senderHash, packetBytes);
      if (rawDecision == TeslaDecision.drop) return;

      try {
        final frame = Frame.fromBytes(packetBytes);

        final effectiveHash = senderHash.isEmpty ? frame.senderId : senderHash;
        final frameDecision = await TeslaEngine.instance.inspectParsedFrame(frame, effectiveHash);
        if (frameDecision == TeslaDecision.drop) return;

        if (frame.senderId == profile.id) return;

        final dupKey = '${frame.senderId}:${frame.messageId}:${frame.type.name}';
        if (_relayedMessageKeys.contains(dupKey)) {
          return;
        }

        _relayedMessageKeys.add(dupKey);
        if (_relayedMessageKeys.length > 200) {
          _relayedMessageKeys.remove(_relayedMessageKeys.first);
        }

        logDiagnostic(
          'NET: Received frame type: ${frame.type.name} from ${frame.senderId} (Hop: ${frame.hopCount})',
        );

        if (isPeerBlocked(frame.senderId)) {
          logDiagnostic(
            'SEC: Discarded incoming frame from blocked peer ${frame.senderId}',
          );
          return;
        }

        final isRoomMsg = frame.type == FrameType.roomMsg;

        if (_relayEnabled && frame.hopCount < 3) {
          if (isRoomMsg) {
            final relayedFrame = Frame(
              type: frame.type,
              senderId: frame.senderId,
              recipientId: frame.recipientId,
              sessionId: frame.sessionId,
              messageId: frame.messageId,
              timestamp: frame.timestamp,
              flags: frame.flags,
              hopCount: frame.hopCount + 1,
              payloadBytes: frame.payloadBytes,
              signature: frame.signature,
            );

            final relayedBytes = relayedFrame.serialize();
            _messageTransport.sendBroadcast(relayedBytes);

            logDiagnostic(
              'SEC: [MESH] Relayed ${frame.type.name} from ${frame.senderId} to public channel (Hop ${frame.hopCount} -> ${relayedFrame.hopCount})',
            );
          }
        }

        if (frame.recipientId == '*' && isRoomMsg) {
          bool isFlagged = false;
          bool isBlurred = false;
          String? moderationExplanation;
          String decryptedPayload = frame.payloadBody;

          final decision = ModerationService.instance.moderateIncoming(
            frame.senderId,
            frame.messageId.toString(),
            decryptedPayload,
          );

          if (decision.action == ModerationAction.block) {
            logDiagnostic(
              'SEC: Blocked message from ${frame.senderId} due to: ${decision.explanation}',
            );
            notifyListeners();
            return;
          }

          isFlagged =
              decision.action == ModerationAction.hide ||
              decision.action == ModerationAction.block;
          isBlurred = decision.action == ModerationAction.hide;
          moderationExplanation = decision.explanation;

          String senderAlias = 'External Peer';
          int avatarSeed = 0;
          for (var p in _peerManager.peers) {
            if (p.id == frame.senderId) {
              senderAlias = p.alias;
              avatarSeed = p.avatarSeed;
              break;
            }
          }

          _sessionRoom.processIncomingFrame(
            frame,
            senderAlias,
            avatarSeed,
            isFlagged: isFlagged,
            isBlurred: isBlurred,
            moderationExplanation: moderationExplanation,
          );
        }
      } catch (e) {
        debugPrint('Failed to parse incoming protocol frame: $e');
      }
    });

    _sweepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      TeslaEngine.instance.sweep();
      _peerManager.sweepStalePeers();
    });
  }

  @visibleForTesting
  MessageTransport get messageTransport => _messageTransport;

  @visibleForTesting
  SessionRoom get sessionRoom => _sessionRoom;

  List<Peer> get peers =>
      _peerManager.peers.where((p) => !isPeerBlocked(p.id)).toList();
  List<LocalRoomMessage> get roomMessages => _sessionRoom.roomMessages;

  bool get isScanning => _isScanning;
  bool get relayEnabled => _relayEnabled;
  int get packetsProcessed => _packetsProcessed;
  double get signalStrength => _signalStrength;

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

  Future<ModerationDecision?> sendBroadcastMessage(
    String content, {
    bool force = false,
  }) async {
    if (content.trim().isEmpty) return null;

    final decision = ModerationService.instance.moderateOutgoing(content);
    if (decision.action == ModerationAction.block) {
      logDiagnostic(
        'SEC: Outgoing room broadcast blocked: ${decision.explanation}',
      );
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
      payloadBytes: utf8.encode(content),
    );

    final signedFrame = await _signFrame(frame);
    final frameBytes = signedFrame.serialize();
    _messageTransport.sendBroadcast(frameBytes);
    logDiagnostic('DBG: Sent room broadcast: [${content.length} chars]');

    final userMsg = LocalRoomMessage(
      id: 'msg_user_${frame.timestamp}_${frame.messageId}',
      senderId: profile.id,
      senderAlias: profile.alias,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
      isFlagged: decision.action == ModerationAction.warn,
      isBlurred: false,
      moderationExplanation: decision.action == ModerationAction.warn
          ? decision.explanation
          : null,
    );

    _sessionRoom.addOutgoingMessage(userMsg, signedFrame);
    _packetsProcessed++;
    return decision;
  }

  void mutePeer(String peerId, Duration duration) {
    ModerationService.instance.mutePeer(peerId, duration);
    logDiagnostic(
      'SEC: Peer $peerId silenziato per ${duration.inSeconds} secondi',
    );
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
    return _peerManager.isBlocked(peerId) ||
        ModerationService.instance.isPeerBlocked(peerId);
  }

  @override
  void dispose() {
    MulticastManager.release();
    _sweepTimer?.cancel();
    _messageTransport.clearReceiveCallback();
    _discoveryTransport.stopDiscovery();

    if (YamiLinkFfiBridge.instance.isSupported) {
      YamiLinkFfiBridge.instance.stop();
    }

    _sessionRoom.clear();
    _peerManager.clear();
    ModerationService.instance.clear();
    super.dispose();
  }

  Future<Frame> _signFrame(Frame frame) async {
    if (profile.identityKeyPair == null) return frame;
    final ed25519 = Ed25519();
    final signature = await ed25519.sign(frame.signableBytes, keyPair: profile.identityKeyPair!);
    return Frame(
      version: frame.version,
      type: frame.type,
      senderId: frame.senderId,
      recipientId: frame.recipientId,
      sessionId: frame.sessionId,
      messageId: frame.messageId,
      timestamp: frame.timestamp,
      flags: frame.flags,
      hopCount: frame.hopCount,
      payloadBytes: frame.payloadBytes,
      signature: Uint8List.fromList(signature.bytes),
    );
  }
}

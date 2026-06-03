import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';

import '../core/moderation/moderation_models.dart';
import '../core/moderation/moderation_service.dart';
import '../core/protocol/frame.dart';
import '../core/state/peer_manager.dart';
import '../core/state/session_manager.dart';
import '../core/transport/noop_transport.dart';
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
  final String _sessionId = List.generate(
    16,
    (_) => Random().nextInt(16).toRadixString(16),
  ).join();
  int _nextMessageId = 100;
  final Set<String> _relayedMessageKeys = {};

  SimpleKeyPair? _localKeyPair;
  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();

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

  YamiLinkRepository({
    required this.profile,
    DiscoveryTransport? discoveryTransport,
    MessageTransport? messageTransport,
  }) {
    YamiLinkFfiBridge.instance.load();
    _initCrypto();

    logDiagnostic('SEC: Initialized ephemeral cryptosystem');
    logDiagnostic('NET: Core 1-hop socket listening on port 8099');

    if (discoveryTransport != null && messageTransport != null) {
      _discoveryTransport = discoveryTransport;
      _messageTransport = messageTransport;
      _packetsProcessed = 0;
    } else if (YamiLinkFfiBridge.instance.isSupported) {
      final winTransport = WinUdpTransport();
      _discoveryTransport = winTransport;
      _messageTransport = winTransport;

      YamiLinkFfiBridge.instance.start(profile.alias, profile.avatarSeed);
      _packetsProcessed = 0;
    } else {
      final noOp = NoOpTransport();
      _discoveryTransport = noOp;
      _messageTransport = noOp;
      _packetsProcessed = 0;
      _signalStrength = 1.0;
    }

    _peerManager = PeerManager(onChanged: notifyListeners);
    _sessionManager = SessionManager(
      localNodeId: profile.id,
      onChanged: notifyListeners,
      onRetransmit: (Frame frame) {
        final frameBytes = utf8.encode(frame.serialize());
        _messageTransport.sendDirect(frame.recipientId, frameBytes);
        _packetsProcessed++;
      },
    );

    _messageTransport.registerReceiveCallback((
      String senderHash,
      Uint8List packetBytes,
    ) async {
      _packetsProcessed++;

      final rawText = utf8.decode(packetBytes);
      try {
        final frame = Frame.deserialize(rawText);

        if (frame.senderId == profile.id) return;

        final dupKey = '${frame.senderId}:${frame.messageId}:${frame.type.name}';
        if (_relayedMessageKeys.contains(dupKey)) {
          if (frame.type == FrameType.directMsg && frame.recipientId == profile.id) {
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
            );
          }
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

        if (frame.type == FrameType.hello && frame.recipientId == profile.id) {
          _handleHello(frame);
          return;
        }

        final isDirectForOthers = frame.recipientId != '*' && frame.recipientId != profile.id;
        final isRoomMsg = frame.type == FrameType.roomMsg;
        final isDM = frame.type == FrameType.directMsg;
        final isAck = frame.type == FrameType.ack;

        if (_relayEnabled && frame.hopCount < 3) {
          if (isRoomMsg || ((isDM || isAck) && isDirectForOthers)) {
            final relayedFrame = Frame(
              type: frame.type,
              senderId: frame.senderId,
              recipientId: frame.recipientId,
              sessionId: frame.sessionId,
              messageId: frame.messageId,
              timestamp: frame.timestamp,
              flags: frame.flags,
              hopCount: frame.hopCount + 1,
              payloadType: frame.payloadType,
              payloadBody: frame.payloadBody,
            );

            final relayedBytes = utf8.encode(relayedFrame.serialize());
            if (relayedFrame.recipientId == '*') {
              _messageTransport.sendBroadcast(relayedBytes);
            } else {
              _messageTransport.sendDirect(relayedFrame.recipientId, relayedBytes);
            }

            logDiagnostic(
              'SEC: [MESH] Relayed ${frame.type.name} from ${frame.senderId} to ${frame.recipientId} (Hop ${frame.hopCount} -> ${relayedFrame.hopCount})',
            );
          }
        }

        if (frame.recipientId == profile.id || frame.recipientId == '*') {
          bool isFlagged = false;
          bool isBlurred = false;
          String? moderationExplanation;
          String decryptedPayload = frame.payloadBody;

          if (frame.type == FrameType.roomMsg ||
              frame.type == FrameType.directMsg) {
            if (frame.type == FrameType.directMsg && frame.payloadType == 'crypto/aes') {
              final sharedKey = _peerManager.getSharedKey(frame.senderId);
              if (sharedKey != null) {
                try {
                  final encryptedBytes = base64.decode(frame.payloadBody);
                  // IV is first 12 bytes
                  final iv = encryptedBytes.sublist(0, 12);
                  final cipherText = encryptedBytes.sublist(12);
                  final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac.empty);
                  
                  final clearBytes = await _aesGcm.decrypt(
                    secretBox,
                    secretKey: SecretKey(sharedKey),
                  );
                  decryptedPayload = utf8.decode(clearBytes);
                  logDiagnostic('SEC: Decrypted direct message from ${frame.senderId}');
                } catch (e) {
                  logDiagnostic('SEC: Failed to decrypt message from ${frame.senderId}: $e');
                  decryptedPayload = '[ENCRYPTED MESSAGE UNREADABLE]';
                }
              } else {
                decryptedPayload = '[ENCRYPTED MESSAGE - NO KEY]';
              }
            }

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
          }

          String senderAlias = 'External Peer';
          int avatarSeed = 0;
          for (var p in _peerManager.peers) {
            if (p.id == frame.senderId) {
              senderAlias = p.alias;
              avatarSeed = p.avatarSeed;
              break;
            }
          }
          final processedFrame = (frame.type == FrameType.directMsg && frame.payloadType == 'crypto/aes')
              ? Frame(
                  version: frame.version,
                  type: frame.type,
                  senderId: frame.senderId,
                  recipientId: frame.recipientId,
                  sessionId: frame.sessionId,
                  messageId: frame.messageId,
                  timestamp: frame.timestamp,
                  flags: frame.flags,
                  hopCount: frame.hopCount,
                  payloadType: 'text',
                  payloadBody: decryptedPayload,
                )
              : frame;

          _sessionManager.processIncomingFrame(
            processedFrame,
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
      _peerManager.sweepStalePeers();
      _sessionManager.syncPeerOnlineStatus(
        _peerManager.peers.map((p) => p.id).toList(),
      );
    });
  }

  @visibleForTesting
  MessageTransport get messageTransport => _messageTransport;

  @visibleForTesting
  SessionManager get sessionManager => _sessionManager;

  List<Peer> get peers =>
      _peerManager.peers.where((p) => !isPeerBlocked(p.id)).toList();
  List<Message> get roomMessages => _sessionManager.roomMessages;

  List<Conversation> get conversations => _sessionManager.conversations
      .where((c) => !isPeerBlocked(c.peerId))
      .toList();

  int get totalUnreadCount =>
      conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  List<Message> getDirectMessages(String peerId) =>
      _sessionManager.getDirectMessages(peerId);
  bool get isScanning => _isScanning;
  bool get relayEnabled => _relayEnabled;
  int get packetsProcessed => _packetsProcessed;
  double get signalStrength => _signalStrength;

  List<int>? getSharedKey(String peerId) => _peerManager.getSharedKey(peerId);

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

  ModerationDecision? sendBroadcastMessage(
    String content, {
    bool force = false,
  }) {
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
      moderationExplanation: decision.action == ModerationAction.warn
          ? decision.explanation
          : null,
    );

    _sessionManager.addOutgoingMessage(userMsg, frame);
    _packetsProcessed++;
    return decision;
  }

  Future<ModerationDecision?> sendDirectMessage(
    String peerId,
    String content, {
    bool force = false,
  }) async {
    if (content.trim().isEmpty) return null;

    final decision = ModerationService.instance.moderateOutgoing(content);
    if (decision.action == ModerationAction.block) {
      logDiagnostic(
        'SEC: Outgoing direct message blocked: ${decision.explanation}',
      );
      return decision;
    }
    if (decision.action == ModerationAction.warn && !force) {
      return decision;
    }

    String finalPayload = content;
    String finalPayloadType = 'text';

    final sharedKey = _peerManager.getSharedKey(peerId);
    if (sharedKey != null) {
      try {
        final clearBytes = utf8.encode(content);
        final nonce = _aesGcm.newNonce();
        final secretBox = await _aesGcm.encrypt(
          clearBytes,
          secretKey: SecretKey(sharedKey),
          nonce: nonce,
        );
        final encryptedBytes = <int>[...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes];
        finalPayload = base64.encode(encryptedBytes);
        finalPayloadType = 'crypto/aes';
        logDiagnostic('SEC: Encrypted direct message for $peerId');
      } catch (e) {
        logDiagnostic('SEC: Failed to encrypt message for $peerId: $e');
      }
    }

    final frame = Frame(
      type: FrameType.directMsg,
      senderId: profile.id,
      recipientId: peerId,
      sessionId: _sessionId,
      messageId: _nextMessageId++,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payloadType: finalPayloadType,
      payloadBody: finalPayload,
    );

    final frameBytes = utf8.encode(frame.serialize());
    _messageTransport.sendDirect(peerId, frameBytes);
    logDiagnostic(
      'DBG: Sent direct message to peer $peerId: [${content.length} chars]',
    );

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
      moderationExplanation: decision.action == ModerationAction.warn
          ? decision.explanation
          : null,
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

  void setActiveConversation(String? peerId) {
    _sessionManager.activeConversationId = peerId;
    if (peerId != null) {
      _sessionManager.markAsRead(peerId);
    }
  }

  void markConversationAsRead(String peerId) {
    _sessionManager.markAsRead(peerId);
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
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

  Future<void> _initCrypto() async {
    _localKeyPair = await _x25519.newKeyPair();
    logDiagnostic('SEC: Local X25519 KeyPair generated');
  }

  Future<void> initiatePairing(String peerId) async {
    if (_localKeyPair == null) return;
    try {
      final publicKey = await _localKeyPair!.extractPublicKey();
      final pkBase64 = base64.encode(publicKey.bytes);

      final frame = Frame(
        type: FrameType.hello,
        senderId: profile.id,
        recipientId: peerId,
        sessionId: _sessionId,
        messageId: _nextMessageId++,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payloadBody: pkBase64,
      );

      final frameBytes = utf8.encode(frame.serialize());
      _messageTransport.sendDirect(peerId, frameBytes);
      logDiagnostic('SEC: Initiated Diffie-Hellman pairing with \$peerId');
    } catch (e) {
      logDiagnostic('SEC: Error initiating pairing with \$peerId: \$e');
    }
  }

  Future<void> _handleHello(Frame frame) async {
    if (_localKeyPair == null) return;
    try {
      final remotePkBytes = base64.decode(frame.payloadBody);
      final remotePk = SimplePublicKey(remotePkBytes, type: KeyPairType.x25519);

      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: _localKeyPair!,
        remotePublicKey: remotePk,
      );

      final sharedBytes = await sharedSecret.extractBytes();
      final hash = await Sha256().hash(sharedBytes);

      _peerManager.setSharedKey(frame.senderId, hash.bytes);
      
      final wasPaired = _peerManager.isPaired(frame.senderId);
      _peerManager.setPaired(frame.senderId);

      logDiagnostic('SEC: ECDH pairing complete with \${frame.senderId}');

      // If we weren't paired yet, reply with our own HELLO
      if (!wasPaired) {
        logDiagnostic('SEC: Replying to HELLO from \${frame.senderId}');
        await initiatePairing(frame.senderId);
      }
      notifyListeners();
    } catch (e) {
      logDiagnostic('SEC: ECDH pairing failed with \${frame.senderId}: \$e');
    }
  }
}

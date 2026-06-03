import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'ffi_bridge.dart';

class SimulationService extends ChangeNotifier {
  final EphemeralProfile profile;

  // App-wide state
  final List<Peer> _peers = [];
  final List<Message> _roomMessages = [];
  final Map<String, List<Message>> _directMessages =
      {}; // peerId -> messageList
  bool _isScanning = false;
  bool _relayEnabled = true;
  int _packetsProcessed = 0;
  double _signalStrength = 1.0;

  Timer? _discoveryTimer;
  Timer? _peerActivityTimer;
  final Random _random = Random();

  SimulationService({required this.profile}) {
    // Attempt to load the C FFI Core bridge
    YamiLinkFfiBridge.instance.load();

    if (YamiLinkFfiBridge.instance.isSupported) {
      // Initialize native Winsock structures
      YamiLinkFfiBridge.instance.initialize(profile.alias, profile.avatarSeed);
      _packetsProcessed = 5; // Diagnostic baseline
    } else {
      // Generate simulated visual history for Chrome/Web fallbacks
      _generateInitialHistory();
      _packetsProcessed = 142;
    }
  }

  // Getters
  List<Peer> get peers => _peers;
  List<Message> get roomMessages => _roomMessages;
  List<Message> getDirectMessages(String peerId) =>
      _directMessages[peerId] ?? [];
  bool get isScanning => _isScanning;
  bool get relayEnabled => _relayEnabled;
  int get packetsProcessed => _packetsProcessed;
  double get signalStrength => _signalStrength;

  final List<String> _simulatedNames = [
    'Alice_Proximity',
    'Ghost-404',
    'NebulaSeeker',
    'QuantumPioneer',
    'CyberShell',
    'AtlasNode',
  ];

  void _generateInitialHistory() {
    final now = DateTime.now();
    _roomMessages.addAll([
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

  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    if (YamiLinkFfiBridge.instance.isSupported) {
      // 1. Run via Real UDP socket FFI engine
      _peers.clear();
      notifyListeners();

      YamiLinkFfiBridge.instance.startDiscovery(
        onPeerFound: (String id, String alias, int seed, double signal) {
          final index = _peers.indexWhere((p) => p.id == id);
          if (index == -1) {
            _peers.add(
              Peer(
                id: id,
                alias: alias,
                avatarSeed: seed,
                proximityHint: ProximityHint.immediate,
                relayCapability: true,
                lastSeen: DateTime.now(),
              ),
            );
            _packetsProcessed += 1;
            notifyListeners();
          } else {
            _peers[index].lastSeen = DateTime.now();
          }
        },
        onMessageReceived:
            (String senderHash, String senderAlias, String content) {
              _packetsProcessed += 1;

              // Parse direct messages targeted to us: [DM_TO:node_id]msg
              final dmPrefix =
                  '[DM_TO:node_${profile.avatarSeed}_${profile.alias.length}]';
              if (content.startsWith('[DM_TO:')) {
                if (content.startsWith(dmPrefix)) {
                  final directMsgText = content.replaceFirst(dmPrefix, '');
                  final directMsg = Message(
                    id: 'msg_dm_recv_${DateTime.now().millisecondsSinceEpoch}',
                    senderId: senderHash,
                    senderAlias: senderAlias,
                    recipientId: profile.id,
                    content: directMsgText,
                    timestamp: DateTime.now(),
                    status: MessageStatus.delivered,
                  );
                  _directMessages
                      .putIfAbsent(senderHash, () => [])
                      .add(directMsg);
                  notifyListeners();
                }
              } else {
                // General room broadcast
                final msg = Message(
                  id: 'msg_recv_${DateTime.now().millisecondsSinceEpoch}',
                  senderId: senderHash,
                  senderAlias: senderAlias,
                  content: content,
                  timestamp: DateTime.now(),
                  status: MessageStatus.delivered,
                );
                _roomMessages.add(msg);
                notifyListeners();
              }
            },
      );
    } else {
      // 2. Local fallback simulator loop
      _spawnInitialPeers();

      _discoveryTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _updatePeerListSimulated();
      });

      _peerActivityTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _simulatePeerRoomMessage();
      });
    }
  }

  void stopScanning() {
    _isScanning = false;

    if (YamiLinkFfiBridge.instance.isSupported) {
      YamiLinkFfiBridge.instance.stop();
    } else {
      _discoveryTimer?.cancel();
      _peerActivityTimer?.cancel();
    }

    notifyListeners();
  }

  void toggleRelay() {
    _relayEnabled = !_relayEnabled;
    _packetsProcessed += 2;
    notifyListeners();
  }

  void sendBroadcastMessage(String content) {
    if (content.trim().isEmpty) return;

    final userMsg = Message(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      senderId: profile.id,
      senderAlias: profile.alias,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );

    _roomMessages.add(userMsg);
    _packetsProcessed += 1;
    notifyListeners();

    if (YamiLinkFfiBridge.instance.isSupported) {
      YamiLinkFfiBridge.instance.sendBroadcast(content);
    } else {
      // Simulate loop reply
      Timer(Duration(milliseconds: 1000 + _random.nextInt(1500)), () {
        _simulateReplyTo(content);
      });
    }
  }

  void sendDirectMessage(String peerId, String content) {
    if (content.trim().isEmpty) return;

    final userMsg = Message(
      id: 'msg_dm_user_${DateTime.now().millisecondsSinceEpoch}',
      senderId: profile.id,
      senderAlias: profile.alias,
      recipientId: peerId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _directMessages.putIfAbsent(peerId, () => []).add(userMsg);
    notifyListeners();

    if (YamiLinkFfiBridge.instance.isSupported) {
      YamiLinkFfiBridge.instance.sendDirect(peerId, content);
      Timer(const Duration(milliseconds: 200), () {
        userMsg.status = MessageStatus.delivered;
        _packetsProcessed += 1;
        notifyListeners();
      });
    } else {
      // Simulation delay
      Timer(const Duration(milliseconds: 600), () {
        userMsg.status = MessageStatus.delivered;
        _packetsProcessed += 1;
        notifyListeners();

        Timer(const Duration(seconds: 2), () {
          final peer = _peers.firstWhere(
            (p) => p.id == peerId,
            orElse: () => _createDummyPeer(peerId),
          );
          final replies = [
            'Direct message processed securely.',
            'Got it, meet you there!',
            'Understood, over and out.',
          ];

          final peerReply = Message(
            id: 'msg_dm_sim_${DateTime.now().millisecondsSinceEpoch}',
            senderId: peer.id,
            senderAlias: peer.alias,
            recipientId: profile.id,
            content: replies[_random.nextInt(replies.length)],
            timestamp: DateTime.now(),
            status: MessageStatus.delivered,
          );

          _directMessages.putIfAbsent(peerId, () => []).add(peerReply);
          _packetsProcessed += 1;
          notifyListeners();
        });
      });
    }
  }

  void togglePeerTrust(String peerId) {
    final index = _peers.indexWhere((p) => p.id == peerId);
    if (index != -1) {
      final currentTrust = _peers[index].trustLevel;
      _peers[index].trustLevel = currentTrust == TrustLevel.paired
          ? TrustLevel.unverified
          : TrustLevel.paired;
      notifyListeners();
    }
  }

  // --- Simulated Helpers ---

  void _spawnInitialPeers() {
    final now = DateTime.now();
    _peers.addAll([
      Peer(
        id: 'peer_alice',
        alias: 'Alice_Proximity',
        avatarSeed: 1042,
        trustLevel: TrustLevel.paired,
        proximityHint: ProximityHint.immediate,
        relayCapability: true,
        lastSeen: now,
      ),
      Peer(
        id: 'peer_ghost',
        alias: 'Ghost-404',
        avatarSeed: 5041,
        trustLevel: TrustLevel.unverified,
        proximityHint: ProximityHint.near,
        relayCapability: false,
        lastSeen: now,
      ),
      Peer(
        id: 'peer_atlas',
        alias: 'AtlasNode',
        avatarSeed: 9811,
        trustLevel: TrustLevel.unverified,
        proximityHint: ProximityHint.far,
        relayCapability: true,
        lastSeen: now,
      ),
    ]);
    notifyListeners();
  }

  void _updatePeerListSimulated() {
    _packetsProcessed += _random.nextInt(10) + 2;
    _signalStrength = 0.75 + _random.nextDouble() * 0.2;

    for (var peer in _peers) {
      if (_random.nextDouble() > 0.65) {
        final hints = ProximityHint.values;
        peer.proximityHint =
            hints[_random.nextInt(hints.length - 1)]; // Avoid unknown
        peer.lastSeen = DateTime.now();
      }
    }

    if (_peers.length < 8 && _random.nextDouble() > 0.75) {
      final availableNames = _simulatedNames
          .where((name) => !_peers.any((p) => p.alias == name))
          .toList();
      if (availableNames.isNotEmpty) {
        final name = availableNames[_random.nextInt(availableNames.length)];
        _peers.add(
          Peer(
            id: 'peer_${name.toLowerCase()}',
            alias: name,
            avatarSeed: _random.nextInt(100000),
            proximityHint: ProximityHint.values[_random.nextInt(3)],
            relayCapability: _random.nextBool(),
            lastSeen: DateTime.now(),
          ),
        );
      }
    }
    notifyListeners();
  }

  void _simulatePeerRoomMessage() {
    if (_peers.isEmpty) return;
    final randomPeer = _peers[_random.nextInt(_peers.length)];
    final sentences = [
      'Who is going to the keynote in 10 minutes?',
      'Awesome local connectivity network.',
      'The 1-hop relay works perfectly here.',
    ];

    _roomMessages.add(
      Message(
        id: 'msg_sim_${DateTime.now().millisecondsSinceEpoch}',
        senderId: randomPeer.id,
        senderAlias: randomPeer.alias,
        content: sentences[_random.nextInt(sentences.length)],
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      ),
    );
    _packetsProcessed += 1;
    notifyListeners();
  }

  void _simulateReplyTo(String originalText) {
    if (_peers.isEmpty) return;
    final replier = _peers[_random.nextInt(_peers.length)];
    String replyText = 'Received on my node! Clean connection.';

    final lower = originalText.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      replyText = 'Hi ${profile.alias}! Welcome to the physical space.';
    } else if (lower.contains('mesh') || lower.contains('relay')) {
      replyText = 'Yes, local packet broadcasting acts as our mesh.';
    }

    _roomMessages.add(
      Message(
        id: 'msg_reply_sim_${DateTime.now().millisecondsSinceEpoch}',
        senderId: replier.id,
        senderAlias: replier.alias,
        content: replyText,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      ),
    );
    _packetsProcessed += 1;
    notifyListeners();
  }

  Peer _createDummyPeer(String id) {
    return Peer(
      id: id,
      alias: 'External Peer',
      avatarSeed: 888,
      lastSeen: DateTime.now(),
    );
  }

  @override
  void dispose() {
    if (YamiLinkFfiBridge.instance.isSupported) {
      YamiLinkFfiBridge.instance.stop();
    }
    _discoveryTimer?.cancel();
    _peerActivityTimer?.cancel();
    super.dispose();
  }
}

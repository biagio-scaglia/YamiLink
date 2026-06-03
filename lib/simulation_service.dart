import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';

class SimulationService extends ChangeNotifier {
  final EphemeralProfile profile;
  
  // State
  List<Peer> _peers = [];
  List<Message> _roomMessages = [];
  Map<String, List<Message>> _directMessages = {}; // peerId -> messageList
  bool _isScanning = false;
  bool _relayEnabled = true;
  int _packetsProcessed = 142;
  double _signalStrength = 0.85;

  Timer? _discoveryTimer;
  Timer? _peerActivityTimer;
  final Random _random = Random();

  SimulationService({required this.profile}) {
    // Generate initial message history to make the app feel alive
    _generateInitialHistory();
  }

  // Getters
  List<Peer> get peers => _peers;
  List<Message> get roomMessages => _roomMessages;
  List<Message> getDirectMessages(String peerId) => _directMessages[peerId] ?? [];
  bool get isScanning => _isScanning;
  bool get relayEnabled => _relayEnabled;
  int get packetsProcessed => _packetsProcessed;
  double get signalStrength => _signalStrength;

  // Preset cool names for simulated peers
  final List<String> _simulatedNames = [
    'Alice_Proximity',
    'Ghost-404',
    'NebulaSeeker',
    'QuantumPioneer',
    'CyberShell',
    'AtlasNode',
    'EchoZero',
    'ShadowNet',
    'GridRouter-07',
    'RescueBeacon_B3'
  ];

  void _generateInitialHistory() {
    final now = DateTime.now();
    _roomMessages = [
      Message(
        id: 'msg_init_1',
        senderId: 'peer_atlas',
        senderAlias: 'AtlasNode',
        content: 'Benvenuti nel canale locale YamiLink! Qualcuno sa se il workshop di UX è iniziato?',
        timestamp: now.subtract(const Duration(minutes: 5)),
        status: MessageStatus.delivered,
      ),
      Message(
        id: 'msg_init_2',
        senderId: 'peer_nebula',
        senderAlias: 'NebulaSeeker',
        content: 'Sì, è in aula B. C\'è un sacco di gente però.',
        timestamp: now.subtract(const Duration(minutes: 3)),
        status: MessageStatus.delivered,
      ),
    ];
  }

  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    // Populate initial peers
    _spawnInitialPeers();

    // Periodically search for new peers, updates distances or packets
    _discoveryTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _updatePeerList();
    });

    // Periodically send simulated messages in the Room chat
    _peerActivityTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _simulatePeerRoomMessage();
    });
  }

  void stopScanning() {
    _isScanning = false;
    _discoveryTimer?.cancel();
    _peerActivityTimer?.cancel();
    notifyListeners();
  }

  void toggleRelay() {
    _relayEnabled = !_relayEnabled;
    _packetsProcessed += 5;
    notifyListeners();
  }

  void _spawnInitialPeers() {
    final now = DateTime.now();
    _peers = [
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
    ];
    notifyListeners();
  }

  void _updatePeerList() {
    if (!_isScanning) return;
    
    _packetsProcessed += _random.nextInt(12) + 3;
    _signalStrength = 0.7 + _random.nextDouble() * 0.25;

    // 1. Randomly update distance of existing peers
    for (var peer in _peers) {
      if (_random.nextDouble() > 0.6) {
        final hints = ProximityHint.values;
        peer.proximityHint = hints[_random.nextInt(hints.length - 1)]; // Avoid unknown
        peer.lastSeen = DateTime.now();
      }
    }

    // 2. Randomly add a new peer (up to max 8)
    if (_peers.length < 8 && _random.nextDouble() > 0.7) {
      final availableNames = _simulatedNames.where((name) => !_peers.any((p) => p.alias == name)).toList();
      if (availableNames.isNotEmpty) {
        final name = availableNames[_random.nextInt(availableNames.length)];
        final newPeer = Peer(
          id: 'peer_${name.toLowerCase()}',
          alias: name,
          avatarSeed: _random.nextInt(100000),
          proximityHint: ProximityHint.values[_random.nextInt(3)],
          relayCapability: _random.nextBool(),
          lastSeen: DateTime.now(),
        );
        _peers.add(newPeer);
      }
    }

    // 3. Randomly drop a far peer (leaving the physical space)
    if (_peers.length > 3 && _random.nextDouble() > 0.85) {
      final farPeers = _peers.where((p) => p.proximityHint == ProximityHint.far).toList();
      if (farPeers.isNotEmpty) {
        final removeMe = farPeers[_random.nextInt(farPeers.length)];
        _peers.remove(removeMe);
      }
    }

    notifyListeners();
  }

  void sendBroadcastMessage(String content) {
    if (content.trim().isEmpty) return;

    final userMsg = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: profile.id,
      senderAlias: profile.alias,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );

    _roomMessages.add(userMsg);
    _packetsProcessed += 1;
    notifyListeners();

    // Trigger simulation response
    Timer(Duration(milliseconds: 1000 + _random.nextInt(1500)), () {
      _simulateReplyTo(content);
    });
  }

  void _simulatePeerRoomMessage() {
    if (_peers.isEmpty) return;
    final randomPeer = _peers[_random.nextInt(_peers.length)];
    final sentences = [
      'Qualcuno sa a che ora chiude il padiglione?',
      'Il segnale qui è ottimo, il relay mesh funziona a meraviglia!',
      'Avete visto il prototipo esposto all\'ingresso?',
      'Ciao a tutti! Sono appena entrato in zona.',
      'Rete locale stabilissima 👍',
    ];

    final msg = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: randomPeer.id,
      senderAlias: randomPeer.alias,
      content: sentences[_random.nextInt(sentences.length)],
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );

    _roomMessages.add(msg);
    _packetsProcessed += 1;
    notifyListeners();
  }

  void _simulateReplyTo(String originalText) {
    if (_peers.isEmpty) return;
    
    // Pick an active peer to reply
    final replier = _peers[_random.nextInt(_peers.length)];
    String replyText = '';

    final lower = originalText.toLowerCase();
    if (lower.contains('ciao') || lower.contains('hello')) {
      replyText = 'Ciao ${profile.alias}! Come va qui a YamiLink?';
    } else if (lower.contains('funziona') || lower.contains('mesh')) {
      replyText = 'Sì! Sfrutta il Wi-Fi locale e il Bluetooth per fare routing 1-hop.';
    } else if (lower.contains('chi sei') || lower.contains('identità')) {
      replyText = 'Sono un peer temporaneo locale, la mia chiave scade quando esco.';
    } else {
      final answers = [
        'Interessante, ne stavamo parlando proprio ora.',
        'Ricevuto forte e chiaro sul mio nodo!',
        'Concordo in pieno.',
        'Chi c\'è per fare due chiacchiere tra poco?',
      ];
      replyText = answers[_random.nextInt(answers.length)];
    }

    final replyMsg = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: replier.id,
      senderAlias: replier.alias,
      content: replyText,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );

    _roomMessages.add(replyMsg);
    _packetsProcessed += 1;
    notifyListeners();
  }

  void sendDirectMessage(String peerId, String content) {
    if (content.trim().isEmpty) return;

    final userMsg = Message(
      id: 'msg_dm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: profile.id,
      senderAlias: profile.alias,
      recipientId: peerId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _directMessages.putIfAbsent(peerId, () => []).add(userMsg);
    notifyListeners();

    // Simulate 1-hop delay & delivery status
    Timer(const Duration(milliseconds: 600), () {
      userMsg.status = MessageStatus.delivered;
      _packetsProcessed += 1;
      notifyListeners();

      // Trigger automatic peer reply
      Timer(const Duration(seconds: 2), () {
        final peer = _peers.firstWhere((p) => p.id == peerId, orElse: () => _createDummyPeer(peerId));
        final replies = [
          'Messaggio cifrato ricevuto! Ottima questa connessione protetta.',
          'Ti sento forte e chiaro peer-to-peer.',
          'Sì, ci vediamo vicino allo stand tra 10 minuti.',
          'Ricevuto! Ricordati che questa chat svanirà appena ci allontaniamo.'
        ];
        
        final peerReply = Message(
          id: 'msg_dm_reply_${DateTime.now().millisecondsSinceEpoch}',
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

  Peer _createDummyPeer(String id) {
    return Peer(
      id: id,
      alias: 'Unknown Peer',
      avatarSeed: 999,
      lastSeen: DateTime.now(),
    );
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

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _peerActivityTimer?.cancel();
    super.dispose();
  }
}

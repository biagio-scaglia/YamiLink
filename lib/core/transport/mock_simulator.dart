import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'transport_interface.dart';
import '../protocol/frame.dart';

class MockSimulatorTransport implements DiscoveryTransport, MessageTransport {
  final String userAlias;
  final int userSeed;
  final String userNodeId;

  bool _isScanning = false;
  void Function(String nodeHash, String alias, int seed, double rssi)?
  _onPeerFound;
  void Function(String nodeHash)? _onPeerLost;
  void Function(String senderHash, Uint8List packetBytes)? _onDataReceived;

  Timer? _discoveryTimer;
  Timer? _replyTimer;
  final List<String> _simulatedPeers = [
    'peer_alice',
    'peer_ghost',
    'peer_atlas',
  ];
  final List<String> _simulatedNames = [
    'Alice_Proximity',
    'Ghost-404',
    'AtlasNode',
    'NebulaSeeker',
    'QuantumPioneer',
  ];
  final Map<String, int> _peerSeeds = {
    'peer_alice': 1042,
    'peer_ghost': 5041,
    'peer_atlas': 9811,
    'peer_nebula': 7721,
    'peer_quantum': 3304,
  };

  final Random _random = Random();

  MockSimulatorTransport({
    required this.userAlias,
    required this.userSeed,
    required this.userNodeId,
  });

  @override
  bool get isScanning => _isScanning;

  @override
  void startDiscovery({
    required void Function(String nodeHash, String alias, int seed, double rssi)
    onPeerFound,
    required void Function(String nodeHash) onPeerLost,
  }) {
    if (_isScanning) return;
    _isScanning = true;
    _onPeerFound = onPeerFound;
    _onPeerLost = onPeerLost;

    // Immediately trigger initial peers discovery
    Timer(const Duration(milliseconds: 200), () {
      if (!_isScanning) return;
      _onPeerFound?.call('peer_alice', 'Alice_Proximity', 1042, 0.95);
      _onPeerFound?.call('peer_ghost', 'Ghost-404', 5041, 0.65);
      _onPeerFound?.call('peer_atlas', 'AtlasNode', 9811, 0.45);
    });

    // Periodic peer discovery timer
    _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isScanning) return;
      _simulatePeerBeacon();
    });
  }

  @override
  void stopDiscovery() {
    _isScanning = false;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
  }

  @override
  Future<bool> sendBroadcast(Uint8List packetBytes) async {
    // Mimic local loopback delay and echo response
    final rawText = utf8.decode(packetBytes);
    try {
      final frame = Frame.deserialize(rawText);
      _simulateDelayedReply(frame);
    } catch (e) {
      // Ignored if invalid format
    }
    return true;
  }

  @override
  Future<bool> sendDirect(String recipientHash, Uint8List packetBytes) async {
    final rawText = utf8.decode(packetBytes);
    try {
      final frame = Frame.deserialize(rawText);
      _simulateDirectReply(frame);
    } catch (e) {
      // Ignored
    }
    return true;
  }

  @override
  void registerReceiveCallback(
    void Function(String senderHash, Uint8List packetBytes) onDataReceived,
  ) {
    _onDataReceived = onDataReceived;
  }

  @override
  void clearReceiveCallback() {
    _onDataReceived = null;
  }

  void _simulatePeerBeacon() {
    if (_random.nextDouble() > 0.7 && _simulatedPeers.length < 8) {
      final newIndex = _simulatedPeers.length;
      if (newIndex < _simulatedNames.length) {
        final name = _simulatedNames[newIndex];
        final id = 'peer_${name.toLowerCase().replaceAll("-", "_")}';
        final seed = _random.nextInt(10000) + 1000;
        _peerSeeds[id] = seed;
        _simulatedPeers.add(id);
        _onPeerFound?.call(id, name, seed, 0.5 + _random.nextDouble() * 0.4);
      }
    }
  }

  void _simulateDelayedReply(Frame userFrame) {
    if (userFrame.type != FrameType.roomMsg) return;

    _replyTimer?.cancel();
    _replyTimer = Timer(
      Duration(milliseconds: 1500 + _random.nextInt(1500)),
      () {
        if (_onDataReceived == null || _simulatedPeers.isEmpty) return;

        final peerId = _simulatedPeers[_random.nextInt(_simulatedPeers.length)];
        final name = peerId == 'peer_alice'
            ? 'Alice_Proximity'
            : (peerId == 'peer_ghost' ? 'Ghost-404' : 'AtlasNode');

        String replyText = 'Received on my node! Clean connection.';
        final lower = userFrame.payloadBody.toLowerCase();
        if (lower.contains('hello') || lower.contains('hi')) {
          replyText =
              'Hi ${userFrame.senderId}! Welcome to the physical space.';
        } else if (lower.contains('mesh') || lower.contains('relay')) {
          replyText = 'Yes, local packet broadcasting acts as our mesh.';
        }

        final replyFrame = Frame(
          type: FrameType.roomMsg,
          senderId: peerId,
          recipientId: '*',
          sessionId: 'sim_session_id',
          messageId: _random.nextInt(10000),
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payloadBody: replyText,
        );

        final replyBytes = utf8.encode(replyFrame.serialize()) as Uint8List;
        _onDataReceived?.call(peerId, replyBytes);
      },
    );
  }

  void _simulateDirectReply(Frame userFrame) {
    if (userFrame.type != FrameType.directMsg) return;

    // Send ACK first
    Timer(const Duration(milliseconds: 100), () {
      final ackFrame = Frame(
        type: FrameType.ack,
        senderId: userFrame.recipientId,
        recipientId: userFrame.senderId,
        sessionId: userFrame.sessionId,
        messageId: userFrame.messageId, // Matching MSG ID
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payloadBody: '',
      );
      final ackBytes = utf8.encode(ackFrame.serialize()) as Uint8List;
      _onDataReceived?.call(userFrame.recipientId, ackBytes);
    });

    // Send actual direct reply after a short delay
    Timer(const Duration(milliseconds: 2000), () {
      if (_onDataReceived == null) return;

      final replies = [
        'Direct message processed securely.',
        'Got it, meet you there!',
        'Understood, over and out.',
      ];

      final replyFrame = Frame(
        type: FrameType.directMsg,
        senderId: userFrame.recipientId,
        recipientId: userFrame.senderId,
        sessionId: userFrame.sessionId,
        messageId: _random.nextInt(10000),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payloadBody: replies[_random.nextInt(replies.length)],
      );

      final replyBytes = utf8.encode(replyFrame.serialize()) as Uint8List;
      _onDataReceived?.call(userFrame.recipientId, replyBytes);
    });
  }
}

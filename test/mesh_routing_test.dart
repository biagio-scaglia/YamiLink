import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/models.dart';
import 'package:yamilink/repository/yamilink_repository.dart';
import 'package:yamilink/core/transport/transport_interface.dart';

class FakeMessageTransport implements DiscoveryTransport, MessageTransport {
  void Function(String nodeHash, String alias, int seed, double rssi)? onPeerFoundCallback;
  void Function(String nodeHash)? onPeerLostCallback;
  void Function(String senderHash, Uint8List packetBytes)? onDataReceivedCallback;
  @override
  bool isScanning = false;
  final List<Uint8List> sentPackets = [];
  final List<String> sentRecipients = [];

  @override
  void startDiscovery({
    required void Function(String nodeHash, String alias, int seed, double rssi) onPeerFound,
    required void Function(String nodeHash) onPeerLost,
  }) {
    onPeerFoundCallback = onPeerFound;
    onPeerLostCallback = onPeerLost;
    isScanning = true;
  }

  @override
  void stopDiscovery() {
    isScanning = false;
  }

  @override
  Future<bool> sendBroadcast(Uint8List packetBytes) async {
    sentPackets.add(packetBytes);
    sentRecipients.add('*');
    return true;
  }

  @override
  Future<bool> sendDirect(String recipientHash, Uint8List packetBytes) async {
    sentPackets.add(packetBytes);
    sentRecipients.add(recipientHash);
    return true;
  }

  @override
  void registerReceiveCallback(
    void Function(String senderHash, Uint8List packetBytes) onDataReceived,
  ) {
    onDataReceivedCallback = onDataReceived;
  }

  @override
  void clearReceiveCallback() {
    onDataReceivedCallback = null;
  }
}

void main() {
  group('YamiLink Epidemic Mesh Routing Tests', () {
    late EphemeralProfile profile;
    late FakeMessageTransport transport;
    late YamiLinkRepository repository;

    setUp(() {
      profile = EphemeralProfile(
        id: 'local_node',
        alias: 'LocalNode',
        avatarSeed: 42,
        createdAt: DateTime.now(),
      );
      transport = FakeMessageTransport();
      repository = YamiLinkRepository(
        profile: profile,
        discoveryTransport: transport,
        messageTransport: transport,
      );
      repository.startScanning();
    });

    tearDown(() {
      repository.dispose();
    });

    test('Outgoing broadcast frame starts with hopCount = 1', () {
      repository.sendBroadcastMessage('Test message');
      expect(transport.sentPackets.length, 1);

      final rawText = utf8.decode(transport.sentPackets.first);
      final frame = Frame.deserialize(rawText);
      expect(frame.hopCount, 1);
    });

    test('Relays Room Broadcast message and increments hopCount', () {
      final incomingFrame = Frame(
        type: FrameType.roomMsg,
        senderId: 'peer_sender',
        recipientId: '*',
        sessionId: 'sess_abc',
        messageId: 501,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBody: 'Broadcast test',
      );

      final incomingBytes = utf8.encode(incomingFrame.serialize());
      transport.onDataReceivedCallback?.call('peer_sender', incomingBytes);

      expect(repository.roomMessages.length, 3);
      expect(repository.roomMessages.last.content, 'Broadcast test');
      expect(repository.roomMessages.last.hopCount, 1);

      expect(transport.sentPackets.length, 1);
      final relayedText = utf8.decode(transport.sentPackets.first);
      final relayedFrame = Frame.deserialize(relayedText);
      expect(relayedFrame.hopCount, 2);
      expect(relayedFrame.senderId, 'peer_sender');
      expect(relayedFrame.recipientId, '*');
    });

    test('Seen cache prevents packet loops', () {
      final incomingFrame = Frame(
        type: FrameType.roomMsg,
        senderId: 'peer_sender',
        recipientId: '*',
        sessionId: 'sess_abc',
        messageId: 502,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBody: 'Unique payload',
      );

      final incomingBytes = utf8.encode(incomingFrame.serialize());
      transport.onDataReceivedCallback?.call('peer_sender', incomingBytes);
      expect(transport.sentPackets.length, 1);

      transport.onDataReceivedCallback?.call('peer_sender', incomingBytes);
      expect(transport.sentPackets.length, 1);
    });

    test('Relays DM addressed to others and does not save in local state', () {
      final incomingFrame = Frame(
        type: FrameType.directMsg,
        senderId: 'alice',
        recipientId: 'charlie',
        sessionId: 'sess_abc',
        messageId: 701,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBody: 'Secret DM for Charlie',
      );

      final incomingBytes = utf8.encode(incomingFrame.serialize());
      transport.onDataReceivedCallback?.call('alice', incomingBytes);

      expect(repository.conversations.isEmpty, true);
      expect(repository.getDirectMessages('alice').isEmpty, true);

      expect(transport.sentPackets.length, 1);
      expect(transport.sentRecipients.first, 'charlie');

      final relayedText = utf8.decode(transport.sentPackets.first);
      final relayedFrame = Frame.deserialize(relayedText);
      expect(relayedFrame.hopCount, 2);
      expect(relayedFrame.payloadBody, 'Secret DM for Charlie');
    });

    test('Relays ACK addressed to others and does not process locally', () {
      final incomingFrame = Frame(
        type: FrameType.ack,
        senderId: 'charlie',
        recipientId: 'alice',
        sessionId: 'sess_abc',
        messageId: 701,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBody: '',
      );

      final incomingBytes = utf8.encode(incomingFrame.serialize());
      transport.onDataReceivedCallback?.call('charlie', incomingBytes);

      expect(transport.sentPackets.length, 1);
      expect(transport.sentRecipients.first, 'alice');

      final relayedText = utf8.decode(transport.sentPackets.first);
      final relayedFrame = Frame.deserialize(relayedText);
      expect(relayedFrame.hopCount, 2);
      expect(relayedFrame.type, FrameType.ack);
    });

    test('End-to-end multi-hop DM delivery and acknowledgment', () {
      repository.sendDirectMessage('peer_destination', 'Ping DM');
      expect(transport.sentPackets.length, 1);
      expect(transport.sentRecipients.first, 'peer_destination');

      final msg = repository.getDirectMessages('peer_destination').first;
      expect(msg.status, MessageStatus.sending);

      final ackFrame = Frame(
        type: FrameType.ack,
        senderId: 'peer_destination',
        recipientId: 'local_node',
        sessionId: 'sess_any',
        messageId: 100,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 2,
        payloadBody: '',
      );

      final ackBytes = utf8.encode(ackFrame.serialize());
      transport.onDataReceivedCallback?.call('peer_destination', ackBytes);

      expect(
        repository.getDirectMessages('peer_destination').first.status,
        MessageStatus.delivered,
      );
    });
  });
}

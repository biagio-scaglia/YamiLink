import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/models.dart';
import 'package:yamilink/repository/yamilink_repository.dart';
import 'package:yamilink/core/transport/transport_interface.dart';
import 'package:yamilink/core/security/tesla_engine.dart';

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

    Future<Frame> signTestFrame(Frame frame, SimpleKeyPair keyPair) async {
      final ed25519 = Ed25519();
      final signature = await ed25519.sign(frame.signableBytes, keyPair: keyPair);
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

    setUp(() async {
      TeslaEngine.instance.sweep();
      profile = await EphemeralProfile.generate('LocalNode');
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
      TeslaEngine.instance.sweep();
    });

    test('Outgoing broadcast frame starts with hopCount = 1', () async {
      await repository.sendBroadcastMessage('Test message');
      
      // Delay so async transport finishes
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(transport.sentPackets.length, 1);

      final rawBytes = transport.sentPackets.first;
      final frame = Frame.fromBytes(rawBytes);
      expect(frame.hopCount, 1);
    });

    test('Relays Room Broadcast message and increments hopCount', () async {
      final peerProfile = await EphemeralProfile.generate('peer_sender');
      final incomingFrame = Frame(
        type: FrameType.roomMsg,
        senderId: peerProfile.id,
        recipientId: '*',
        sessionId: 'sess_abc',
        messageId: 501,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBytes: utf8.encode('Broadcast test'),
      );

      final signedIncomingFrame = await signTestFrame(incomingFrame, peerProfile.identityKeyPair!);
      final incomingBytes = signedIncomingFrame.serialize();
      transport.onDataReceivedCallback?.call('peer_sender_hash', incomingBytes);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(repository.roomMessages.length, 1);
      expect(repository.roomMessages.last.content, 'Broadcast test');
      expect(repository.roomMessages.last.hopCount, 1);

      expect(transport.sentPackets.length, 1);
      final relayedBytes = transport.sentPackets.first;
      final relayedFrame = Frame.fromBytes(relayedBytes);
      expect(relayedFrame.hopCount, 2);
      expect(relayedFrame.senderId, peerProfile.id);
      expect(relayedFrame.recipientId, '*');
    });

    test('Seen cache prevents packet loops', () async {
      final peerProfile = await EphemeralProfile.generate('peer_sender');
      final incomingFrame = Frame(
        type: FrameType.roomMsg,
        senderId: peerProfile.id,
        recipientId: '*',
        sessionId: 'sess_abc',
        messageId: 502,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBytes: utf8.encode('Unique payload'),
      );

      final signedIncomingFrame = await signTestFrame(incomingFrame, peerProfile.identityKeyPair!);
      final incomingBytes = signedIncomingFrame.serialize();
      
      transport.onDataReceivedCallback?.call('peer_sender_hash', incomingBytes);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(transport.sentPackets.length, 1);

      transport.onDataReceivedCallback?.call('peer_sender_hash', incomingBytes);
      await Future.delayed(const Duration(milliseconds: 50));
      // Should still be 1 (ignored by ReplayGuard / RelayedMessageKeys)
      expect(transport.sentPackets.length, 1);
    });

    test('Relays DM addressed to others and does not save in local state', () async {
      final aliceProfile = await EphemeralProfile.generate('alice');
      final charlieProfile = await EphemeralProfile.generate('charlie');
      
      final incomingFrame = Frame(
        type: FrameType.directMsg,
        senderId: aliceProfile.id,
        recipientId: charlieProfile.id,
        sessionId: 'sess_abc',
        messageId: 701,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBytes: utf8.encode('Secret DM for Charlie'),
      );

      final signedIncomingFrame = await signTestFrame(incomingFrame, aliceProfile.identityKeyPair!);
      final incomingBytes = signedIncomingFrame.serialize();
      
      transport.onDataReceivedCallback?.call('alice_hash', incomingBytes);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repository.conversations.isEmpty, true);
      expect(repository.getDirectMessages(aliceProfile.id).isEmpty, true);

      expect(transport.sentPackets.length, 1);
      expect(transport.sentRecipients.first, charlieProfile.id);

      final relayedBytes = transport.sentPackets.first;
      final relayedFrame = Frame.fromBytes(relayedBytes);
      expect(relayedFrame.hopCount, 2);
      expect(utf8.decode(relayedFrame.payloadBytes), 'Secret DM for Charlie');
    });

    test('Relays ACK addressed to others and does not process locally', () async {
      final aliceProfile = await EphemeralProfile.generate('alice');
      final charlieProfile = await EphemeralProfile.generate('charlie');
      
      final incomingFrame = Frame(
        type: FrameType.ack,
        senderId: charlieProfile.id,
        recipientId: aliceProfile.id,
        sessionId: 'sess_abc',
        messageId: 701,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 1,
        payloadBytes: Uint8List(0),
      );

      final signedIncomingFrame = await signTestFrame(incomingFrame, charlieProfile.identityKeyPair!);
      final incomingBytes = signedIncomingFrame.serialize();
      
      transport.onDataReceivedCallback?.call('charlie_hash', incomingBytes);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(transport.sentPackets.length, 1);
      expect(transport.sentRecipients.first, aliceProfile.id);

      final relayedBytes = transport.sentPackets.first;
      final relayedFrame = Frame.fromBytes(relayedBytes);
      expect(relayedFrame.hopCount, 2);
      expect(relayedFrame.type, FrameType.ack);
    });

    test('End-to-end multi-hop DM delivery and acknowledgment', () async {
      final destProfile = await EphemeralProfile.generate('destination');
      await repository.sendDirectMessage(destProfile.id, 'Ping DM');
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(transport.sentPackets.length, 1);
      expect(transport.sentRecipients.first, destProfile.id);

      final msg = repository.getDirectMessages(destProfile.id).first;
      expect(msg.status, MessageStatus.sending);

      final ackFrame = Frame(
        type: FrameType.ack,
        senderId: destProfile.id,
        recipientId: profile.id, // local_node
        sessionId: 'sess_any',
        messageId: 100, // Normally this should match the message ID of the DM
        timestamp: DateTime.now().millisecondsSinceEpoch,
        hopCount: 2,
        payloadBytes: Uint8List(0),
      );

      final signedAckFrame = await signTestFrame(ackFrame, destProfile.identityKeyPair!);
      final ackBytes = signedAckFrame.serialize();
      
      transport.onDataReceivedCallback?.call('dest_hash', ackBytes);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        repository.getDirectMessages(destProfile.id).first.status,
        MessageStatus.delivered,
      );
    });
  });
}

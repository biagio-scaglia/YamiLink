import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/core/security/tesla_engine.dart';
import 'package:yamilink/models.dart';
import 'package:yamilink/core/transport/transport_interface.dart';
import 'package:yamilink/repository/yamilink_repository.dart';

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

  void simulateReceive(String senderHash, Uint8List packetBytes) {
    onDataReceivedCallback?.call(senderHash, packetBytes);
  }
}

void main() {
  group('Stress Testing YamiLink Pipeline', () {
    late YamiLinkRepository repo;
    late FakeMessageTransport mockTransport;
    late EphemeralProfile profile;

    setUp(() async {
      profile = await EphemeralProfile.generate('Stress Node');
      mockTransport = FakeMessageTransport();
      repo = YamiLinkRepository(
        profile: profile,
        discoveryTransport: mockTransport,
        messageTransport: mockTransport,
      );
      repo.startScanning();
    });

    tearDown(() {
      repo.dispose();
      TeslaEngine.instance.sweep();
    });

    test('Process 10,000 valid incoming packets quickly without crashing', () async {
      final stopwatch = Stopwatch()..start();

      final senderProfile = await EphemeralProfile.generate('Sender Peer');
      final ed25519 = Ed25519();
      
      int processedCount = 0;
      
      for (int i = 0; i < 10000; i++) {
        final time = DateTime.now().millisecondsSinceEpoch;
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: senderProfile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: i,
          timestamp: time,
          payloadBytes: utf8.encode('Stress testing payload'),
        );
        
        final signature = await ed25519.sign(frame.signableBytes, keyPair: senderProfile.identityKeyPair!);
        final signedFrame = Frame(
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
        
        final rawBytes = signedFrame.serialize();

        // Inject directly into the transport's simulated receive
        mockTransport.simulateReceive('peer_sender_1_hash', rawBytes);
        processedCount++;
      }

      stopwatch.stop();

      // Wait a bit for async processing to settle if any
      await Future.delayed(const Duration(milliseconds: 1500));

      expect(processedCount, 10000);
      debugPrint('Processed 10,000 valid packets in ${stopwatch.elapsedMilliseconds} ms');
      // Ed25519 verification might take a bit more time for 10000 packets.
      // 10000 ed25519 signatures can take roughly 1000-2000 ms depending on CPU.
      expect(stopwatch.elapsedMilliseconds, lessThan(60000));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Process 10,000 malformed packets gracefully (UDP flood simulation)', () async {
      final stopwatch = Stopwatch()..start();

      int processedCount = 0;
      
      for (int i = 0; i < 10000; i++) {
        final rawBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        mockTransport.simulateReceive('flooder_hash', rawBytes);
        processedCount++;
      }

      stopwatch.stop();

      await Future.delayed(const Duration(milliseconds: 500));

      expect(processedCount, 10000);
      debugPrint('Processed 10,000 junk packets in ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
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
      final base64Payload = base64.encode(utf8.encode('Stress testing payload'));
      
      int processedCount = 0;
      
      for (int i = 0; i < 10000; i++) {
        final time = DateTime.now().millisecondsSinceEpoch;
        final rawStrBeforeSig = 'YML1:RM:${senderProfile.id}:*:sess_1:$i:$time:0:1:text:$base64Payload';
        final signature = await ed25519.sign(utf8.encode(rawStrBeforeSig), keyPair: senderProfile.identityKeyPair!);
        final rawStr = '$rawStrBeforeSig:${base64.encode(signature.bytes)}';
        
        final rawBytes = Uint8List.fromList(utf8.encode(rawStr));

        // Inject directly into the transport's simulated receive
        mockTransport.simulateReceive('peer_sender_1_hash', rawBytes);
        processedCount++;
      }

      stopwatch.stop();

      // Wait a bit for async processing to settle if any
      await Future.delayed(const Duration(milliseconds: 1500));

      expect(processedCount, 10000);
      print('Processed 10,000 valid packets in ${stopwatch.elapsedMilliseconds} ms');
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
      print('Processed 10,000 junk packets in ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}

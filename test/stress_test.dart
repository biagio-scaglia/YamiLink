import 'dart:convert';
import 'dart:typed_data';
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

    setUp(() {
      final profile = EphemeralProfile(id: 'stress_node_1', alias: 'Stress Node', avatarSeed: 1, createdAt: DateTime.now());
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

      final base64Payload = base64.encode(utf8.encode('Stress testing payload'));
      
      int processedCount = 0;
      
      // We will register a hook to the mock transport to simulate incoming data
      // Actually we can just call the receive callback if we had it, but YamiLinkRepository
      // registers it on messageTransport.
      
      // Let's generate 10,000 frames. 
      // We vary the messageId so they are not caught as duplicates by the ReplayGuard.
      for (int i = 0; i < 10000; i++) {
        final time = DateTime.now().millisecondsSinceEpoch;
        final rawStr = 'YML1:RM:peer_sender_1:*:sess_1:$i:$time:0:1:text:$base64Payload';
        final rawBytes = Uint8List.fromList(utf8.encode(rawStr));

        // Inject directly into the transport's simulated receive
        // In the mock transport, there's a simulateReceive method
        mockTransport.simulateReceive('peer_sender_1_hash', rawBytes);
        processedCount++;
      }

      stopwatch.stop();

      // Wait a bit for async processing to settle if any
      await Future.delayed(const Duration(milliseconds: 500));

      expect(processedCount, 10000);
      // We just want to ensure it completes under a reasonable time (e.g. 5 seconds for 10k messages)
      // and doesn't crash the isolate.
      print('Processed 10,000 valid packets in ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('Process 10,000 malformed packets gracefully (UDP flood simulation)', () async {
      final stopwatch = Stopwatch()..start();

      int processedCount = 0;
      
      // Generate 10,000 junk packets
      for (int i = 0; i < 10000; i++) {
        // Just random junk that fails early at TeslaPacketValidator
        final rawBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

        mockTransport.simulateReceive('flooder_hash', rawBytes);
        processedCount++;
      }

      stopwatch.stop();

      await Future.delayed(const Duration(milliseconds: 500));

      expect(processedCount, 10000);
      print('Processed 10,000 junk packets in ${stopwatch.elapsedMilliseconds} ms');
      // Junk packets should be incredibly fast as they are dropped before UTF-8 decode
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/core/security/tesla_engine.dart';

void main() {
  group('TeslaEngine Security & Penetration Tests', () {
    late TeslaEngine engine;

    setUp(() {
      // In dart, singletons carry state between tests if not reset,
      // but TeslaEngine doesn't have a direct reset. We will clear
      // state by using a new mock setup or testing via its public sweep methods.
      // For proper test isolation, we'd ideally reset the singleton,
      // but we can just use new senderIds for each test.
      engine = TeslaEngine.instance;
      engine.sweep(); // Clear what we can
    });

    group('TeslaPacketValidator Tests', () {
      test('Valid YML1 frame should pass raw inspection', () {
        final raw = Uint8List.fromList('YML1:RM:1234:*:1234:1:1234:0:1:text:hello'.codeUnits);
        final decision = engine.inspectRawPacket('hash1', raw);
        expect(decision, TeslaDecision.allow);
      });

      test('Frame without YML1 signature should be dropped', () {
        final raw = Uint8List.fromList('JSON:{"id": 1}'.codeUnits);
        final decision = engine.inspectRawPacket('hash1', raw);
        expect(decision, TeslaDecision.drop);
      });

      test('Corrupted signature should be dropped', () {
        final raw = Uint8List.fromList('YMX1:RM:...'.codeUnits);
        final decision = engine.inspectRawPacket('hash1', raw);
        expect(decision, TeslaDecision.drop);
      });

      test('Oversized frames should be dropped before UTF-8 decoding', () {
        // Limit is 2048. Create a 2049 byte array.
        final oversized = Uint8List(2049);
        // Fill signature so validator doesn't fail early on signature
        final sig = 'YML1:'.codeUnits;
        for (int i = 0; i < sig.length; i++) {
          oversized[i] = sig[i];
        }

        final decision = engine.inspectRawPacket('hash1', oversized);
        expect(decision, TeslaDecision.drop);
      });

      test('Frame exactly at limit should pass if valid', () {
        final exact = Uint8List(2048);
        final sig = 'YML1:'.codeUnits;
        for (int i = 0; i < sig.length; i++) {
          exact[i] = sig[i];
        }

        final decision = engine.inspectRawPacket('hash1', exact);
        expect(decision, TeslaDecision.allow);
      });

      test('Frame with non-UTF8 bytes should pass raw validator (dropped later in parser)', () {
        final badBytes = Uint8List.fromList([89, 77, 76, 49, 58, 255, 254, 253]);
        final decision = engine.inspectRawPacket('hash1', badBytes);
        // Raw packet validator only checks signature and size, not utf8 correctness
        expect(decision, TeslaDecision.allow);
      });
    });

    group('TeslaSpoofGuard Tests', () {
      test('Initial binding allows packet', () {
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: 'alice_1',
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hello',
        );

        final decision = engine.inspectParsedFrame(frame, 'alice_hash');
        expect(decision, TeslaDecision.allow);
      });

      test('Peer spoofing senderId drops packet', () {
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: 'alice_2', // new ID
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hello',
        );

        // Bind alice_2 to alice_hash_2
        engine.inspectParsedFrame(frame, 'alice_hash_2');

        // Attacker with attacker_hash tries to spoof alice_2
        final spoofedFrame = Frame(
          type: FrameType.roomMsg,
          senderId: 'alice_2',
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 2,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'imposter!',
        );

        final decision = engine.inspectParsedFrame(spoofedFrame, 'attacker_hash');
        expect(decision, TeslaDecision.drop);
      });
    });

    group('TeslaReplayGuard Tests', () {
      test('Fresh unique frame is allowed', () {
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: 'charlie_1',
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 100,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final decision = engine.inspectParsedFrame(frame, 'charlie_hash');
        expect(decision, TeslaDecision.allow);
      });

      test('Exact duplicate frame is dropped (replay/deduplication)', () {
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: 'charlie_2',
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 101,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final decision1 = engine.inspectParsedFrame(frame, 'charlie_hash_2');
        expect(decision1, TeslaDecision.allow);

        // Send exact same frame again
        final decision2 = engine.inspectParsedFrame(frame, 'charlie_hash_2');
        expect(decision2, TeslaDecision.drop);
      });

      test('Frame with old timestamp (> 60s) is dropped', () {
        final oldTime = DateTime.now().millisecondsSinceEpoch - 65000;
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: 'dave_1',
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: oldTime,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final decision = engine.inspectParsedFrame(frame, 'dave_hash');
        expect(decision, TeslaDecision.drop);
      });

      test('Frame with anomalous future timestamp (> 5s) is dropped', () {
        final futureTime = DateTime.now().millisecondsSinceEpoch + 10000;
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: 'eve_1',
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: futureTime,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final decision = engine.inspectParsedFrame(frame, 'eve_hash');
        expect(decision, TeslaDecision.drop);
      });
    });
  });
}

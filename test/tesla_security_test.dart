import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';
import 'package:yamilink/core/security/tesla_engine.dart';
import 'package:yamilink/models.dart';

void main() {
  group('TeslaEngine Security & Penetration Tests', () {
    late TeslaEngine engine;

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
        payloadType: frame.payloadType,
        payloadBody: frame.payloadBody,
        signature: base64.encode(signature.bytes),
      );
    }

    setUp(() {
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
        final oversized = Uint8List(2049);
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
        expect(decision, TeslaDecision.allow);
      });
    });

    group('TeslaSpoofGuard Tests', () {
      test('Valid PKI signed frame allows packet', () async {
        final profile = await EphemeralProfile.generate('alice');
        
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: profile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hello',
        );

        final signedFrame = await signTestFrame(frame, profile.identityKeyPair!);
        final decision = await engine.inspectParsedFrame(signedFrame, 'alice_hash');
        expect(decision, TeslaDecision.allow);
      });

      test('Peer spoofing senderId drops packet (bad PKI signature)', () async {
        final aliceProfile = await EphemeralProfile.generate('alice');
        final attackerProfile = await EphemeralProfile.generate('attacker');
        
        // Attacker creates a frame pretending to be alice
        final spoofedFrame = Frame(
          type: FrameType.roomMsg,
          senderId: aliceProfile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 2,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'imposter!',
        );

        // Attacker signs it with their own key, but senderId is alice's pub key
        final signedSpoofedFrame = await signTestFrame(spoofedFrame, attackerProfile.identityKeyPair!);
        final decision = await engine.inspectParsedFrame(signedSpoofedFrame, 'attacker_hash');
        expect(decision, TeslaDecision.drop);
      });
    });

    group('TeslaReplayGuard Tests', () {
      test('Fresh unique frame is allowed', () async {
        final profile = await EphemeralProfile.generate('charlie');
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: profile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 100,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final signedFrame = await signTestFrame(frame, profile.identityKeyPair!);
        final decision = await engine.inspectParsedFrame(signedFrame, 'charlie_hash');
        expect(decision, TeslaDecision.allow);
      });

      test('Exact duplicate frame is dropped (replay/deduplication)', () async {
        final profile = await EphemeralProfile.generate('charlie');
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: profile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 101,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final signedFrame = await signTestFrame(frame, profile.identityKeyPair!);
        final decision1 = await engine.inspectParsedFrame(signedFrame, 'charlie_hash_2');
        expect(decision1, TeslaDecision.allow);

        // Send exact same frame again
        final decision2 = await engine.inspectParsedFrame(signedFrame, 'charlie_hash_2');
        expect(decision2, TeslaDecision.drop);
      });

      test('Frame with old timestamp (> 60s) is dropped', () async {
        final profile = await EphemeralProfile.generate('dave');
        final oldTime = DateTime.now().millisecondsSinceEpoch - 65000;
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: profile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: oldTime,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final signedFrame = await signTestFrame(frame, profile.identityKeyPair!);
        final decision = await engine.inspectParsedFrame(signedFrame, 'dave_hash');
        expect(decision, TeslaDecision.drop);
      });

      test('Frame with anomalous future timestamp (> 5s) is dropped', () async {
        final profile = await EphemeralProfile.generate('eve');
        final futureTime = DateTime.now().millisecondsSinceEpoch + 10000;
        final frame = Frame(
          type: FrameType.roomMsg,
          senderId: profile.id,
          recipientId: '*',
          sessionId: 'sess_1',
          messageId: 1,
          timestamp: futureTime,
          flags: 0,
          hopCount: 1,
          payloadType: 'text',
          payloadBody: 'hi',
        );

        final signedFrame = await signTestFrame(frame, profile.identityKeyPair!);
        final decision = await engine.inspectParsedFrame(signedFrame, 'eve_hash');
        expect(decision, TeslaDecision.drop);
      });
    });
  });
}

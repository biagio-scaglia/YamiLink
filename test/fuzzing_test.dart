import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';

void main() {
  group('Fuzzing & Boundary Tests', () {
    final random = Random();

    Uint8List generateRandomBytes(int length) {
      final bytes = Uint8List(length);
      for (int i = 0; i < length; i++) {
        bytes[i] = random.nextInt(256);
      }
      return bytes;
    }

    test('Frame.fromBytes safely rejects completely random garbage strings', () {
      for (int i = 0; i < 100; i++) {
        final garbage = generateRandomBytes(random.nextInt(100) + 10);
        expect(() => Frame.fromBytes(garbage), throwsFormatException);
      }
    });

    test('Frame.fromBytes safely rejects frames that are too short', () {
      final badFrame = Uint8List(50); 
      badFrame[0] = 2; // Valid version, but too short
      expect(() => Frame.fromBytes(badFrame), throwsFormatException);
    });

    test('Frame.fromBytes safely rejects oversized payloads (based on actual buffer reading)', () {
      // Create a valid header but with a huge payload length indicator
      final frame = Frame(
        type: FrameType.roomMsg,
        senderId: 'A'*64,
        recipientId: 'B'*64,
        sessionId: '1234',
        messageId: 1,
        timestamp: 12345,
        payloadBytes: Uint8List(2000),
      );
      final bytes = frame.serialize(withSignature: false);
      expect(() => Frame.fromBytes(bytes), returnsNormally);

      // Now create a byte array with a length that is larger than the actual bytes available
      final truncatedBytes = bytes.sublist(0, bytes.length - 1000);
      expect(() => Frame.fromBytes(truncatedBytes), throwsFormatException);
    });

    test('Frame.fromBytes parses legitimate frame correctly', () {
      final payload = utf8.encode('Legit message');
      final time = DateTime.now().millisecondsSinceEpoch;
      
      final frame = Frame(
        type: FrameType.roomMsg,
        senderId: 'alice'.padRight(64, '0'), // Needs to be 64 chars hex string conceptually, but here just 64 chars
        recipientId: '*',
        sessionId: 'sess_1',
        messageId: 1,
        timestamp: time,
        flags: 0,
        hopCount: 1,
        payloadBytes: payload,
      );
      final goodBytes = frame.serialize(withSignature: false);
      
      final parsedFrame = Frame.fromBytes(goodBytes);
      expect(parsedFrame.type, FrameType.roomMsg);
      expect(parsedFrame.senderId, 'alice'.padRight(64, '0'));
      expect(utf8.decode(parsedFrame.payloadBytes), 'Legit message');
    });
  });
}

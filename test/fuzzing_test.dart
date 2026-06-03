import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';

void main() {
  group('Fuzzing & Boundary Tests', () {
    final random = Random();

    String generateRandomString(int length) {
      const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890!@#\$%^&*()_+-=<>?/:;';
      return String.fromCharCodes(Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ));
    }

    test('Frame.deserialize safely rejects completely random garbage strings', () {
      for (int i = 0; i < 100; i++) {
        final garbage = generateRandomString(random.nextInt(100) + 10);
        expect(() => Frame.deserialize(garbage), throwsFormatException);
      }
    });

    test('Frame.deserialize safely rejects frames with missing delimiters', () {
      final badFrame = 'YML1:RM:sender:recip:sess:msg:123456:0:1:text'; // missing base64 part
      expect(() => Frame.deserialize(badFrame), throwsFormatException);
    });

    test('Frame.deserialize safely rejects oversized base64 payloads', () {
      // 2800 is the limit.
      final oversizedBase64 = generateRandomString(3000);
      final badFrame = 'YML1:RM:sender:recip:sess:msg:123456:0:1:text:$oversizedBase64';
      
      expect(() => Frame.deserialize(badFrame), throwsFormatException);
    });

    test('Frame.deserialize safely rejects structurally correct frames with invalid base64', () {
      // Valid delimiters, but base64 is broken
      final badBase64 = 'not_base_64_!!!';
      final badFrame = 'YML1:RM:sender:recip:sess:msg:123456:0:1:text:$badBase64';
      
      expect(() => Frame.deserialize(badFrame), throwsFormatException);
    });

    test('Frame.deserialize safely rejects structurally correct frames with invalid non-UTF8 payload', () {
      // Base64 is valid base64 string, but decodes to non-UTF8 bytes
      final badBytes = Uint8List.fromList([255, 254, 253, 128]);
      final encodedBadBytes = base64.encode(badBytes);
      final badFrame = 'YML1:RM:sender:recip:sess:msg:123456:0:1:text:$encodedBadBytes';
      
      expect(() => Frame.deserialize(badFrame), throwsFormatException);
    });

    test('Frame.deserialize parses legitimate frame correctly', () {
      final payload = base64.encode(utf8.encode('Legit message'));
      final time = DateTime.now().millisecondsSinceEpoch;
      final goodFrame = 'YML1:RM:alice:bob:sess_1:1:$time:0:1:text:$payload';
      
      final frame = Frame.deserialize(goodFrame);
      expect(frame.type, FrameType.roomMsg);
      expect(frame.senderId, 'alice');
      expect(frame.payloadBody, 'Legit message');
    });
  });
}

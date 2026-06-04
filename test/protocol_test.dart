import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';

void main() {
  group('YamiLink Frame Protocol Tests', () {
    test('Successful serialization and deserialization of room message', () {
      final frame = Frame(
        type: FrameType.roomMsg,
        senderId: 'A' * 64, // 32 bytes hex
        recipientId: '*',
        sessionId: 'session_xyz',
        messageId: 42,
        timestamp: 1625000000000,
        flags: 1,
        hopCount: 2,
        payloadBytes: utf8.encode('Hello Proximity Network!'),
      );

      final serialized = frame.serialize(withSignature: false);
      expect(serialized, isNotEmpty);
      expect(serialized[0], 2); // Version 2

      final deserialized = Frame.fromBytes(serialized);
      expect(deserialized.version, 2);
      expect(deserialized.type, FrameType.roomMsg);
      expect(deserialized.senderId, 'A' * 64);
      expect(deserialized.recipientId, '*');
      expect(deserialized.sessionId, 'session_xyz');
      expect(deserialized.messageId, 42);
      expect(deserialized.timestamp, 1625000000000);
      expect(deserialized.flags, 1);
      expect(deserialized.hopCount, 2);
      expect(utf8.decode(deserialized.payloadBytes), 'Hello Proximity Network!');
    });

    test('Successful serialization and deserialization of direct message', () {
      final frame = Frame(
        type: FrameType.directMsg,
        senderId: 'B' * 64,
        recipientId: 'C' * 64,
        sessionId: 'sess_123',
        messageId: 999,
        timestamp: 1625000000100,
        payloadBytes: utf8.encode('Secret DM'),
      );

      final serialized = frame.serialize(withSignature: false);
      final deserialized = Frame.fromBytes(serialized);
      expect(deserialized.type, FrameType.directMsg);
      expect(deserialized.recipientId, 'C' * 64);
      expect(deserialized.hopCount, 1);
      expect(utf8.decode(deserialized.payloadBytes), 'Secret DM');
    });

    test('Throws FormatException on invalid frame data', () {
      expect(
        () => Frame.fromBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
      
      final wrongVersion = Uint8List(178);
      wrongVersion[0] = 3;
      expect(
        () => Frame.fromBytes(wrongVersion),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/protocol/frame.dart';

void main() {
  group('YamiLink Frame Protocol Tests', () {
    test('Successful serialization and deserialization of room message', () {
      final frame = Frame(
        type: FrameType.roomMsg,
        senderId: 'sender_abc',
        recipientId: '*',
        sessionId: 'session_xyz',
        messageId: 42,
        timestamp: 1625000000000,
        flags: 1,
        payloadType: 'text',
        payloadBody: 'Hello Proximity Network!',
      );

      final serialized = frame.serialize();
      expect(serialized, isNotEmpty);
      expect(serialized.startsWith('YML1:RM:'), isTrue);

      final deserialized = Frame.deserialize(serialized);
      expect(deserialized.version, 'YML1');
      expect(deserialized.type, FrameType.roomMsg);
      expect(deserialized.senderId, 'sender_abc');
      expect(deserialized.recipientId, '*');
      expect(deserialized.sessionId, 'session_xyz');
      expect(deserialized.messageId, 42);
      expect(deserialized.timestamp, 1625000000000);
      expect(deserialized.flags, 1);
      expect(deserialized.payloadType, 'text');
      expect(deserialized.payloadBody, 'Hello Proximity Network!');
    });

    test('Successful serialization and deserialization of direct message', () {
      final frame = Frame(
        type: FrameType.directMsg,
        senderId: 'node_1',
        recipientId: 'node_2',
        sessionId: 'sess_123',
        messageId: 999,
        timestamp: 1625000000100,
        payloadBody: 'Secret DM',
      );

      final serialized = frame.serialize();
      final deserialized = Frame.deserialize(serialized);
      expect(deserialized.type, FrameType.directMsg);
      expect(deserialized.recipientId, 'node_2');
      expect(deserialized.payloadBody, 'Secret DM');
    });

    test('Throws FormatException on invalid frame data', () {
      expect(() => Frame.deserialize('YML1:RM:short'), throwsA(isA<FormatException>()));
      expect(() => Frame.deserialize('YML2:RM:s:r:sess:1:1:0:t:body'), throwsA(isA<FormatException>()));
    });
  });
}

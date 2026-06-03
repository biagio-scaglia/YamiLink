import 'dart:convert';

enum FrameType { beacon, hello, roomMsg, directMsg, ack, goodbye, error }

extension FrameTypeExtension on FrameType {
  String get code {
    switch (this) {
      case FrameType.beacon:
        return 'BCN';
      case FrameType.hello:
        return 'HLO';
      case FrameType.roomMsg:
        return 'RM';
      case FrameType.directMsg:
        return 'DM';
      case FrameType.ack:
        return 'ACK';
      case FrameType.goodbye:
        return 'BYE';
      case FrameType.error:
        return 'ERR';
    }
  }

  static FrameType fromCode(String code) {
    switch (code) {
      case 'BCN':
        return FrameType.beacon;
      case 'HLO':
        return FrameType.hello;
      case 'RM':
        return FrameType.roomMsg;
      case 'DM':
        return FrameType.directMsg;
      case 'ACK':
        return FrameType.ack;
      case 'BYE':
        return FrameType.goodbye;
      case 'ERR':
      default:
        return FrameType.error;
    }
  }
}

class Frame {
  final String version;
  final FrameType type;
  final String senderId;
  final String recipientId;
  final String sessionId;
  final int messageId;
  final int timestamp;
  final int flags;
  final int hopCount;
  final String payloadType;
  final String payloadBody;

  Frame({
    this.version = 'YML1',
    required this.type,
    required this.senderId,
    required this.recipientId,
    required this.sessionId,
    required this.messageId,
    required this.timestamp,
    this.flags = 0,
    this.hopCount = 1,
    this.payloadType = 'text',
    required this.payloadBody,
  });

  /// Serializes the Frame to a delimited String envelope:
  /// YML1:TYPE:senderId:recipientId:sessionId:messageId:timestamp:flags:payloadType:base64(payloadBody)
  String serialize() {
    final bodyBytes = utf8.encode(payloadBody);
    final bodyBase64 = base64.encode(bodyBytes);
    return '$version:${type.code}:$senderId:$recipientId:$sessionId:$messageId:$timestamp:$flags:$hopCount:$payloadType:$bodyBase64';
  }

  /// Deserializes a delimited String envelope into a Frame instance.
  /// Throws FormatException if parsing fails.
  factory Frame.deserialize(String data) {
    final parts = data.split(':');
    if (parts.length < 11) {
      throw FormatException(
        'Invalid frame format: expected at least 11 fields, got ${parts.length}',
      );
    }

    final version = parts[0];
    if (version != 'YML1') {
      throw FormatException('Unsupported protocol version: $version');
    }

    final type = FrameTypeExtension.fromCode(parts[1]);
    final senderId = parts[2];
    final recipientId = parts[3];
    final sessionId = parts[4];

    final messageId = int.tryParse(parts[5]);
    if (messageId == null) {
      throw const FormatException('Invalid messageId format');
    }

    final timestamp = int.tryParse(parts[6]);
    if (timestamp == null) {
      throw const FormatException('Invalid timestamp format');
    }

    final flags = int.tryParse(parts[7]) ?? 0;
    final hopCount = int.tryParse(parts[8]) ?? 1;
    final payloadType = parts[9];

    final bodyBase64 = parts[10];
    String payloadBody;
    try {
      final decodedBytes = base64.decode(bodyBase64);
      payloadBody = utf8.decode(decodedBytes);
    } catch (e) {
      throw FormatException('Failed to decode payload body: $e');
    }

    return Frame(
      version: version,
      type: type,
      senderId: senderId,
      recipientId: recipientId,
      sessionId: sessionId,
      messageId: messageId,
      timestamp: timestamp,
      flags: flags,
      hopCount: hopCount,
      payloadType: payloadType,
      payloadBody: payloadBody,
    );
  }
}

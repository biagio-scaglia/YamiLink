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
  final String? signature;

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
    this.signature,
  });

  /// Returns the bytes that should be signed. Excludes hopCount and flags.
  List<int> get signableBytes {
    final bodyBase64 = base64.encode(utf8.encode(payloadBody));
    final signableStr = '${type.code}:$senderId:$recipientId:$sessionId:$messageId:$timestamp:$payloadType:$bodyBase64';
    return utf8.encode(signableStr);
  }

  /// Serializes the Frame to a delimited String envelope:
  /// YML1:TYPE:senderId:recipientId:sessionId:messageId:timestamp:flags:payloadType:base64(payloadBody)[:signature]
  String serialize() {
    final bodyBytes = utf8.encode(payloadBody);
    final bodyBase64 = base64.encode(bodyBytes);
    var str = '$version:${type.code}:$senderId:$recipientId:$sessionId:$messageId:$timestamp:$flags:$hopCount:$payloadType:$bodyBase64';
    if (signature != null) {
      str += ':$signature';
    }
    return str;
  }

  /// Deserializes a delimited String envelope into a Frame instance.
  /// Throws FormatException if parsing fails.
  factory Frame.deserialize(String data) {
    if (data.length > 3072) {
      // 2048 bytes raw packet roughly translates to ~2800 bytes base64 encoded.
      throw const FormatException('Frame length exceeds maximum allowed size (3072 chars).');
    }

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
    
    // Extract signature if it exists (parts.length >= 12 implies part[11] is signature)
    // Be careful because base64 body might not have colons, but let's assume we split max 12 times or handle it properly.
    // The safest way is to check parts length.
    String bodyBase64;
    String? signature;
    
    if (parts.length == 11) {
      bodyBase64 = parts[10];
    } else {
      // We have 12 or more parts.
      // Since base64 does not contain colons in standard base64 string,
      // parts[10] is payload, parts[11] is signature.
      bodyBase64 = parts[10];
      signature = parts[11];
    }

    if (bodyBase64.length > 2800) {
      throw const FormatException('Payload exceeds maximum allowed length.');
    }

    String payloadBody;
    try {
      final decodedBytes = base64.decode(bodyBase64);
      payloadBody = utf8.decode(decodedBytes, allowMalformed: false);
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
      signature: signature,
    );
  }
}

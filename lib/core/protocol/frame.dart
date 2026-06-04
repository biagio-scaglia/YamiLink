import 'dart:convert';
import 'dart:typed_data';
import '../../ffi_bridge_native.dart' if (dart.library.html) '../../ffi_bridge_stub.dart';

enum FrameType { beacon, hello, helloAck, roomMsg, directMsg, ack, goodbye, error }

extension FrameTypeExtension on FrameType {
  int get code {
    switch (this) {
      case FrameType.beacon: return 0;
      case FrameType.hello: return 1;
      case FrameType.helloAck: return 2;
      case FrameType.roomMsg: return 3;
      case FrameType.directMsg: return 4;
      case FrameType.ack: return 5;
      case FrameType.goodbye: return 6;
      case FrameType.error: return 7;
    }
  }

  static FrameType fromCode(int code) {
    if (code >= 0 && code <= 7) return FrameType.values[code];
    return FrameType.error;
  }
}

class Frame {
  static const int headerSize = 178;
  static const int signatureSize = 64;
  
  final int version;
  final FrameType type;
  final String senderId;
  final String recipientId;
  final String sessionId;
  final int messageId;
  final int timestamp;
  final int flags;
  final int hopCount;
  
  // We removed payloadType from the struct to save space, assuming it's part of the binary payload if needed, or we just assume text/json/binary.
  // We will treat payloadBody as raw bytes, but provide a string getter/setter for compatibility.
  final Uint8List payloadBytes;
  final Uint8List? signature;

  Frame({
    this.version = 2,
    required this.type,
    required this.senderId,
    required this.recipientId,
    required this.sessionId,
    required this.messageId,
    required this.timestamp,
    this.flags = 0,
    this.hopCount = 1,
    required this.payloadBytes,
    this.signature,
  });

  String get payloadBody {
    try {
      return utf8.decode(payloadBytes);
    } catch (_) {
      return '';
    }
  }

  /// Returns the bytes that should be signed. Excludes hopCount, flags, and signature.
  List<int> get signableBytes {
    // Actually, signing the entire exact binary representation (with flags/hopCount zeroed out) is much safer and standard.
    
    // Let's just create a copy of the packet up to payload, zeroing out mutable fields (flags, hopCount)
    final packet = serialize(withSignature: false);
    // Zero out flags (offset 174) and hopCount (offset 175)
    packet[174] = 0;
    packet[175] = 0;
    return packet;
  }

  /// Serializes the Frame to a binary YML2 buffer.
  Uint8List serialize({bool withSignature = true}) {
    final payloadLen = payloadBytes.length;
    final totalSize = headerSize + payloadLen + (withSignature && signature != null ? signatureSize : 0);
    
    final buffer = Uint8List(totalSize);
    final bd = ByteData.view(buffer.buffer);
    
    bd.setUint8(0, version);
    bd.setUint8(1, type.code);
    
    _writeString(buffer, 2, 64, senderId);
    _writeString(buffer, 66, 64, recipientId);
    _writeString(buffer, 130, 32, sessionId);
    
    bd.setUint32(162, messageId, Endian.little);
    bd.setUint64(166, timestamp, Endian.little);
    bd.setUint8(174, flags);
    bd.setUint8(175, hopCount);
    bd.setUint16(176, payloadLen, Endian.little);
    
    buffer.setAll(headerSize, payloadBytes);
    
    if (withSignature && signature != null && signature!.length == signatureSize) {
      buffer.setAll(headerSize + payloadLen, signature!);
    }
    
    return buffer;
  }

  /// Factory from raw bytes
  factory Frame.fromBytes(Uint8List data) {
    if (data.length < headerSize) {
      throw const FormatException('Packet too small for YML2 Header');
    }
    
    final bd = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final version = bd.getUint8(0);
    if (version != 2) throw FormatException('Unsupported YML version: $version');
    
    final type = FrameTypeExtension.fromCode(bd.getUint8(1));
    final senderId = _readString(data, 2, 64);
    final recipientId = _readString(data, 66, 64);
    final sessionId = _readString(data, 130, 32);
    
    final messageId = bd.getUint32(162, Endian.little);
    final timestamp = bd.getUint64(166, Endian.little);
    final flags = bd.getUint8(174);
    final hopCount = bd.getUint8(175);
    final payloadLen = bd.getUint16(176, Endian.little);
    
    if (data.length < headerSize + payloadLen) {
      throw const FormatException('Packet truncated: missing payload');
    }
    
    final payload = data.sublist(headerSize, headerSize + payloadLen);
    
    Uint8List? sig;
    if (data.length >= headerSize + payloadLen + signatureSize) {
      sig = data.sublist(headerSize + payloadLen, headerSize + payloadLen + signatureSize);
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
      payloadBytes: payload,
      signature: sig,
    );
  }

  /// Factory from FFI Struct (Zero-copy payload mapping)
  factory Frame.fromFFI(YML2PacketFFI ffiPacket) {
    throw UnimplementedError('Use fromBytes with a reconstructed Uint8List or a pointer memory view');
  }

  static void _writeString(Uint8List buffer, int offset, int maxLen, String value) {
    final bytes = utf8.encode(value);
    final copyLen = bytes.length > maxLen ? maxLen : bytes.length;
    buffer.setAll(offset, bytes.sublist(0, copyLen));
    for (var i = copyLen; i < maxLen; i++) {
      buffer[offset + i] = 0; // null pad
    }
  }

  static String _readString(Uint8List buffer, int offset, int maxLen) {
    int end = offset;
    while (end < offset + maxLen && buffer[end] != 0) {
      end++;
    }
    return utf8.decode(buffer.sublist(offset, end), allowMalformed: true);
  }
}

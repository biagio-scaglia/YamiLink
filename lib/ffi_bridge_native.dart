import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class YML2PacketFFI extends Struct {
  @Uint8()
  external int version;

  @Uint8()
  external int type;

  @Array(64)
  external Array<Uint8> senderId;

  @Array(64)
  external Array<Uint8> recipientId;

  @Array(32)
  external Array<Uint8> sessionId;

  @Uint32()
  external int messageId;

  @Uint64()
  external int timestamp;

  @Uint8()
  external int flags;

  @Uint8()
  external int hopCount;

  @Uint16()
  external int payloadLen;

  external Pointer<Uint8> payload;
  external Pointer<Uint8> signature;
}

final class YamiLinkEvent extends Struct {
  @Uint8()
  external int eventType;

  external Pointer<Utf8> senderHash;
  external Pointer<Utf8> senderAlias;

  @Uint32()
  external int avatarSeed;

  external Pointer<Uint8> rawPacket;
  @Uint32()
  external int rawPacketLen;

  @Float()
  external double signalRssi;
}

typedef CEventDispatcher = Void Function(Pointer<YamiLinkEvent> event);

typedef CStartFunc =
    Int32 Function(
      Pointer<Utf8> alias,
      Uint32 seed,
      Pointer<NativeFunction<CEventDispatcher>> dispatcher,
    );
typedef DartStartFunc =
    int Function(
      Pointer<Utf8> alias,
      int seed,
      Pointer<NativeFunction<CEventDispatcher>> dispatcher,
    );


typedef CFreeEventFunc = Void Function(Pointer<YamiLinkEvent> event);
typedef DartFreeEventFunc = void Function(Pointer<YamiLinkEvent> event);

typedef CSendFunc =
    Int32 Function(
      Pointer<Uint8> data,
      Uint32 length,
    );
typedef DartSendFunc =
    int Function(Pointer<Uint8> data, int length);

typedef CStopFunc = Int32 Function();
typedef DartStopFunc = int Function();

class YamiLinkFfiBridge {
  static final YamiLinkFfiBridge instance = YamiLinkFfiBridge._();
  YamiLinkFfiBridge._();

  DynamicLibrary? _lib;
  bool _isSupported = false;

  DartStartFunc? _yamilinkCoreStart;
  DartSendFunc? _yamilinkCoreSend;
  DartStopFunc? _yamilinkCoreStop;

  NativeCallable<CEventDispatcher>? _eventCallable;

  void Function(
    int eventType,
    String senderHash,
    String senderAlias,
    int seed,
    Uint8List packetBytes,
    double signal,
  )?
  onEvent;

  bool get isSupported => _isSupported;

  String? load() {
    try {
      if (identical(0, 0.0)) {
        _isSupported = false;
        return 'Web platform not supported for FFI.';
      }

      if (Platform.isWindows) {
        _lib = DynamicLibrary.open('yamilink_core.dll');
      } else if (Platform.isLinux || Platform.isAndroid) {
        _lib = DynamicLibrary.open('libyamilink_core.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libyamilink_core.dylib');
      } else {
        _isSupported = false;
        return 'Unsupported platform: ${Platform.operatingSystem}';
      }

      if (_lib != null) {
        _yamilinkCoreStart = _lib!.lookupFunction<CStartFunc, DartStartFunc>(
          'yamilink_core_start',
        );
        _yamilinkCoreSend = _lib!.lookupFunction<CSendFunc, DartSendFunc>(
          'yamilink_core_send',
        );
        _yamilinkCoreStop = _lib!.lookupFunction<CStopFunc, DartStopFunc>(
          'yamilink_core_stop',
        );
        _isSupported = true;
        return null; // Success
      }
      return 'Library not found';
    } catch (e) {
      _isSupported = false;
      return 'FFI unavailable: $e';
    }
  }

  int start(String alias, int seed) {
    if (!_isSupported || _yamilinkCoreStart == null) return -1;

    _eventCallable = NativeCallable<CEventDispatcher>.listener((
      Pointer<YamiLinkEvent> eventPtr,
    ) {
      final event = eventPtr.ref;
      final type = event.eventType;

      String hash = '';
      if (event.senderHash != nullptr) {
        try {
          hash = event.senderHash.toDartString();
        } catch (_) {
          // Bad FFI string, skip
          return;
        }
      }

      String senderAlias = '';
      if (event.senderAlias != nullptr) {
        try {
          senderAlias = event.senderAlias.toDartString();
        } catch (_) {
          return;
        }
      }

      final avatarSeed = event.avatarSeed;
      final signal = event.signalRssi;

      Uint8List packetBytes = Uint8List(0);
      if (event.rawPacket != nullptr && event.rawPacketLen > 0) {
        try {
          final safeLen = event.rawPacketLen > 4096 ? 4096 : event.rawPacketLen;
          final list = event.rawPacket.asTypedList(safeLen);
          packetBytes = Uint8List.fromList(list);
        } catch (_) {
          return;
        }
      }

      onEvent?.call(type, hash, senderAlias, avatarSeed, packetBytes, signal);
    });

    final aliasUtf8 = alias.toNativeUtf8();
    try {
      return _yamilinkCoreStart!(
        aliasUtf8,
        seed,
        _eventCallable!.nativeFunction,
      );
    } finally {
      calloc.free(aliasUtf8);
    }
  }

  int send(Uint8List data) {
    if (!_isSupported || _yamilinkCoreSend == null) return -1;

    final dataPtr = calloc<Uint8>(data.length);
    final dataPtrList = dataPtr.asTypedList(data.length);
    dataPtrList.setAll(0, data);

    try {
      return _yamilinkCoreSend!(
        dataPtr.cast<Uint8>(),
        data.length,
      );
    } finally {
      calloc.free(dataPtr);
    }
  }

  int stop() {
    if (!_isSupported || _yamilinkCoreStop == null) return -1;
    final res = _yamilinkCoreStop!();

    _eventCallable?.close();
    _eventCallable = null;

    return res;
  }
}

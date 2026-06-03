import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class YamiLinkEvent extends Struct {
  @Uint8()
  external int eventType;

  external Pointer<Utf8> senderHash;
  external Pointer<Utf8> senderAlias;

  @Uint32()
  external int avatarSeed;

  external Pointer<Uint8> payload;

  @Uint32()
  external int payloadLen;

  @Float()
  external double signalRssi;
}

// Callback signatures
typedef CEventDispatcher = Void Function(Pointer<YamiLinkEvent> event);

// Native function typings
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

typedef CSendFunc =
    Int32 Function(
      Pointer<Utf8> recipientHash,
      Pointer<Uint8> data,
      Uint32 length,
    );
typedef DartSendFunc =
    int Function(Pointer<Utf8> recipientHash, Pointer<Uint8> data, int length);

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

  // Callback to propagate events to transport layer
  void Function(
    int eventType,
    String senderHash,
    String senderAlias,
    int seed,
    Uint8List payload,
    double signal,
  )?
  onEvent;

  bool get isSupported => _isSupported;

  void load() {
    try {
      if (identical(0, 0.0)) {
        _isSupported = false;
        return;
      }

      if (Platform.isWindows) {
        _lib = DynamicLibrary.open('yamilink_core.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libyamilink_core.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libyamilink_core.dylib');
      } else {
        _isSupported = false;
        return;
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
      }
    } catch (e) {
      _isSupported = false;
      debugPrint(
        'YamiLink Core FFI unavailable: $e. Falling back to Simulated Space.',
      );
    }
  }

  int start(String alias, int seed) {
    if (!_isSupported || _yamilinkCoreStart == null) return -1;

    // Use NativeCallable.listener to receive events from background threads safely
    _eventCallable = NativeCallable<CEventDispatcher>.listener((
      Pointer<YamiLinkEvent> eventPtr,
    ) {
      final event = eventPtr.ref;
      final type = event.eventType;

      String hash = '';
      if (event.senderHash != nullptr) {
        hash = event.senderHash.toDartString();
      }

      String senderAlias = '';
      if (event.senderAlias != nullptr) {
        senderAlias = event.senderAlias.toDartString();
      }

      final avatarSeed = event.avatarSeed;
      final len = event.payloadLen;
      final signal = event.signalRssi;

      Uint8List payloadBytes = Uint8List(0);
      if (len > 0 && event.payload != nullptr) {
        final list = event.payload.asTypedList(len);
        payloadBytes = Uint8List.fromList(list);
      }

      onEvent?.call(type, hash, senderAlias, avatarSeed, payloadBytes, signal);
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

  int send(String? recipientHash, Uint8List data) {
    if (!_isSupported || _yamilinkCoreSend == null) return -1;

    final recipientUtf8 = recipientHash != null
        ? recipientHash.toNativeUtf8()
        : nullptr;

    // Allocate memory for packet data
    final dataPtr = calloc<Uint8>(data.length);
    final dataPtrList = dataPtr.asTypedList(data.length);
    dataPtrList.setAll(0, data);

    try {
      return _yamilinkCoreSend!(
        recipientUtf8,
        dataPtr.cast<Uint8>(),
        data.length,
      );
    } finally {
      if (recipientUtf8 != nullptr) calloc.free(recipientUtf8);
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

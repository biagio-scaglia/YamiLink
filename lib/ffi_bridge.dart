import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Callback signatures
typedef CPeerCallback = Void Function(Pointer<Utf8> hash, Pointer<Utf8> alias, Uint32 seed, Float signal);
typedef CMessageCallback = Void Function(Pointer<Utf8> senderHash, Pointer<Utf8> senderAlias, Pointer<Utf8> content);

// Dart equivalents
typedef DartPeerCallback = void Function(String hash, String alias, int seed, double signal);
typedef DartMessageCallback = void Function(String senderHash, String senderAlias, String content);

// Native function typings
typedef CInitFunc = Int32 Function(Pointer<Utf8> alias, Uint32 seed);
typedef DartInitFunc = int Function(Pointer<Utf8> alias, int seed);

typedef CStartDiscoveryFunc = Int32 Function(Pointer<NativeFunction<CPeerCallback>> peerCb, Pointer<NativeFunction<CMessageCallback>> msgCb);
typedef DartStartDiscoveryFunc = int Function(Pointer<NativeFunction<CPeerCallback>> peerCb, Pointer<NativeFunction<CMessageCallback>> msgCb);

typedef CSendBroadcastFunc = Int32 Function(Pointer<Utf8> content);
typedef DartSendBroadcastFunc = int Function(Pointer<Utf8> content);

typedef CSendDirectFunc = Int32 Function(Pointer<Utf8> recipientHash, Pointer<Utf8> content);
typedef DartSendDirectFunc = int Function(Pointer<Utf8> recipientHash, Pointer<Utf8> content);

typedef CStopFunc = Int32 Function();
typedef DartStopFunc = int Function();

class YamiLinkFfiBridge {
  static final YamiLinkFfiBridge instance = YamiLinkFfiBridge._();
  YamiLinkFfiBridge._();

  DynamicLibrary? _lib;
  bool _isSupported = false;

  // Function binders
  DartInitFunc? _yamilinkInit;
  DartStartDiscoveryFunc? _yamilinkStartDiscovery;
  DartSendBroadcastFunc? _yamilinkSendBroadcast;
  DartSendDirectFunc? _yamilinkSendDirect;
  DartStopFunc? _yamilinkStop;

  // Callables to persist in memory to prevent GC
  NativeCallable<CPeerCallback>? _peerCallable;
  NativeCallable<CMessageCallback>? _messageCallable;

  bool get isSupported => _isSupported;

  void load() {
    try {
      // Prevent FFI checks on web (where dart:io throws unsupported errors)
      if (identical(0, 0.0)) {
        // Javascript VM
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
        _yamilinkInit = _lib!.lookupFunction<CInitFunc, DartInitFunc>('yamilink_init');
        _yamilinkStartDiscovery = _lib!.lookupFunction<CStartDiscoveryFunc, DartStartDiscoveryFunc>('yamilink_start_discovery');
        _yamilinkSendBroadcast = _lib!.lookupFunction<CSendBroadcastFunc, DartSendBroadcastFunc>('yamilink_send_broadcast');
        _yamilinkSendDirect = _lib!.lookupFunction<CSendDirectFunc, DartSendDirectFunc>('yamilink_send_direct');
        _yamilinkStop = _lib!.lookupFunction<CStopFunc, DartStopFunc>('yamilink_stop');
        _isSupported = true;
      }
    } catch (e) {
      // Graceful fallback for non-desktop builds or missing binaries
      _isSupported = false;
      print('YamiLink Core FFI unavailable: $e. Falling back to Simulated Space.');
    }
  }

  int initialize(String alias, int seed) {
    if (!_isSupported || _yamilinkInit == null) return -1;
    final aliasUtf8 = alias.toNativeUtf8();
    try {
      return _yamilinkInit!(aliasUtf8, seed);
    } finally {
      calloc.free(aliasUtf8);
    }
  }

  int startDiscovery({
    required DartPeerCallback onPeerFound,
    required DartMessageCallback onMessageReceived,
  }) {
    if (!_isSupported || _yamilinkStartDiscovery == null) return -1;

    // Use modern NativeCallable.listener to handle callback delivery from background C socket threads
    _peerCallable = NativeCallable<CPeerCallback>.listener((Pointer<Utf8> hash, Pointer<Utf8> alias, int seed, double signal) {
      onPeerFound(hash.toDartString(), alias.toDartString(), seed, signal);
    });

    _messageCallable = NativeCallable<CMessageCallback>.listener((Pointer<Utf8> senderHash, Pointer<Utf8> senderAlias, Pointer<Utf8> content) {
      onMessageReceived(senderHash.toDartString(), senderAlias.toDartString(), content.toDartString());
    });

    return _yamilinkStartDiscovery!(
      _peerCallable!.nativeFunction,
      _messageCallable!.nativeFunction,
    );
  }

  int sendBroadcast(String content) {
    if (!_isSupported || _yamilinkSendBroadcast == null) return -1;
    final contentUtf8 = content.toNativeUtf8();
    try {
      return _yamilinkSendBroadcast!(contentUtf8);
    } finally {
      calloc.free(contentUtf8);
    }
  }

  int sendDirect(String recipientHash, String content) {
    if (!_isSupported || _yamilinkSendDirect == null) return -1;
    final recipientUtf8 = recipientHash.toNativeUtf8();
    final contentUtf8 = content.toNativeUtf8();
    try {
      return _yamilinkSendDirect!(recipientUtf8, contentUtf8);
    } finally {
      calloc.free(recipientUtf8);
      calloc.free(contentUtf8);
    }
  }

  int stop() {
    if (!_isSupported || _yamilinkStop == null) return -1;
    final result = _yamilinkStop!();
    
    // Release native callbacks
    _peerCallable?.close();
    _messageCallable?.close();
    _peerCallable = null;
    _messageCallable = null;
    
    return result;
  }
}

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MulticastManager {
  static const MethodChannel _channel = MethodChannel('com.yamilink/multicast');

  /// Acquires the Android WifiManager.MulticastLock to allow receiving UDP broadcasts and multicast.
  /// On non-Android platforms, this is a no-op and returns true immediately.
  static Future<bool> acquire() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // Not needed on Windows/Desktop/iOS
    }
    
    try {
      final bool? result = await _channel.invokeMethod('acquireMulticastLock');
      if (result == true) {
        debugPrint('MulticastManager: Acquired Android MulticastLock successfully.');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('MulticastManager: Failed to acquire MulticastLock: ${e.message}');
      return false;
    }
  }

  /// Releases the MulticastLock to save battery.
  static Future<void> release() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    
    try {
      await _channel.invokeMethod('releaseMulticastLock');
      debugPrint('MulticastManager: Released Android MulticastLock.');
    } on PlatformException catch (e) {
      debugPrint('MulticastManager: Failed to release MulticastLock: ${e.message}');
    }
  }
}

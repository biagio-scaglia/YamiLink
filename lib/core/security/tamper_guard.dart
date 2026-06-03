import 'dart:io';
import 'package:flutter/foundation.dart';

class TamperGuard {
  static final TamperGuard instance = TamperGuard._();

  TamperGuard._();

  bool _isSuspiciousEnvironment = false;
  bool get isSuspiciousEnvironment => _isSuspiciousEnvironment;

  void initialize() {
    _runEnvironmentChecks();
  }

  void _runEnvironmentChecks() {
    bool suspicious = false;

    // In release mode, the presence of active debugging or certain emulator traits
    // is a sign of instrumentation/tampering.
    if (kReleaseMode) {
      if (_detectDebuggerOrHooking()) {
        suspicious = true;
      }
      if (Platform.isAndroid && _detectRootOrEmulationAndroid()) {
        suspicious = true;
      }
    }

    _isSuspiciousEnvironment = suspicious;

    if (suspicious && !kReleaseMode) {
      debugPrint('TAMPER_GUARD: Suspicious environment detected (ignored in debug mode).');
    }
  }

  bool _detectDebuggerOrHooking() {
    // Basic heuristic: check if observatory/VM service is running in release
    // (Should not happen normally, but if a custom runtime is used...)
    bool vmservice = false;
    assert(() {
      vmservice = true;
      return true;
    }());
    if (kReleaseMode && vmservice) {
      return true; // Debug mode flag is active in a release build! (tampered engine)
    }

    // Additional simplistic checks for environment variables commonly used by hookers
    final env = Platform.environment;
    if (env.containsKey('FRIDA_SERVER') || env.containsKey('XPOSED_ROOT')) {
      return true;
    }

    return false;
  }

  bool _detectRootOrEmulationAndroid() {
    try {
      // Basic manual heuristics for Android without adding heavy dependencies
      final suspiciousFiles = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
        '/su/bin/su',
        '/data/adb/magisk', 
      ];

      for (var path in suspiciousFiles) {
        if (File(path).existsSync()) {
          return true;
        }
      }
    } catch (e) {
      // Ignore errors, accessing these paths might throw
    }
    return false;
  }
}

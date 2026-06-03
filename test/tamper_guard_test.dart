import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/core/security/tamper_guard.dart';

void main() {
  group('TamperGuard Environment Tests', () {
    test('Initialization in debug mode does not flag as suspicious by default', () {
      final guard = TamperGuard.instance;
      // Re-initialize for test
      guard.initialize();
      
      // Since `flutter test` runs in debug mode (kReleaseMode == false),
      // it should NOT flag as suspicious because the checks are ignored or less strict.
      expect(guard.isSuspiciousEnvironment, isFalse);
    });

    test('Debug mode flag logic verification', () {
      // In flutter test, kReleaseMode is false, and kDebugMode is true.
      expect(kDebugMode, isTrue);
      expect(kReleaseMode, isFalse);
    });

    // In a real device test or integration test, we'd mock Platform.isAndroid 
    // and kReleaseMode to test the actual branch. Dart test environment
    // doesn't allow easy override of kReleaseMode since it's a compile-time const,
    // but we can ensure the class loads and initializes without crashing.
    test('TamperGuard singleton does not crash on multiple inits', () {
      final guard = TamperGuard.instance;
      guard.initialize();
      guard.initialize();
      expect(guard, isNotNull);
    });
  });
}

import 'package:flutter/material.dart';

class YamiTheme {
  // Theme Colors
  static const Color bgDeep = Color(0xFF070A0F);
  static const Color surfaceDark = Color(0xFF101520);
  static const Color surfaceLight = Color(0xFF161E2E);
  static const Color borderGlass = Color(0x14FFFFFF);
  
  static const Color glowActive = Color(0xFF00F0FF);   // Cyber Cyan
  static const Color glowSecure = Color(0xFF00FF85);   // Emerald Green
  static const Color glowAmbient = Color(0xFF7000FF);  // Neon Purple
  static const Color glowWarning = Color(0xFFFF3B30);  // Alert Red

  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Custom Glassmorphic Decoration
  static BoxDecoration glassDecoration({
    Color backgroundColor = surfaceDark,
    double opacity = 0.7,
    Color glowColor = Colors.transparent,
    double glowRadius = 0.0,
    double borderRadius = 16.0,
  }) {
    return BoxDecoration(
      color: backgroundColor.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderGlass,
        width: 1.0,
      ),
      boxShadow: glowRadius > 0
          ? [
              BoxShadow(
                color: glowColor.withOpacity(0.15),
                blurRadius: glowRadius,
                spreadRadius: 1,
              )
            ]
          : null,
    );
  }

  // Linear Gradient for background atmospheric effect
  static Gradient ambientBackgroundGradient() {
    return const RadialGradient(
      center: Alignment(0.7, -0.6),
      radius: 1.5,
      colors: [
        Color(0x227000FF), // Soft purple ambient
        Color(0x00000000),
      ],
      stops: [0.0, 1.0],
    );
  }

  // Text Styles
  static TextStyle get titleStyle => const TextStyle(
        fontFamily: 'Roboto', // Standard clean sans-serif
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.5,
      );

  static TextStyle get subtitleStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static TextStyle get bodyStyle => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.4,
      );

  static TextStyle get captionStyle => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMuted,
      );

  static TextStyle get monoStyle => const TextStyle(
        fontFamily: 'Courier', // Standard monospace fallback
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: glowActive,
        letterSpacing: 1.0,
      );

  // App-wide Theme Data
  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDeep,
      primaryColor: glowActive,
      colorScheme: const ColorScheme.dark(
        primary: glowActive,
        secondary: glowAmbient,
        surface: surfaceDark,
        background: bgDeep,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textPrimary,
        ),
      ),
    );
  }
}

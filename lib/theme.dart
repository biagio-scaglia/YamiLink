import 'package:flutter/material.dart';

class YamiTheme {
  static const Color bgDeep = Color(0xFF070A0F);
  static const Color surfaceDark = Color(0xFF0E131F);
  static const Color surfaceLight = Color(0xFF161E30);
  static const Color borderGlass = Color(0x14FFFFFF);

  static const Color glowActive = Color(0xFF00F0FF);
  static const Color glowSecure = Color(0xFF00FF85);
  static const Color glowAmbient = Color(0xFF7000FF);
  static const Color glowWarning = Color(0xFFFF3B30);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static BoxDecoration glassDecoration({
    Color backgroundColor = surfaceDark,
    double opacity = 0.75,
    Color glowColor = Colors.transparent,
    double glowRadius = 0.0,
    double borderRadius = 16.0,
    bool doubleBorder = false,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: doubleBorder ? borderGlass.withValues(alpha: 0.12) : borderGlass,
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16.0,
          spreadRadius: -4.0,
        ),

        if (glowRadius > 0 && glowColor != Colors.transparent)
          BoxShadow(
            color: glowColor.withValues(alpha: 0.15),
            blurRadius: glowRadius,
            spreadRadius: 0.5,
          ),
      ],
    );
  }

  static Gradient ambientBackgroundGradient() {
    return const RadialGradient(
      center: Alignment(0.8, -0.2),
      radius: 1.5,
      colors: [Color(0x147000FF), Color(0x00000000)],
      stops: [0.0, 1.0],
    );
  }

  static TextStyle get titleStyle => const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get subtitleStyle => const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle get bodyStyle => const TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.4,
  );

  static TextStyle get captionStyle => const TextStyle(
    fontFamily: 'Outfit',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );

  static TextStyle get monoStyle => const TextStyle(
    fontFamily: 'SpaceMono',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: glowActive,
    letterSpacing: 1.5,
  );

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDeep,
      primaryColor: glowActive,
      colorScheme: const ColorScheme.dark(
        primary: glowActive,
        secondary: glowAmbient,
        surface: surfaceDark,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
      ),
    );
  }
}

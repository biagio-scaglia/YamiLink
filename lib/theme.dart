import 'package:flutter/material.dart';

class YamiTheme {
  // Brand Color Tokens (Obsidian Proximity Palette)
  static const Color bgDeep = Color(0xFF070A0F); // Midnight Slate Base
  static const Color surfaceDark = Color(0xFF0E131F); // Obsidian Card Base
  static const Color surfaceLight = Color(0xFF161E30); // Elevated Interactive
  static const Color borderGlass = Color(0x14FFFFFF); // Soft outer border

  static const Color glowActive = Color(0xFF00F0FF); // Electric Cyan
  static const Color glowSecure = Color(0xFF00FF85); // Neon Mint Green
  static const Color glowAmbient = Color(0xFF7000FF); // Phlox Violet
  static const Color glowWarning = Color(0xFFFF3B30); // Warm Crimson

  static const Color textPrimary = Color(0xFFF1F5F9); // Off-white
  static const Color textSecondary = Color(0xFF94A3B8); // Cool Gray
  static const Color textMuted = Color(0xFF64748B); // Muted Metadata

  // Advanced Glassmorphic Decorator
  static BoxDecoration glassDecoration({
    Color backgroundColor = surfaceDark,
    double opacity = 0.75,
    Color glowColor = Colors.transparent,
    double glowRadius = 0.0,
    double borderRadius = 16.0,
    bool doubleBorder = false,
  }) {
    return BoxDecoration(
      color: backgroundColor.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: doubleBorder ? borderGlass.withOpacity(0.12) : borderGlass,
        width: 1.0,
      ),
      boxShadow: [
        // Ambient soft backdrop shadow
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 16.0,
          spreadRadius: -4.0,
        ),
        // Neon Glow effect when active
        if (glowRadius > 0 && glowColor != Colors.transparent)
          BoxShadow(
            color: glowColor.withOpacity(0.15),
            blurRadius: glowRadius,
            spreadRadius: 0.5,
          ),
      ],
    );
  }

  // Soft slow-moving ambient light overlay
  static Gradient ambientBackgroundGradient() {
    return const RadialGradient(
      center: Alignment(0.8, -0.2),
      radius: 1.5,
      colors: [
        Color(0x147000FF), // Phlox Violet (6% opacity to satisfy WCAG AA)
        Color(0x00000000),
      ],
      stops: [0.0, 1.0],
    );
  }

  // Typography Styles
  static TextStyle get titleStyle => const TextStyle(
    fontFamily: 'SpaceGrotesk', // Modern geometric sans-serif
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
    fontFamily: 'Outfit', // Smooth readable sans
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
    fontFamily: 'SpaceMono', // Monospace details
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: glowActive,
    letterSpacing: 1.5,
  );

  // App Theme configuration
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
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class YamiTheme {
  // New Nocturnal & Tactile Palette
  static const Color bgDeep = Color(0xFF0A0908);
  static const Color surfaceDark = Color(0xFF141211);
  static const Color surfaceLight = Color(0xFF1F1C1A);
  
  static const Color borderMetallic = Color(0xFF36302B);

  // Accents (Oxblood, Brass, Plum, Rust)
  static const Color accentActive = Color(0xFF752A33);
  static const Color accentSecure = Color(0xFFA88B5E);
  static const Color accentAmbient = Color(0xFF4A313B);
  static const Color accentWarning = Color(0xFF9E3B33);

  // Typography (Bone, Sand, Earth)
  static const Color textPrimary = Color(0xFFEAE4DC);
  static const Color textSecondary = Color(0xFFA39B94);
  static const Color textMuted = Color(0xFF6E6660);

  static BoxDecoration tactileDecoration({
    Color backgroundColor = surfaceDark,
    double opacity = 0.95, // Smoked acrylic, less transparent
    Color borderColor = borderMetallic,
    double borderRadius = 12.0,
    bool raised = true,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor.withValues(alpha: 0.8),
        width: 1.0,
      ),
      boxShadow: raised
          ? [
              // Deep mechanical drop shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12.0,
                spreadRadius: 2.0,
                offset: const Offset(0, 4),
              ),
              // Simulating top edge lighting for tactile depth
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.03),
                blurRadius: 0.0,
                spreadRadius: 0.0,
                offset: const Offset(0, -1),
              ),
            ]
          : [],
    );
  }

  static Gradient ambientBackgroundGradient() {
    return const RadialGradient(
      center: Alignment(0.5, -0.5),
      radius: 1.5,
      colors: [Color(0x0C4A313B), Color(0x00000000)], // Very subtle plum ambient
      stops: [0.0, 1.0],
    );
  }

  static TextStyle get titleStyle => const TextStyle(
    fontFamily: 'Inter', // Fallback cleanly if missing
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get subtitleStyle => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.2,
  );

  static TextStyle get bodyStyle => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static TextStyle get captionStyle => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );

  static TextStyle get monoStyle => const TextStyle(
    fontFamily: 'SpaceMono',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: accentActive,
    letterSpacing: 2.0,
  );

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDeep,
      primaryColor: accentActive,
      colorScheme: const ColorScheme.dark(
        primary: accentActive,
        secondary: accentAmbient,
        surface: surfaceDark,
        error: accentWarning,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceDark,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
          side: const BorderSide(color: borderMetallic, width: 1.0),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
      ),
    );
  }
}

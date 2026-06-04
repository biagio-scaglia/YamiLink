import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// YamiLink Design System V2 — "Nocturnal Object"
/// Art direction: dark, intimate, tactile, cinematic.
/// Palette: burgundy/wine accents, smoked charcoal surfaces, warm ivory text.
/// Typography: Inter (UI), Playfair Display (display/brand), JetBrains Mono (technical only).
class YamiTheme {
  YamiTheme._();

  // ---------------------------------------------------------------------------
  // COLOUR TOKENS
  // ---------------------------------------------------------------------------

  // Superfici — stratificate, profonde
  static const Color bgVoid       = Color(0xFF080706);
  static const Color bgDeep       = Color(0xFF0E0C0B);
  static const Color surfaceBase  = Color(0xFF161210);
  static const Color surfaceRaised= Color(0xFF1E1A18);
  static const Color surfaceHigh  = Color(0xFF272220);

  // Bordi caldi
  static const Color borderFaint  = Color(0xFF2A2420);
  static const Color borderMid    = Color(0xFF3A3028);
  static const Color borderStrong = Color(0xFF52453C);

  // --- Accenti (solo 2) ---
  /// Accento primario: wine/burgundy. CTA, selezione, badge unread.
  static const Color accentWine   = Color(0xFF8B2E3F);
  /// Accento secondario: brass caldo. Verified/trusted, timestamp hover.
  static const Color accentBrass  = Color(0xFFB8966A);
  /// Warning/danger: ember terracotta.
  static const Color accentEmber  = Color(0xFF9E4B38);

  // Alias di compatibilità (usati dai file esistenti che non tocchiamo)
  static const Color accentActive   = accentWine;
  static const Color accentSecure   = accentBrass;
  static const Color accentAmbient  = Color(0xFF3D2530);
  static const Color accentWarning  = accentEmber;
  static const Color borderMetallic = borderMid;

  // Testo — 4 livelli
  static const Color textBright = Color(0xFFF0EAE2);
  static const Color textBody   = Color(0xFFC8BFB6);
  static const Color textSub    = Color(0xFF8A8078);
  static const Color textGhost  = Color(0xFF524C46);

  // Alias di compatibilità
  static const Color textPrimary   = textBright;
  static const Color textSecondary = textBody;
  static const Color textMuted     = textSub;

  /// Compatibilità con codice esistente che usa surfaceDark/surfaceLight
  static const Color surfaceDark  = surfaceBase;
  static const Color surfaceLight = surfaceRaised;

  // Overlays
  static const Color overlayLight = Color(0x0AF0EAE2); // ~4% ivory
  static const Color overlayWine  = Color(0x148B2E3F); // ~8% wine

  // ---------------------------------------------------------------------------
  // TYPOGRAPHY
  // ---------------------------------------------------------------------------

  // Display — brand/entry screen
  static TextStyle get displayStyle => GoogleFonts.playfairDisplay(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    color: textBright,
    letterSpacing: 2.0,
    height: 1.1,
  );

  // Heading — AppBar, section header
  static TextStyle get headingStyle => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textBright,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // Heading muted — sotto-titolo AppBar
  static TextStyle get headingSubStyle => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSub,
    letterSpacing: 0.2,
  );

  // Body — testo messaggi, liste, guide. BASE LEGGIBILE.
  static TextStyle get bodyStyle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textBody,
    height: 1.6,
    letterSpacing: 0.0,
  );

  // Body small — preview messaggi, descrizioni secondarie
  static TextStyle get bodySmallStyle => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textBody,
    height: 1.5,
  );

  // Label — bottoni, tab, chip, badge label
  static TextStyle get labelStyle => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textBright,
    letterSpacing: 0.2,
  );

  // Caption — timestamp, meta, hint
  static TextStyle get captionStyle => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSub,
    height: 1.4,
  );

  // Mono — SOLO per ID hash, dati diagnostici, codice tecnico
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: accentWine,
    letterSpacing: 0.8,
    height: 1.4,
  );

  // Mono bright — mono su sfondo scuro, leggibile
  static TextStyle get monoBrightStyle => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textBody,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// Alias di compatibilità per codice esistente
  static TextStyle get titleStyle => headingStyle;
  static TextStyle get subtitleStyle => headingSubStyle;

  // ---------------------------------------------------------------------------
  // SPACING SCALE (4px grid)
  // ---------------------------------------------------------------------------
  static const double spaceXs  = 4.0;
  static const double spaceSm  = 8.0;
  static const double spaceMd  = 16.0;
  static const double spaceLg  = 24.0;
  static const double spaceXl  = 32.0;
  static const double spaceXxl = 48.0;

  // ---------------------------------------------------------------------------
  // RADIUS SCALE
  // ---------------------------------------------------------------------------
  static const double radiusSharp = 4.0;
  static const double radiusSoft  = 10.0;
  static const double radiusRound = 16.0;
  static const double radiusPill  = 100.0;

  // ---------------------------------------------------------------------------
  // ELEVATION / SHADOW (calde, mai fredde)
  // ---------------------------------------------------------------------------
  static List<BoxShadow> get shadowLow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.40),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static List<BoxShadow> get shadowMid => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.55),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  static List<BoxShadow> get shadowHigh => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.70),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.02),
      offset: const Offset(0, -1),
      blurRadius: 0,
    ),
  ];

  // ---------------------------------------------------------------------------
  // MOTION DURATIONS
  // ---------------------------------------------------------------------------
  static const Duration motionFast   = Duration(milliseconds: 120);
  static const Duration motionNormal = Duration(milliseconds: 220);
  static const Duration motionSlow   = Duration(milliseconds: 360);

  // ---------------------------------------------------------------------------
  // DECORATIONS RIUTILIZZABILI
  // ---------------------------------------------------------------------------

  /// Surface card — per liste, card peer, conversation tile
  static BoxDecoration surfaceCard({
    Color? borderColor,
    double radius = radiusSoft,
  }) => BoxDecoration(
    color: surfaceBase,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? borderMid,
      width: 1.0,
    ),
    boxShadow: shadowLow,
  );

  /// Surface raised — modal, bottom sheet content, overlapping surfaces
  static BoxDecoration surfaceRaisedDecoration({
    double radius = radiusRound,
    Color? borderColor,
  }) => BoxDecoration(
    color: surfaceRaised,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? borderStrong,
      width: 1.0,
    ),
    boxShadow: shadowHigh,
  );

  /// Mantenuto per compatibilità con codice esistente (nearby_screen, etc.)
  static BoxDecoration tactileDecoration({
    Color backgroundColor = surfaceBase,
    double opacity = 1.0,
    Color borderColor = borderMid,
    double borderRadius = radiusSoft,
    bool raised = false,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: raised ? shadowMid : shadowLow,
    );
  }

  /// Gradiente atmosferico leggero — background body
  static Gradient get ambientGradient => const RadialGradient(
    center: Alignment(0.6, -0.7),
    radius: 1.4,
    colors: [Color(0x0C3D2530), Color(0x00000000)],
    stops: [0.0, 1.0],
  );

  /// Mantenuto per compatibilità
  static Gradient ambientBackgroundGradient() => ambientGradient;

  // ---------------------------------------------------------------------------
  // THEME DATA COMPLETO
  // ---------------------------------------------------------------------------
  static ThemeData get themeData {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: bgDeep,
      primaryColor: accentWine,

      colorScheme: const ColorScheme.dark(
        primary: accentWine,
        secondary: accentBrass,
        surface: surfaceBase,
        error: accentEmber,
        onPrimary: textBright,
        onSecondary: bgDeep,
        onSurface: textBody,
        onError: textBright,
        outline: borderMid,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: headingStyle,
        iconTheme: const IconThemeData(color: textBody, size: 22),
        actionsIconTheme: const IconThemeData(color: textSub, size: 22),
        toolbarHeight: 60,
        shape: const Border(
          bottom: BorderSide(color: borderFaint, width: 1.0),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBase,
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: textGhost,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: textSub,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSoft),
          borderSide: const BorderSide(color: borderMid, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSoft),
          borderSide: const BorderSide(color: borderMid, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSoft),
          borderSide: const BorderSide(color: accentWine, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentWine,
          foregroundColor: textBright,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSoft),
          ),
          textStyle: labelStyle,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSub,
          textStyle: labelStyle.copyWith(color: textSub),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: bodySmallStyle.copyWith(color: textBright),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSoft),
          side: const BorderSide(color: borderStrong),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusRound),
          side: const BorderSide(color: borderStrong, width: 1.0),
        ),
        titleTextStyle: headingStyle,
        contentTextStyle: bodyStyle,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        modalBackgroundColor: surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radiusRound),
            topRight: Radius.circular(radiusRound),
          ),
        ),
        showDragHandle: false,
        elevation: 12,
      ),

      dividerTheme: const DividerThemeData(
        color: borderFaint,
        thickness: 1,
        space: 1,
      ),

      textTheme: base.textTheme.copyWith(
        displayLarge: displayStyle,
        headlineMedium: headingStyle,
        bodyLarge: bodyStyle,
        bodyMedium: bodySmallStyle,
        labelLarge: labelStyle,
        bodySmall: captionStyle,
      ),
    );
  }
}

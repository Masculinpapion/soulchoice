import 'package:flutter/material.dart';

class AuroraTheme {
  // ── Renkler ───────────────────────────────────────────────────────────────
  static const Color bgDeep        = Color(0xFF050709);
  static const Color auroraRed     = Color(0xFFFF2D55);
  static const Color auroraBlue    = Color(0xFF2D7FFF);
  static const Color auroraViolet  = Color(0xFF8B5CF6);
  static const Color auroraGold    = Color(0xFFFFB800);

  static const Color textPrimary   = Colors.white;
  static Color textSecondary       = Colors.white.withOpacity(0.7);
  static Color textMuted           = Colors.white.withOpacity(0.45);

  static Color glassBg             = Colors.white.withOpacity(0.06);
  static Color glassBorder         = Colors.white.withOpacity(0.12);
  static Color glassStrong         = Colors.white.withOpacity(0.10);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient redBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [auroraRed, auroraBlue],
  );

  static const LinearGradient titleGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Colors.white, Color(0xCCFF2D55)],
  );

  // ── Glow Shadows ──────────────────────────────────────────────────────────
  static List<BoxShadow> redGlow = [
    BoxShadow(
      color: auroraRed.withOpacity(0.4),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> blueGlow = [
    BoxShadow(
      color: auroraBlue.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 60,
      offset: const Offset(0, 30),
    ),
    BoxShadow(
      color: auroraRed.withOpacity(0.12),
      blurRadius: 50,
      spreadRadius: 0,
    ),
  ];

  // ── Background variants ───────────────────────────────────────────────────
  static const Color bgSoft = Color(0xFF0A0D12);

  // ── Extended text colors (mockup-spec opacity stops) ──────────────────────
  static Color textMetaLine     = Colors.white.withOpacity(0.78);
  static Color textPullQuote    = Colors.white.withOpacity(0.88);
  static Color textSectionLabel = Colors.white.withOpacity(0.55);
  static Color textPromptLabel  = Colors.white.withOpacity(0.42);
  static Color metaSeparator    = Colors.white.withOpacity(0.40);

  // ── Glass variants ────────────────────────────────────────────────────────
  static Color glassBarNeutral  = Colors.white.withOpacity(0.18);

  // ── Accent colors ─────────────────────────────────────────────────────────
  static const Color successGreen = Color(0xFF10B981);

  // ── Scroll clearance ──────────────────────────────────────────────────────
  // nav(72) + margin(16) + safety(22) = 110
  static const double scrollBottomSafetyHeight = 110.0;

  // ── Radius ────────────────────────────────────────────────────────────────
  static const double radiusCard      = 28.0;
  static const double radiusGlassPill = 100.0;
  static const double radiusInfoCard  = 20.0;
  static const double radiusSmall     = 12.0;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double spacingXS   = 4.0;
  static const double spacingS    = 8.0;
  static const double spacingM    = 12.0;
  static const double spacingL    = 16.0;
  static const double spacingXL   = 24.0;
  static const double spacingXXL  = 32.0;
  static const double spacingXXXL = 36.0;

  // ── Typography ────────────────────────────────────────────────────────────
  static const String fontDisplay = 'Fraunces';
  static const String fontBody    = 'Manrope';
  static const String fontMono    = 'JetBrainsMono';

  static TextStyle get displayItalic => TextStyle(
    fontFamily: fontDisplay,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get bodyText => TextStyle(
    fontFamily: fontBody,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle get monoLabel => TextStyle(
    fontFamily: fontMono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 2,
    height: 1.4,
  );

  // ── Soft gradient (accent pill) ───────────────────────────────────────────
  static const LinearGradient redBlueSoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2EFF2D55), Color(0x2E2D7FFF)],
  );
}

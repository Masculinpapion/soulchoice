import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand: Red (Ismarlıyorum) ↔ Blue (İstiyorum) ────────────────────────
  static const Color primaryRed  = Color(0xFFE63946);
  static const Color red         = primaryRed;
  static const Color redGlow     = Color(0xFFFF6B7A);

  static const Color primaryBlue = Color(0xFF4A90E2);
  static const Color blue        = primaryBlue;
  static const Color blueGlow    = Color(0xFF74B3F5);

  static const Color accentGold  = Color(0xFFD4AF37);
  static const Color gold        = Color(0xFFD4AF37);

  // ─── Backgrounds ──────────────────────────────────────────────────────────
  static const Color bgBlack = Color(0xFF0A0A0B);
  static const Color bgDeep  = Color(0xFF050506);
  static const Color bgCard  = Color(0xFF121218);

  // ─── Gradient ─────────────────────────────────────────────────────────────
  static const Color gradientStart = Color(0xFFE63946);
  static const Color gradientEnd   = Color(0xFF4A90E2);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primaryGradientDiagonal = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// "Ismarlıyorum" akışı — kırmızı dominant (%70 red)
  static const LinearGradient inviteGradient = LinearGradient(
    colors: [gradientStart, gradientStart, gradientEnd],
    stops: [0.0, 0.65, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// "İstiyorum" akışı — mavi dominant (%70 blue)
  static const LinearGradient requestGradient = LinearGradient(
    colors: [gradientEnd, gradientEnd, gradientStart],
    stops: [0.0, 0.65, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary  = Color(0xFF64748B);

  // ─── Glassmorphism ────────────────────────────────────────────────────────
  static const Color glassBg           = Color(0x0DFFFFFF);  //  5% white
  static const Color glassBgMedium     = Color(0x14FFFFFF);  //  8% white
  static const Color glassBgStrong     = Color(0x1AFFFFFF);  // 10% white
  static const Color glassBorder       = Color(0x26FFFFFF);  // 15% white
  static const Color glassBorderBright = Color(0x40FFFFFF);  // 25% white

  // ─── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
}

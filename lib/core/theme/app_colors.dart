import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand Accent: Violet → Cyan ─────────────────────────────────────────
  /// Primary accent — premium violet (kept as 'red' for legacy refs)
  static const Color red = Color(0xFF8B5CF6);
  static const Color redGlow = Color(0xFFA78BFA);

  /// Secondary accent — electric cyan (kept as 'blue' for legacy refs)
  static const Color blue = Color(0xFF06B6D4);
  static const Color blueGlow = Color(0xFF22D3EE);

  /// Warm gold — verified badges
  static const Color gold = Color(0xFFDDB77B);

  // ─── Backgrounds ──────────────────────────────────────────────────────────
  static const Color bgBlack = Color(0xFF070B14);   // deep space blue-black
  static const Color bgDeep  = Color(0xFF040709);   // absolute depth
  static const Color bgCard  = Color(0xFF0D1424);   // elevated surface

  // ─── Gradient ─────────────────────────────────────────────────────────────
  static const Color gradientStart = Color(0xFF8B5CF6);  // violet
  static const Color gradientEnd   = Color(0xFF06B6D4);  // cyan

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

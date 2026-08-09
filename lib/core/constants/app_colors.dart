import 'package:flutter/material.dart';

/// Brand color palette for SayNO.
/// Colors are used only to communicate status — never decoratively.
abstract final class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF1A1A1A);
  static const Color surfaceBorder = Color(0xFF222222);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFF4B5563);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Accent (neutral — used for interactive elements)
  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentMuted = Color(0xFF374151);

  // Transparent
  static const Color transparent = Colors.transparent;
}

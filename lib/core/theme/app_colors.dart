import 'package:flutter/material.dart';

class AppColors {
  // Foundations: Dark charcoal-navy off-grid emergency theme
  static const Color background = Color(0xFF0E131B);
  static const Color surface = Color(0xFF161C26);
  static const Color surfaceElevated = Color(0xFF202938);
  static const Color surfaceCard = Color(0xFF18202C);
  static const Color border = Color(0xFF2A3649);
  static const Color borderSubtle = Color(0xFF1F2937);

  // Status & Emergency Accents
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyRedBright = Color(0xFFEF4444);
  static const Color emergencyRedDark = Color(0xFF991B1B);
  static const Color emergencyRedGlow = Color(0x55DC2626);
  static const Color emergencyRedBg = Color(0x22DC2626);

  static const Color successGreen = Color(0xFF22C55E);
  static const Color successGreenBg = Color(0x2222C55E);

  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberBg = Color(0x24F59E0B);

  static const Color infoBlue = Color(0xFF38BDF8);
  static const Color infoBlueBg = Color(0x2238BDF8);

  // Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnPrimary = Colors.white;

  // Gradients
  static const RadialGradient sosGradient = RadialGradient(
    center: Alignment(0.0, -0.2),
    radius: 0.85,
    colors: [
      Color(0xFFEF4444),
      Color(0xFFB91C1C),
      Color(0xFF7F1D1D),
    ],
  );
}

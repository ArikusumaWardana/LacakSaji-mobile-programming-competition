import 'package:material_ui/material_ui.dart';

/// Restrained 90-8-2 utilitarian color tokens defined in DESIGN.md Section 2.
abstract final class AppColors {
  // Neutral paper & ink surfaces (90% screen area)
  static const Color bgCanvas = Color(0xFFF6F7F5);
  static const Color surfaceBase = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFECEFEA);
  static const Color skeletonFill = Color(0xFFE6EAE6);
  static const Color borderHairline = Color(0xFFDCE1DC);
  static const Color borderFocus = Color(0xFF234B3E);

  static const Color textPrimary = Color(0xFF181E1B);
  static const Color textSecondary = Color(0xFF4B5650);
  static const Color textMuted = Color(0xFF68736D);

  // Single primary pine color (8% screen area)
  static const Color primary = Color(0xFF234B3E);
  static const Color primaryPressed = Color(0xFF1A3A30);
  static const Color primaryTint = Color(0xFFE8F0EC);
  static const Color onPrimaryTint = Color(0xFF163329);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic safety & network colors (2% screen area, strictly functional)
  static const Color safeFg = Color(0xFF19533B);
  static const Color safeBg = Color(0xFFEBF4EF);
  static const Color safeBorder = Color(0xFFBCD8CA);

  static const Color warnFg = Color(0xFF7C4A03);
  static const Color warnBg = Color(0xFFFBF3E4);
  static const Color warnBorder = Color(0xFFE2C693);

  static const Color dangerFg = Color(0xFF8E2424);
  static const Color dangerBg = Color(0xFFFBECEC);
  static const Color dangerBorder = Color(0xFFDFB0B0);

  static const Color emergencyFg = Color(0xFFFFFFFF);
  static const Color emergencyBg = Color(0xFF9B2226);
  static const Color emergencyBorder = Color(0xFF78191C);

  static const Color infoFg = Color(0xFF244A69);
  static const Color infoBg = Color(0xFFEDF2F7);
  static const Color infoBorder = Color(0xFFC0D3E3);
}

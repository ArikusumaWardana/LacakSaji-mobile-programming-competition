import 'package:material_ui/material_ui.dart';

/// Restrained 90-8-2 modern editorial palette defined in DESIGN.md v2.0.0.
abstract final class AppColors {
  // Neutral airy canvas & soft-filled surfaces (90% screen area)
  static const Color bgCanvas = Color(0xFFFFFFFF);
  static const Color surfaceBase = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF4F5F4);
  static const Color surfaceSubtle = Color(0xFFF4F5F4);
  static const Color skeletonFill = Color(0xFFEAECEB);
  static const Color borderHairline = Color(0xFFECEFED);
  static const Color borderStrong = Color(0xFFCED5D1);
  static const Color borderFocus = Color(0xFF234B3E);

  static const Color textPrimary = Color(0xFF181E1B);
  static const Color textSecondary = Color(0xFF64706A);
  static const Color textMuted = Color(0xFF64706A);
  static const Color chipInactiveText = Color(0xFF5A6660);

  // Single primary pine color (8% screen area)
  static const Color primary = Color(0xFF234B3E);
  static const Color primaryPressed = Color(0xFF1A3A30);
  static const Color primaryTint = Color(0xFFE8F0EC);
  static const Color onPrimaryTint = Color(0xFF163329);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Slide-out / permanent drawer tokens
  static const Color drawerSurface = Color(0xFF234B3E);
  static const Color drawerInactiveFg = Color(0xFFDCE5E2);
  static const Color drawerDivider = Color(0x2EFFFFFF);

  // Photographic scrim & pill overlays (WCAG AAA over imagery)
  static const Color scrimDark = Color(0xD1181E1B);
  static const Color scrimPill = Color(0xAD181E1B);

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


import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Typography scale defined in DESIGN.md Section 3 (Plus Jakarta Sans + Roboto fallback).
abstract final class AppTypography {
  static TextStyle _base({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    Color color = AppColors.textPrimary,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
      fontFeatures: fontFeatures,
    ).copyWith(fontFamilyFallback: const ['Roboto']);
  }

  static final TextStyle displayStatus = _base(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static final TextStyle headlinePage = _base(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.30,
  );

  static final TextStyle titleSection = _base(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static final TextStyle titleItem = _base(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );

  static final TextStyle bodyLarge = _base(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  static final TextStyle bodyMedium = _base(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static final TextStyle labelButton = _base(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.20,
  );

  static final TextStyle labelTag = _base(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static final TextStyle captionLegal = _base(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.textMuted,
  );

  /// Applies tabular figures for aligned dynamic times, temperatures, and counts.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextTheme buildTextTheme() {
    return TextTheme(
      displaySmall: displayStatus,
      headlineSmall: headlinePage,
      titleLarge: headlinePage,
      titleMedium: titleSection,
      titleSmall: titleItem,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: captionLegal,
      labelLarge: labelButton,
      labelMedium: labelTag,
      labelSmall: captionLegal,
    );
  }
}

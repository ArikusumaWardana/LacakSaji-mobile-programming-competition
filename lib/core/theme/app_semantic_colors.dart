import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Semantic colors for food safety states, cluster alerts, and offline status.
@immutable
class LacakSemanticColors extends ThemeExtension<LacakSemanticColors> {
  const LacakSemanticColors({
    required this.safeBg,
    required this.safeFg,
    required this.safeBorder,
    required this.warnBg,
    required this.warnFg,
    required this.warnBorder,
    required this.dangerBg,
    required this.dangerFg,
    required this.dangerBorder,
    required this.emergencyBg,
    required this.emergencyFg,
    required this.emergencyBorder,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
  });

  final Color safeBg;
  final Color safeFg;
  final Color safeBorder;
  final Color warnBg;
  final Color warnFg;
  final Color warnBorder;
  final Color dangerBg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color emergencyBg;
  final Color emergencyFg;
  final Color emergencyBorder;
  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;

  static const LacakSemanticColors light = LacakSemanticColors(
    safeBg: AppColors.safeBg,
    safeFg: AppColors.safeFg,
    safeBorder: AppColors.safeBorder,
    warnBg: AppColors.warnBg,
    warnFg: AppColors.warnFg,
    warnBorder: AppColors.warnBorder,
    dangerBg: AppColors.dangerBg,
    dangerFg: AppColors.dangerFg,
    dangerBorder: AppColors.dangerBorder,
    emergencyBg: AppColors.emergencyBg,
    emergencyFg: AppColors.emergencyFg,
    emergencyBorder: AppColors.emergencyBorder,
    infoBg: AppColors.infoBg,
    infoFg: AppColors.infoFg,
    infoBorder: AppColors.infoBorder,
  );

  @override
  LacakSemanticColors copyWith({
    Color? safeBg,
    Color? safeFg,
    Color? safeBorder,
    Color? warnBg,
    Color? warnFg,
    Color? warnBorder,
    Color? dangerBg,
    Color? dangerFg,
    Color? dangerBorder,
    Color? emergencyBg,
    Color? emergencyFg,
    Color? emergencyBorder,
    Color? infoBg,
    Color? infoFg,
    Color? infoBorder,
  }) {
    return LacakSemanticColors(
      safeBg: safeBg ?? this.safeBg,
      safeFg: safeFg ?? this.safeFg,
      safeBorder: safeBorder ?? this.safeBorder,
      warnBg: warnBg ?? this.warnBg,
      warnFg: warnFg ?? this.warnFg,
      warnBorder: warnBorder ?? this.warnBorder,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerFg: dangerFg ?? this.dangerFg,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      emergencyBg: emergencyBg ?? this.emergencyBg,
      emergencyFg: emergencyFg ?? this.emergencyFg,
      emergencyBorder: emergencyBorder ?? this.emergencyBorder,
      infoBg: infoBg ?? this.infoBg,
      infoFg: infoFg ?? this.infoFg,
      infoBorder: infoBorder ?? this.infoBorder,
    );
  }

  @override
  LacakSemanticColors lerp(
    covariant ThemeExtension<LacakSemanticColors>? other,
    double t,
  ) {
    if (other is! LacakSemanticColors) {
      return this;
    }
    return LacakSemanticColors(
      safeBg: Color.lerp(safeBg, other.safeBg, t) ?? safeBg,
      safeFg: Color.lerp(safeFg, other.safeFg, t) ?? safeFg,
      safeBorder: Color.lerp(safeBorder, other.safeBorder, t) ?? safeBorder,
      warnBg: Color.lerp(warnBg, other.warnBg, t) ?? warnBg,
      warnFg: Color.lerp(warnFg, other.warnFg, t) ?? warnFg,
      warnBorder: Color.lerp(warnBorder, other.warnBorder, t) ?? warnBorder,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t) ?? dangerBg,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t) ?? dangerFg,
      dangerBorder:
          Color.lerp(dangerBorder, other.dangerBorder, t) ?? dangerBorder,
      emergencyBg:
          Color.lerp(emergencyBg, other.emergencyBg, t) ?? emergencyBg,
      emergencyFg:
          Color.lerp(emergencyFg, other.emergencyFg, t) ?? emergencyFg,
      emergencyBorder:
          Color.lerp(emergencyBorder, other.emergencyBorder, t) ??
          emergencyBorder,
      infoBg: Color.lerp(infoBg, other.infoBg, t) ?? infoBg,
      infoFg: Color.lerp(infoFg, other.infoFg, t) ?? infoFg,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t) ?? infoBorder,
    );
  }
}

/// Convenience accessor for [LacakSemanticColors] on [BuildContext].
extension LacakThemeContextX on BuildContext {
  LacakSemanticColors get semanticColors =>
      Theme.of(this).extension<LacakSemanticColors>() ??
      LacakSemanticColors.light;
}

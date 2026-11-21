import 'package:material_ui/material_ui.dart';

import '../theme/app_semantic_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum LacakStatusLevel {
  safe,
  warning,
  danger,
  emergency,
  offline,
}

/// Compact tag combining color, Material Rounded icon, and explicit text (max 1 per row).
class LacakStatusTag extends StatelessWidget {
  const LacakStatusTag({
    super.key,
    required this.level,
    required this.label,
    this.icon,
  });

  final LacakStatusLevel level;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = _StatusVisual.fromLevel(context.semanticColors, level);
    final resolvedIcon = icon ?? palette.defaultIcon;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolvedIcon, size: 16, color: palette.foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelTag.copyWith(color: palette.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width semantic banner with uniform 1dp border and no 4dp left stripe.
class LacakStatusBanner extends StatelessWidget {
  const LacakStatusBanner({
    super.key,
    required this.level,
    required this.title,
    this.description,
    this.icon,
    this.action,
  });

  final LacakStatusLevel level;
  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = _StatusVisual.fromLevel(context.semanticColors, level);
    final resolvedIcon = icon ?? palette.defaultIcon;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBanner),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(resolvedIcon, size: 24, color: palette.foreground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleItem.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.background,
    required this.foreground,
    required this.border,
    required this.defaultIcon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData defaultIcon;

  static _StatusVisual fromLevel(
    LacakSemanticColors colors,
    LacakStatusLevel level,
  ) {
    switch (level) {
      case LacakStatusLevel.safe:
        return _StatusVisual(
          background: colors.safeBg,
          foreground: colors.safeFg,
          border: colors.safeBorder,
          defaultIcon: Icons.check_circle_rounded,
        );
      case LacakStatusLevel.warning:
        return _StatusVisual(
          background: colors.warnBg,
          foreground: colors.warnFg,
          border: colors.warnBorder,
          defaultIcon: Icons.warning_amber_rounded,
        );
      case LacakStatusLevel.danger:
        return _StatusVisual(
          background: colors.dangerBg,
          foreground: colors.dangerFg,
          border: colors.dangerBorder,
          defaultIcon: Icons.dangerous_rounded,
        );
      case LacakStatusLevel.emergency:
        return _StatusVisual(
          background: colors.emergencyBg,
          foreground: colors.emergencyFg,
          border: colors.emergencyBorder,
          defaultIcon: Icons.notification_important_rounded,
        );
      case LacakStatusLevel.offline:
        return _StatusVisual(
          background: colors.infoBg,
          foreground: colors.infoFg,
          border: colors.infoBorder,
          defaultIcon: Icons.cloud_off_rounded,
        );
    }
  }
}

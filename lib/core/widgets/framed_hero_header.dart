import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Key metric item anchored along the bottom of [FramedHeroHeader].
class HeroMetricItem {
  const HeroMetricItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// Detail screen framed hero image (16dp horizontal margin, 20dp radius) with dark-translucent circular controls.
class FramedHeroHeader extends StatelessWidget {
  const FramedHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.image,
    this.imagePlaceholder,
    this.metrics = const [],
    this.onBackTap,
    this.actionIcon,
    this.actionTooltip,
    this.onActionTap,
    this.height = 276,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  final String title;
  final String? subtitle;
  final ImageProvider? image;
  final Widget? imagePlaceholder;
  final List<HeroMetricItem> metrics;
  final VoidCallback? onBackTap;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onActionTap;
  final double height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final fallback = imagePlaceholder ??
        Container(
          color: AppColors.primaryTint,
          alignment: Alignment.center,
          child: const Icon(
            Icons.photo_camera_back_rounded,
            size: 52,
            color: AppColors.primary,
          ),
        );

    final resolvedBackTap = onBackTap ?? () => Navigator.of(context).maybePop();

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusHero),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image(
                  image: image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              else
                fallback,
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.65, 1.0],
                      colors: [
                        const Color(0xFF181E1B).withValues(alpha: 0.24),
                        Colors.transparent,
                        const Color(0xFF181E1B).withValues(alpha: 0.45),
                        AppColors.scrimDark,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeroCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Kembali',
                      onTap: resolvedBackTap,
                    ),
                    if (actionIcon != null && onActionTap != null)
                      _HeroCircleButton(
                        icon: actionIcon!,
                        tooltip: actionTooltip ?? 'Aksi',
                        onTap: onActionTap!,
                      ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.xl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlinePage.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
                      ),
                    ],
                    if (metrics.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.sm,
                        children: metrics
                            .map(
                              (metric) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      metric.icon,
                                      size: 16,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(
                                      metric.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.tabular(
                                        AppTypography.labelTag.copyWith(
                                          color: AppColors.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.scrimPill,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              child: Icon(
                icon,
                size: 20,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

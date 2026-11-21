import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_buttons.dart';
import 'lacak_section_surface.dart';

/// Flat non-animated skeleton placeholder block matching DESIGN.md 5.6 (MOTION 1).
class LacakSkeletonBox extends StatelessWidget {
  const LacakSkeletonBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppSpacing.radiusTag,
    this.color = AppColors.skeletonFill,
  });

  final double height;
  final double width;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Open-canvas skeleton layout that mirrors the redesigned UI hierarchy:
/// visible loading status label + optional tonal summary/CTA placeholders on canvas
/// + a single clean divided list surface with title, status tag, and metadata bars.
class LacakSkeletonList extends StatelessWidget {
  const LacakSkeletonList({
    super.key,
    this.itemCount = 3,
    this.loadingLabel = 'Memuat data keamanan pangan...',
    this.showHeaderBlock = false,
    this.showHeroActionBlock = false,
  });

  final int itemCount;
  final String loadingLabel;
  final bool showHeaderBlock;
  final bool showHeroActionBlock;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: loadingLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loadingLabel,
                  style: AppTypography.labelTag.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (showHeaderBlock) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: LacakSkeletonBox(height: 22, width: 140),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      LacakSkeletonBox(height: 20, width: 84),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  LacakSkeletonBox(height: 14, width: 210),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (showHeroActionBlock) ...[
            const LacakSkeletonBox(
              height: AppSpacing.primaryButtonMinHeight,
              radius: AppSpacing.radiusControl,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const LacakSkeletonBox(height: 16, width: 148),
          const SizedBox(height: AppSpacing.sm),
          LacakSectionSurface.separated(
            children: List.generate(
              itemCount,
              (index) {
                final titleWidth = index.isEven ? 168.0 : 144.0;
                final subWidth = index.isEven ? 220.0 : 196.0;
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: LacakSkeletonBox(
                              height: 16,
                              width: titleWidth,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const LacakSkeletonBox(
                            height: 22,
                            width: 76,
                            radius: AppSpacing.radiusTag,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LacakSkeletonBox(height: 13, width: subWidth),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain vector empty state on a soft tonal surface without heavy double card borders.
class LacakEmptyState extends StatelessWidget {
  const LacakEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
        border: Border.all(color: AppColors.borderHairline, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleSection,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            LacakPrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Plain-language error view stating what failed and offering a clear retry path.
class LacakErrorState extends StatelessWidget {
  const LacakErrorState({
    super.key,
    required this.message,
    this.title = 'Data belum dapat dimuat',
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
        border: Border.all(color: AppColors.dangerBorder, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: AppColors.dangerFg,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleSection,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            LacakSecondaryButton(
              label: retryLabel,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

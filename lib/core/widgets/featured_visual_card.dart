import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Vertical 18dp-rounded photo card with soft dark bottom gradient and top-right translucent pill badge.
class FeaturedVisualCard extends StatelessWidget {
  const FeaturedVisualCard({
    super.key,
    required this.title,
    this.subtitle,
    this.image,
    this.imagePlaceholder,
    this.badgeLabel,
    this.badgeIcon,
    this.onTap,
    this.width = 228,
    this.height = 264,
  });

  final String title;
  final String? subtitle;
  final ImageProvider? image;
  final Widget? imagePlaceholder;
  final String? badgeLabel;
  final IconData? badgeIcon;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = imagePlaceholder ??
        Container(
          color: AppColors.primaryTint,
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant_rounded,
            size: 44,
            color: AppColors.primary,
          ),
        );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: InkWell(
          onTap: onTap,
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
                      stops: const [0.35, 0.70, 1.0],
                      colors: [
                        Colors.transparent,
                        const Color(0xFF181E1B).withValues(alpha: 0.42),
                        AppColors.scrimDark,
                      ],
                    ),
                  ),
                ),
              ),
              if (badgeLabel != null && badgeLabel!.trim().isNotEmpty)
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: width - AppSpacing.md * 2,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scrimPill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeIcon != null) ...[
                            Icon(
                              badgeIcon,
                              size: 14,
                              color: AppColors.onPrimary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              badgeLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.tabular(
                                AppTypography.captionLegal.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleItem.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionLegal.copyWith(
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
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

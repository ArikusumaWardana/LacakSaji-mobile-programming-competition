import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Small icon + text metadata item rendered inside [BorderlessThumbTile].
class BorderlessMetaItem {
  const BorderlessMetaItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// Borderless list item with a rounded square thumbnail on the left and clean vertical rhythm.
class BorderlessThumbTile extends StatelessWidget {
  const BorderlessThumbTile({
    super.key,
    required this.title,
    required this.statusText,
    this.thumbnail,
    this.fallbackIcon = Icons.restaurant_menu_rounded,
    this.fallbackBgColor,
    this.fallbackIconColor,
    this.statusColor,
    this.metadata = const [],
    this.trailing,
    this.onTap,
    this.showBottomDivider = false,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.md),
  });

  final String title;
  final String statusText;
  final ImageProvider? thumbnail;
  final IconData fallbackIcon;
  final Color? fallbackBgColor;
  final Color? fallbackIconColor;
  final Color? statusColor;
  final List<BorderlessMetaItem> metadata;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showBottomDivider;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolvedStatusColor = statusColor ?? AppColors.primary;
    final thumbPlaceholder = Container(
      width: 76,
      height: 76,
      color: fallbackBgColor ?? AppColors.surfaceSoft,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: 28,
        color: fallbackIconColor ?? AppColors.primary,
      ),
    );

    final rowContent = Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusThumb),
              child: SizedBox(
                width: 76,
                height: 76,
                child: thumbnail != null
                    ? Image(
                        image: thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => thumbPlaceholder,
                      )
                    : thumbPlaceholder,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleItem.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.tabular(
                      AppTypography.labelTag.copyWith(
                        color: resolvedStatusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: metadata
                          .map(
                            (item) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.tabular(
                                      AppTypography.captionMuted,
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
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusThumb),
            splashColor: AppColors.surfaceSoft,
            highlightColor: AppColors.surfaceSoft,
            child: rowContent,
          ),
        ),
        if (showBottomDivider)
          const Divider(height: 1, thickness: 1, color: AppColors.borderHairline),
      ],
    );
  }
}

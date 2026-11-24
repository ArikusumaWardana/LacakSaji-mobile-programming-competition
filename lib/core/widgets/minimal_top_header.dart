import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_shell.dart';

/// Borderless top header on airy white canvas replacing solid colored AppBars.
class MinimalTopHeader extends StatelessWidget {
  const MinimalTopHeader({
    super.key,
    required this.contextLabel,
    required this.title,
    this.onMenuTap,
    this.showMenuButton,
    this.onTitleTap,
    this.onNotificationTap,
    this.hasUnreadAlert = false,
    this.notificationTooltip = 'Notifikasi',
    this.includeTopSafeArea = true,
    this.padding,
  });

  final String contextLabel;
  final String title;
  final VoidCallback? onMenuTap;
  final bool? showMenuButton;
  final VoidCallback? onTitleTap;
  final VoidCallback? onNotificationTap;
  final bool hasUnreadAlert;
  final String notificationTooltip;
  final bool includeTopSafeArea;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shellScope = AppShellScope.maybeOf(context);
    final isPermanentSidebar = shellScope?.isPermanentSidebar ?? false;
    final displayMenuButton =
        showMenuButton ?? (!isPermanentSidebar && (onMenuTap != null || shellScope != null));
    final resolvedMenuTap = onMenuTap ?? shellScope?.toggleDrawer;
    final horizontalPad = padding ??
        EdgeInsets.fromLTRB(
          displayMenuButton ? AppSpacing.sm : AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          contextLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.captionMuted,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlinePage,
              ),
            ),
            if (onTitleTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ],
          ],
        ),
      ],
    );

    final headerContent = Padding(
      padding: horizontalPad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (displayMenuButton) ...[
            IconButton(
              onPressed: resolvedMenuTap,
              tooltip: 'Buka menu navigasi',
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              icon: const Icon(
                Icons.menu_rounded,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: onTitleTap != null
                ? InkWell(
                    onTap: onTitleTap,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      child: titleColumn,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    child: titleColumn,
                  ),
          ),
          if (onNotificationTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Semantics(
              button: true,
              label: hasUnreadAlert
                  ? '$notificationTooltip (ada pemberitahuan baru)'
                  : notificationTooltip,
              child: Tooltip(
                message: notificationTooltip,
                child: InkWell(
                  onTap: onNotificationTap,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.minTouchTarget / 2,
                  ),
                  child: SizedBox(
                    width: AppSpacing.minTouchTarget,
                    height: AppSpacing.minTouchTarget,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 25,
                            color: AppColors.textPrimary,
                          ),
                          if (hasUnreadAlert)
                            Positioned(
                              top: -1,
                              right: -1,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppColors.dangerFg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.bgCanvas,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!includeTopSafeArea) {
      return headerContent;
    }
    return SafeArea(bottom: false, child: headerContent);
  }
}

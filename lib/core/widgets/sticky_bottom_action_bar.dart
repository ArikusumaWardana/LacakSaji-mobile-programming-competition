import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Fixed white detail footer displaying a summary status/value on the left and primary CTA on the right.
class StickyBottomActionBar extends StatelessWidget {
  const StickyBottomActionBar({
    super.key,
    required this.summaryLabel,
    required this.summaryValue,
    required this.ctaLabel,
    required this.onCtaPressed,
    this.summaryValueColor,
    this.ctaIcon,
    this.isLoading = false,
    this.ctaColor,
  });

  final String summaryLabel;
  final String summaryValue;
  final Color? summaryValueColor;
  final String ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCtaPressed;
  final bool isLoading;
  final Color? ctaColor;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final effectiveOnPressed = isLoading ? null : onCtaPressed;

    final summaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.captionMuted,
        ),
        const SizedBox(height: 2),
        Text(
          summaryValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.tabular(
            AppTypography.titleSection.copyWith(
              color: summaryValueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final buttonWidget = ElevatedButton(
      onPressed: effectiveOnPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(124, AppSpacing.secondaryButtonMinHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled) && !isLoading) {
            return AppColors.surfaceSoft;
          }
          return ctaColor ?? AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled) && !isLoading) {
            return AppColors.textMuted;
          }
          return AppColors.onPrimary;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (ctaIcon != null) ...[
            Icon(ctaIcon, size: 20, color: AppColors.onPrimary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              ctaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelButton.copyWith(
                color: effectiveOnPressed == null && !isLoading
                    ? AppColors.textMuted
                    : AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: AppColors.surfaceBase,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderHairline, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackVertically =
                    constraints.maxWidth < 340 && textScale >= 1.25;
                if (stackVertically) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      summaryColumn,
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(width: double.infinity, child: buttonWidget),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: summaryColumn),
                    const SizedBox(width: AppSpacing.lg),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.56,
                      ),
                      child: buttonWidget,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

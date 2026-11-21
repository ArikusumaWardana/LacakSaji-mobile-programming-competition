import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Primary 56dp button with single-line anti-slop solid pine fill and loading debounce.
class LacakPrimaryButton extends StatelessWidget {
  const LacakPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.minHeight = AppSpacing.primaryButtonMinHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    return ElevatedButton(
      onPressed: effectiveOnPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, minHeight),
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        foregroundColor: effectiveOnPressed == null && !isLoading
            ? AppColors.textMuted
            : AppColors.onPrimary,
      ),
    );
  }
}

/// Secondary 52dp outlined button using primary pine border.
class LacakSecondaryButton extends StatelessWidget {
  const LacakSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    return OutlinedButton(
      onPressed: effectiveOnPressed,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        foregroundColor: effectiveOnPressed == null && !isLoading
            ? AppColors.textMuted
            : AppColors.primary,
      ),
    );
  }
}

/// Solid emergency 56dp button reserved strictly for critical stop/KLB actions.
class LacakDangerButton extends StatelessWidget {
  const LacakDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.notification_important_rounded,
    this.isLoading = false,
    this.minHeight = AppSpacing.primaryButtonMinHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    return ElevatedButton(
      onPressed: effectiveOnPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(double.infinity, minHeight)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled) && !isLoading) {
            return AppColors.surfaceSubtle;
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.emergencyBorder;
          }
          return AppColors.emergencyBg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled) && !isLoading) {
            return AppColors.textMuted;
          }
          return AppColors.emergencyFg;
        }),
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        foregroundColor: effectiveOnPressed == null && !isLoading
            ? AppColors.textMuted
            : AppColors.emergencyFg,
      ),
    );
  }
}

/// Senior-friendly large selection row replacing tiny radio buttons (DESIGN.md 5.2).
class LacakSelectionRow extends StatelessWidget {
  const LacakSelectionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leadingIcon,
    this.minHeight = AppSpacing.selectionRowMinHeight,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryTint : AppColors.surfaceBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderHairline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 24,
                    color: selected
                        ? AppColors.onPrimaryTint
                        : AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleItem.copyWith(
                          color: selected
                              ? AppColors.onPrimaryTint
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: selected
                                ? AppColors.onPrimaryTint
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 24,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 22, color: foregroundColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelButton.copyWith(color: foregroundColor),
          ),
        ),
      ],
    );
  }
}

/// Option item for [LacakSegmentedControl].
class LacakSegmentOption<T> {
  const LacakSegmentOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

/// Utilitarian 8dp-radius segmented selector replacing Material's pill SegmentedButton
/// so labels like "Standar" never wrap mid-word into "Standa / r".
class LacakSegmentedControl<T> extends StatelessWidget {
  const LacakSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<LacakSegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        border: Border.all(color: AppColors.borderHairline, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _SegmentButtonTile<T>(
                  option: options[i],
                  selected: options[i].value == selectedValue,
                  onTap: () => onChanged(options[i].value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentButtonTile<T> extends StatelessWidget {
  const _SegmentButtonTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LacakSegmentOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.primary : Colors.transparent;
    final fgColor = selected ? AppColors.onPrimary : AppColors.textPrimary;
    final subColor = selected ? AppColors.onPrimary : AppColors.textSecondary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: AppTypography.labelTag.copyWith(
                      color: fgColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (option.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.tabular(
                      AppTypography.captionLegal.copyWith(
                        color: subColor,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Directional smooth transition switcher for multi-step wizard forms.
/// Slides right-to-left when advancing to the next step and left-to-right
/// when returning to a previous step, while respecting OS reduced-motion settings.
class LacakAnimatedStepSwitcher extends StatefulWidget {
  const LacakAnimatedStepSwitcher({
    super.key,
    required this.currentStep,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  final int currentStep;
  final Widget child;
  final Duration duration;

  @override
  State<LacakAnimatedStepSwitcher> createState() =>
      _LacakAnimatedStepSwitcherState();
}

class _LacakAnimatedStepSwitcherState extends State<LacakAnimatedStepSwitcher> {
  bool _isForward = true;

  @override
  void didUpdateWidget(covariant LacakAnimatedStepSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStep != oldWidget.currentStep) {
      _isForward = widget.currentStep > oldWidget.currentStep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effectiveDuration = reduceMotion ? Duration.zero : widget.duration;
    final currentKey = ValueKey<int>(widget.currentStep);

    return AnimatedSize(
      duration: effectiveDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: effectiveDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == currentKey;
          final beginOffset = isIncoming
              ? Offset(_isForward ? 0.06 : -0.06, 0)
              : Offset(_isForward ? -0.06 : 0.06, 0);
          final slideAnimation = Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: currentKey,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Senior-friendly multi-step progress indicator showing "Langkah X dari Y"
/// with animated horizontal progress segments and local draft persistence indicator.
class LacakStepProgressHeader extends StatelessWidget {
  const LacakStepProgressHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitle,
    this.stepSubtitle,
  });

  final int currentStep;
  final int totalSteps;
  final String stepTitle;
  final String? stepSubtitle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final segmentDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Langkah $currentStep dari $totalSteps',
              style: AppTypography.tabular(
                AppTypography.labelTag.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.save_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Draf tersimpan otomatis',
                  style: AppTypography.captionLegal.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 1; i <= totalSteps; i++) ...[
              if (i > 1) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AnimatedContainer(
                  duration: segmentDuration,
                  curve: Curves.easeOutCubic,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= currentStep
                        ? AppColors.primary
                        : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LacakAnimatedStepSwitcher(
          currentStep: currentStep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stepTitle,
                style: AppTypography.headlinePage,
              ),
              if (stepSubtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  stepSubtitle!,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

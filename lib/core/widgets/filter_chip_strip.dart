import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Item descriptor for [FilterChipStrip].
class FilterChipItem<T> {
  const FilterChipItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Horizontal scrollable filter chip strip (active: solid #234B3E, inactive: #F4F5F4).
class FilterChipStrip<T> extends StatelessWidget {
  const FilterChipStrip({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  final List<FilterChipItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _EditorialFilterChip<T>(
              item: items[i],
              selected: items[i].value == selectedValue,
              onTap: () => onSelected(items[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wrapped multi-select filter chip strip (active: solid #234B3E, inactive: #F4F5F4).
class MultiSelectFilterChipStrip<T> extends StatelessWidget {
  const MultiSelectFilterChipStrip({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onToggled,
    this.padding = EdgeInsets.zero,
  });

  final List<FilterChipItem<T>> items;
  final Set<T> selectedValues;
  final ValueChanged<T> onToggled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final item in items)
            _EditorialFilterChip<T>(
              item: FilterChipItem<T>(
                value: item.value,
                label: item.label,
                icon: selectedValues.contains(item.value)
                    ? Icons.check_rounded
                    : item.icon,
              ),
              selected: selectedValues.contains(item.value),
              onTap: () => onToggled(item.value),
            ),
        ],
      ),
    );
  }
}

class _EditorialFilterChip<T> extends StatelessWidget {
  const _EditorialFilterChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FilterChipItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.primary : AppColors.surfaceSoft;
    final fgColor = selected ? AppColors.onPrimary : AppColors.chipInactiveText;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 18, color: fgColor),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelTag.copyWith(
                        color: fgColor,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Soft-filled #F4F5F4 search input paired with a square #234B3E action button.
class SearchAndActionBar extends StatefulWidget {
  const SearchAndActionBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Cari...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onActionTap,
    this.actionIcon = Icons.tune_rounded,
    this.actionTooltip = 'Filter',
    this.showActionButton = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onActionTap;
  final IconData actionIcon;
  final String actionTooltip;
  final bool showActionButton;

  @override
  State<SearchAndActionBar> createState() => _SearchAndActionBarState();
}

class _SearchAndActionBarState extends State<SearchAndActionBar> {
  TextEditingController? _internalController;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant SearchAndActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      if (widget.controller == null) {
        _internalController ??= TextEditingController();
      } else {
        _internalController?.removeListener(_handleTextChange);
        _internalController?.dispose();
        _internalController = null;
      }
      _effectiveController.addListener(_handleTextChange);
    }
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleTextChange);
    _internalController?.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _effectiveController.text.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: TextField(
              controller: _effectiveController,
              focusNode: widget.focusNode,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: widget.hintText,
                filled: true,
                fillColor: AppColors.surfaceSoft,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: hasText
                    ? IconButton(
                        onPressed: _clearSearch,
                        tooltip: 'Hapus pencarian',
                        constraints: const BoxConstraints(
                          minWidth: AppSpacing.minTouchTarget,
                          minHeight: AppSpacing.minTouchTarget,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: const BorderSide(
                    color: AppColors.borderFocus,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showActionButton) ...[
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: widget.actionTooltip,
            child: Tooltip(
              message: widget.actionTooltip,
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                child: InkWell(
                  onTap: widget.onActionTap,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(
                      widget.actionIcon,
                      size: 22,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

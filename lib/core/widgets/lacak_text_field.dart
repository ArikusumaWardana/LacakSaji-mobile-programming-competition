import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Accessible form input with static label positioned above the field (DESIGN.md 5.4).
class LacakTextField extends StatefulWidget {
  const LacakTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.isPassword = false,
    this.readOnly = false,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixWidget,
    this.validator,
    this.onTap,
    this.onChanged,
    this.onFieldSubmitted,
    this.useTabularFigures = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool isPassword;
  final bool readOnly;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool useTabularFigures;

  @override
  State<LacakTextField> createState() => _LacakTextFieldState();
}

class _LacakTextFieldState extends State<LacakTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.useTabularFigures
        ? AppTypography.tabular(AppTypography.bodyLarge)
        : AppTypography.bodyLarge;

    Widget? resolvedSuffix = widget.suffixWidget;
    if (widget.isPassword) {
      resolvedSuffix = IconButton(
        onPressed: () => setState(() => _obscureText = !_obscureText),
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        tooltip: _obscureText ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
        icon: Icon(
          _obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          size: 22,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: AppTypography.labelTag.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          obscureText: widget.isPassword && _obscureText,
          readOnly: widget.readOnly,
          maxLength: widget.maxLength,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: textStyle,
          decoration: InputDecoration(
            hintText: widget.hintText,
            helperText: widget.helperText,
            helperMaxLines: 2,
            helperStyle: AppTypography.captionLegal.copyWith(
              color: AppColors.textSecondary,
            ),
            errorMaxLines: 2,
            counterText: '',
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    size: 22,
                    color: AppColors.textSecondary,
                  )
                : null,
            suffixIcon: resolvedSuffix,
          ),
        ),
      ],
    );
  }
}

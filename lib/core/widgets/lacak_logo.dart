import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Custom geometric minimalist vector brand mark for LacakSaji.
/// Combines a serving cloche/dome ("Saji") and a precision verification crosshair/scan mark ("Lacak")
/// in solid pine (#234B3E) and warm paper (#F6F7F5) without relying on generic shield icons.
class LacakLogoMark extends StatelessWidget {
  const LacakLogoMark({
    super.key,
    this.size = 44,
    this.inverted = false,
  });

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final bgColor = inverted ? AppColors.surfaceBase : AppColors.primary;
    final fgColor = inverted ? AppColors.primary : AppColors.onPrimary;
    final accentColor = inverted ? AppColors.primaryTint : AppColors.primaryTint;
    final radius = (size * 0.22).clamp(6.0, 14.0);

    return Semantics(
      label: 'Logo LacakSaji',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _LacakLogoPainter(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            accentColor: accentColor,
            cornerRadius: radius,
          ),
        ),
      ),
    );
  }
}

/// Horizontal lockup pairing [LacakLogoMark] with the LacakSaji wordmark and optional subtitle.
class LacakBrandHeader extends StatelessWidget {
  const LacakBrandHeader({
    super.key,
    this.title = 'LacakSaji',
    this.subtitle,
    this.logoSize = 40,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final double logoSize;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LacakLogoMark(size: logoSize),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.headlinePage,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTypography.labelTag.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
    );
  }
}

class _LacakLogoPainter extends CustomPainter {
  const _LacakLogoPainter({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.accentColor,
    required this.cornerRadius,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color accentColor;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Base rounded square container
    final baseRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cornerRadius),
    );
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(baseRect, bgPaint);

    // 2. Subtle QR scan corner brackets ("Lacak" frame)
    final bracketStroke = (w * 0.055).clamp(1.6, 3.2);
    final bracketPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bracketStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inset = w * 0.17;
    final arm = w * 0.12;

    final bracketPath = Path()
      // Top-left corner bracket
      ..moveTo(inset, inset + arm)
      ..lineTo(inset, inset)
      ..lineTo(inset + arm, inset)
      // Top-right corner bracket
      ..moveTo(w - inset - arm, inset)
      ..lineTo(w - inset, inset)
      ..lineTo(w - inset, inset + arm)
      // Bottom-left corner bracket
      ..moveTo(inset, h - inset - arm)
      ..lineTo(inset, h - inset)
      ..lineTo(inset + arm, h - inset)
      // Bottom-right corner bracket
      ..moveTo(w - inset - arm, h - inset)
      ..lineTo(w - inset, h - inset)
      ..lineTo(w - inset, h - inset - arm);
    canvas.drawPath(bracketPath, bracketPaint);

    // 3. Minimalist serving dome / bowl silhouette ("Saji")
    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    // Top handle dot of the serving cloche
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.31),
      w * 0.045,
      fgPaint,
    );

    // Cloche dome arch
    final domeRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.58),
      width: w * 0.48,
      height: h * 0.44,
    );
    final domePath = Path()
      ..arcTo(domeRect, 3.14159265, 3.14159265, false)
      ..close();
    canvas.drawPath(domePath, fgPaint);

    // Base tray bar beneath the dome
    final trayRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.62, w * 0.56, h * 0.075),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(trayRect, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _LacakLogoPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

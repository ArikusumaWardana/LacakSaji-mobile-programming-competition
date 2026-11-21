import 'package:material_ui/material_ui.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_buttons.dart';

/// High-contrast flat confirmation dialog for critical actions (logout, rejection, alert).
Future<bool> showLacakConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  bool isDanger = false,
  IconData? confirmIcon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title, style: AppTypography.titleSection),
        content: Text(message, style: AppTypography.bodyLarge),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDanger)
                LacakDangerButton(
                  label: confirmLabel,
                  icon: confirmIcon ?? Icons.warning_amber_rounded,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                )
              else
                LacakPrimaryButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              const SizedBox(height: AppSpacing.md),
              LacakSecondaryButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

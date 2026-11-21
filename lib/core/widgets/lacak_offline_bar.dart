import 'package:material_ui/material_ui.dart';

import '../theme/app_semantic_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Global O02 status bar displayed below AppBar when offline or syncing Drift queue.
class LacakOfflineBar extends StatelessWidget {
  const LacakOfflineBar({
    super.key,
    required this.isOffline,
    this.pendingSyncCount = 0,
    this.isSyncing = false,
    this.statusErrorMessage,
    this.onSyncTap,
    this.onInspectTap,
  });

  final bool isOffline;
  final int pendingSyncCount;
  final bool isSyncing;
  final String? statusErrorMessage;
  final VoidCallback? onSyncTap;
  final VoidCallback? onInspectTap;

  @override
  Widget build(BuildContext context) {
    if (!isOffline && !isSyncing && pendingSyncCount == 0) {
      return const SizedBox.shrink();
    }

    final colors = context.semanticColors;
    final hasError =
        !isOffline &&
        !isSyncing &&
        pendingSyncCount > 0 &&
        statusErrorMessage != null &&
        statusErrorMessage!.trim().isNotEmpty;

    final IconData icon;
    final String message;

    if (isOffline) {
      icon = Icons.cloud_off_rounded;
      message = pendingSyncCount > 0
          ? 'Mode Tanpa Sinyal. $pendingSyncCount data tersimpan aman di HP.'
          : 'Mode Tanpa Sinyal. Semua pemeriksaan tetap tersimpan aman di HP.';
    } else if (isSyncing) {
      icon = Icons.sync_rounded;
      message = pendingSyncCount > 0
          ? 'Mengirim $pendingSyncCount data tersimpan ke server...'
          : 'Mengirim data tersimpan ke server...';
    } else if (hasError) {
      icon = Icons.error_outline_rounded;
      message =
          '$pendingSyncCount data gagal terkirim. Ketuk untuk lihat rincian.';
    } else {
      icon = Icons.cloud_upload_outlined;
      message =
          '$pendingSyncCount data belum terkirim ke server. Ketuk untuk lihat.';
    }

    final canSendNow =
        !isOffline && !isSyncing && pendingSyncCount > 0 && onSyncTap != null;
    final canInspect = pendingSyncCount > 0 && onInspectTap != null;
    final rowTap = canInspect ? onInspectTap : (canSendNow ? onSyncTap : null);

    final bgColor = hasError ? colors.warnBg : colors.infoBg;
    final fgColor = hasError ? colors.warnFg : colors.infoFg;
    final borderColor = hasError ? colors.warnBorder : colors.infoBorder;

    return Material(
      color: bgColor,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: (canSendNow || canInspect) ? AppSpacing.minTouchTarget : 36,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: rowTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: fgColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          message,
                          style: AppTypography.labelTag.copyWith(color: fgColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (canSendNow)
              InkWell(
                onTap: onSyncTap,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hasError ? 'Coba Lagi' : 'Kirim',
                    style: AppTypography.labelTag.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

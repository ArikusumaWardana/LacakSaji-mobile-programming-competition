import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../database/database_provider.dart';
import '../network/connectivity_provider.dart';
import '../sync/offline_sync_controller.dart';
import '../sync/sync_queue_presenter.dart';
import '../theme/app_colors.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_buttons.dart';
import 'lacak_status_badge.dart';

/// Triggers manual sync from global banner and always shows clear SnackBar feedback.
Future<void> runInteractiveSyncWithFeedback(
  BuildContext context,
  WidgetRef ref,
) async {
  final report = await ref
      .read(offlineSyncControllerProvider.notifier)
      .syncNowWithReport();
  if (!context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  final colors = context.semanticColors;
  final message = report.buildFeedbackMessage();

  messenger.clearSnackBars();
  final useWarningStyle = report.hasFailure;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: useWarningStyle
            ? AppTypography.bodyMedium.copyWith(color: colors.warnFg)
            : null,
      ),
      backgroundColor: useWarningStyle ? colors.warnBg : null,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: report.remainingCount > 0
          ? SnackBarAction(
              label: 'Lihat Rincian',
              textColor: useWarningStyle ? colors.warnFg : null,
              onPressed: () {
                if (context.mounted) {
                  showPendingSyncQueueSheet(context, ref);
                }
              },
            )
          : null,
    ),
  );
}

/// Opens a bottom sheet showing what local data is waiting in HP and why any failed.
Future<void> showPendingSyncQueueSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgCanvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusSurface),
      ),
    ),
    builder: (sheetContext) => const _PendingSyncQueueSheet(),
  );
}

class _PendingSyncQueueSheet extends ConsumerStatefulWidget {
  const _PendingSyncQueueSheet();

  @override
  ConsumerState<_PendingSyncQueueSheet> createState() =>
      _PendingSyncQueueSheetState();
}

class _PendingSyncQueueSheetState
    extends ConsumerState<_PendingSyncQueueSheet> {
  String? _inlineFeedback;
  bool _inlineIsError = false;

  Future<void> _handleSendNow() async {
    final report = await ref
        .read(offlineSyncControllerProvider.notifier)
        .syncNowWithReport();
    if (!mounted) {
      return;
    }
    setState(() {
      _inlineFeedback = report.buildFeedbackMessage();
      _inlineIsError = report.hasFailure || report.otherAccountCount > 0;
    });
  }

  Future<void> _handleRemoveItem(SyncQueueItemSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data dari Antrean?'),
        content: Text(
          item.belongsToCurrentAccount
              ? 'Data "${item.title}" belum terkirim ke server. Jika dihapus dari antrean HP, data ini tidak akan dikirim lagi.'
              : 'Data "${item.title}" tercatat untuk akun atau peran lain dan tidak bisa dikirim dari akun ini. Hapus dari antrean HP?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref
        .read(offlineSyncControllerProvider.notifier)
        .removeQueuedItem(item.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _inlineFeedback = '1 data dihapus dari antrean pengiriman HP.';
      _inlineIsError = false;
    });
  }

  Future<void> _handleClearOtherAccountItems(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data Akun Lain?'),
        content: Text(
          '$count data di antrean HP dibuat saat masuk memakai akun atau peran berbeda. Data tersebut tidak dapat dikirim dengan akun saat ini. Hapus dari antrean HP?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final removed = await ref
        .read(offlineSyncControllerProvider.notifier)
        .removeOtherAccountItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _inlineFeedback = '$removed data akun lain dihapus dari antrean HP.';
      _inlineIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(pendingSyncItemsProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final auth = ref.watch(authControllerProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final syncState = ref.watch(offlineSyncControllerProvider);
    final colors = context.semanticColors;

    final rows = rowsAsync.value ?? const [];
    final items = summarizePendingSyncItems(
      rows,
      kitchen: auth.kitchen,
      school: auth.school,
      isAuthenticated: auth.status == AuthStatus.authenticated,
    );
    final displayCount = items.isNotEmpty ? items.length : pendingCount;
    final sendableCount =
        items.where((item) => item.belongsToCurrentAccount).length;
    final otherAccountCount = items.length - sendableCount;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayCount > 0
                            ? '$displayCount Data Tersimpan di HP'
                            : 'Antrean Kirim Kosong',
                        style: AppTypography.titleSection,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        displayCount > 0
                            ? 'Rincian catatan yang menunggu dikirim ke server.'
                            : 'Semua data sudah terkirim ke server.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderHairline),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_inlineFeedback != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _inlineIsError
                            ? colors.warnBg
                            : colors.safeBg,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSurface,
                        ),
                        border: Border.all(
                          color: _inlineIsError
                              ? colors.warnBorder
                              : colors.safeBorder,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _inlineIsError
                                ? Icons.info_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: _inlineIsError
                                ? colors.warnFg
                                : colors.safeFg,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _inlineFeedback!,
                              style: AppTypography.bodyMedium.copyWith(
                                color: _inlineIsError
                                    ? colors.warnFg
                                    : colors.safeFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (otherAccountCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.infoBg,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSurface,
                        ),
                        border: Border.all(color: colors.infoBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$otherAccountCount data berasal dari akun atau peran lain',
                            style: AppTypography.titleItem.copyWith(
                              color: colors.infoFg,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Kemungkinan tercatat saat sebelumnya masuk dengan akun demo atau sekolah/dapur yang berbeda.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.infoFg,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: () => _handleClearOtherAccountItems(
                              otherAccountCount,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Hapus Data Akun Lain'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (items.isEmpty && displayCount == 0)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSurface,
                        ),
                        border: Border.all(color: AppColors.borderHairline),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            color: colors.safeFg,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Tidak ada data yang tertunda di penyimpanan HP.',
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...items.map((item) {
                      final badgeLevel = !item.belongsToCurrentAccount
                          ? LacakStatusLevel.offline
                          : item.isFailed
                          ? LacakStatusLevel.warning
                          : LacakStatusLevel.offline;
                      final badgeLabel = !item.belongsToCurrentAccount
                          ? 'Akun Lain'
                          : item.isFailed
                          ? 'Gagal Kirim'
                          : 'Belum Terkirim';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBase,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSurface,
                            ),
                            border: Border.all(
                              color: item.isFailed
                                  ? colors.warnBorder
                                  : AppColors.borderHairline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: AppTypography.titleItem,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  LacakStatusTag(
                                    level: badgeLevel,
                                    label: badgeLabel,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                item.detailLine,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (item.friendlyError != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: colors.warnBg,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusControl,
                                    ),
                                  ),
                                  child: Text(
                                    item.friendlyError!,
                                    style: AppTypography.labelTag.copyWith(
                                      color: colors.warnFg,
                                    ),
                                  ),
                                ),
                              ],
                              if (item.accountMismatchHint != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  item.accountMismatchHint!,
                                  style: AppTypography.labelTag.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _handleRemoveItem(item),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Hapus dari Antrean'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          if (displayCount > 0)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surfaceBase,
                border: Border(
                  top: BorderSide(color: AppColors.borderHairline),
                ),
              ),
              child: LacakPrimaryButton(
                label: isOffline
                    ? 'Menunggu Koneksi Internet'
                    : (sendableCount > 0
                          ? 'Kirim Sekarang ($sendableCount Data)'
                          : 'Coba Kirim Ulang'),
                icon: Icons.cloud_upload_rounded,
                isLoading: syncState.isSyncing,
                onPressed: isOffline || syncState.isSyncing
                    ? null
                    : _handleSendNow,
              ),
            ),
        ],
      ),
    );
  }
}

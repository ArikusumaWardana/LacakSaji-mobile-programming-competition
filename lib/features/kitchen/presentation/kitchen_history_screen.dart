import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';
import 'widgets/kitchen_photo_builder.dart';

/// D05: Editorial Kitchen batch history & plate-waste evaluation analytics screen.
class KitchenHistoryScreen extends ConsumerWidget {
  const KitchenHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(kitchenHistoryRangeProvider);
    final historyAsync = ref.watch(kitchenHistoryProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = width >= 900 ? 880.0 : AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          const MinimalTopHeader(
            contextLabel: 'Evaluasi & Arsip',
            title: 'Riwayat & Sisa Pangan',
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(kitchenHistoryProvider);
                await ref.read(kitchenHistoryProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        FilterChipStrip<HistoryTimeRange>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: range,
                          onSelected: (selected) {
                            ref
                                .read(kitchenHistoryRangeProvider.notifier)
                                .selectRange(selected);
                          },
                          items: HistoryTimeRange.values
                              .map(
                                (option) => FilterChipItem(
                                  value: option,
                                  label: option.label,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: historyAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 3,
                              showHeaderBlock: true,
                              loadingLabel:
                                  'Memuat riwayat batch dan data sisa makanan...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(kitchenHistoryProvider),
                            ),
                            data: (data) => _HistoryBody(data: data),
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
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.data});

  final KitchenHistoryData data;

  @override
  Widget build(BuildContext context) {
    final summary = data.wasteSummary;
    final batchById = <String, FoodBatchItem>{
      for (final batch in data.batches) batch.id: batch,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WasteSummaryBlock(rangeLabel: data.range.label, summary: summary),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Riwayat Sisa Makanan (${data.wasteLogs.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (data.wasteLogs.isEmpty)
          const LacakEmptyState(
            icon: Icons.restaurant_rounded,
            title: 'Belum ada catatan sisa makanan',
            message:
                'Laporan persentase sisa ompreng yang dikirim Guru / PIC sekolah akan tercatat di sini.',
          )
        else
          Column(
            children: [
              for (var i = 0; i < data.wasteLogs.length; i++)
                _WasteThumbTile(
                  log: data.wasteLogs[i],
                  relatedBatch: batchById[data.wasteLogs[i].batchId],
                  showDivider: i < data.wasteLogs.length - 1,
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Riwayat Batch Makanan (${data.batches.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (data.batches.isEmpty)
          LacakEmptyState(
            icon: Icons.history_rounded,
            title: 'Belum ada batch pada rentang waktu ini',
            message:
                'Batch makanan yang disegel dari dapur akan tersimpan berurutan di daftar ini.',
            actionLabel: 'Buat Batch Baru',
            onAction: () => context.push(AppRoutes.kitchenCreateBatch),
          )
        else
          Column(
            children: [
              for (var i = 0; i < data.batches.length; i++)
                _BatchHistoryThumbTile(
                  batch: data.batches[i],
                  showDivider: i < data.batches.length - 1,
                  onTap: () => context.push(
                    AppRoutes.batchDetailPath(data.batches[i].id),
                    extra: data.batches[i],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _WasteSummaryBlock extends StatelessWidget {
  const _WasteSummaryBlock({
    required this.rangeLabel,
    required this.summary,
  });

  final String rangeLabel;
  final PlateWasteSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.sampleCount == 0) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Belum ada rata-rata sisa makanan pada rentang $rangeLabel.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 2,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Rata-Rata Sisa Makanan ($rangeLabel)',
                    style: AppTypography.titleItem,
                  ),
                  Text(
                    '${summary.sampleCount} laporan',
                    style: AppTypography.tabular(AppTypography.captionMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _WasteProgressRow(
                label: 'Nasi / Karbohidrat',
                percent: summary.avgCarbPct,
              ),
              const SizedBox(height: AppSpacing.md),
              _WasteProgressRow(
                label: 'Lauk / Protein',
                percent: summary.avgProteinPct,
              ),
              const SizedBox(height: AppSpacing.md),
              _WasteProgressRow(
                label: 'Sayuran',
                percent: summary.avgVegPct,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final rec in summary.recommendations)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  summary.hasHighWasteAlert
                      ? Icons.warning_amber_rounded
                      : Icons.fact_check_rounded,
                  size: 19,
                  color: summary.hasHighWasteAlert
                      ? AppColors.warnFg
                      : AppColors.safeFg,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    rec,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WasteProgressRow extends StatelessWidget {
  const _WasteProgressRow({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final isHigh = percent >= 40;
    final barColor = isHigh ? AppColors.warnFg : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelTag.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$percent%',
              style: AppTypography.tabular(
                AppTypography.titleItem.copyWith(
                  color: isHigh ? AppColors.warnFg : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent.clamp(0, 100)) / 100.0,
            minHeight: 8,
            backgroundColor: AppColors.surfaceBase,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

class _WasteThumbTile extends StatelessWidget {
  const _WasteThumbTile({
    required this.log,
    required this.relatedBatch,
    required this.showDivider,
  });

  final PlateWasteLogItem log;
  final FoodBatchItem? relatedBatch;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return KitchenBatchPhotoBuilder(
      localPhotoPath: relatedBatch?.localPhotoPath,
      storagePath: relatedBatch?.packagingPhotoUrl,
      builder: (context, imageProvider) {
        return BorderlessThumbTile(
          thumbnail: imageProvider,
          fallbackIcon: Icons.restaurant_rounded,
          fallbackBgColor:
              log.needsMenuReview ? AppColors.warnBg : AppColors.surfaceSoft,
          fallbackIconColor:
              log.needsMenuReview ? AppColors.warnFg : AppColors.primary,
          title: log.schoolName,
          statusText:
              'Nasi ${log.carbWastePct}% · Lauk ${log.proteinWastePct}% · Sayur ${log.vegWastePct}%',
          statusColor: log.needsMenuReview ? AppColors.warnFg : AppColors.primary,
          metadata: [
            BorderlessMetaItem(
              icon: Icons.restaurant_menu_rounded,
              label: '${log.menuName} (${log.batchCode})',
            ),
            BorderlessMetaItem(
              icon: Icons.schedule_rounded,
              label: formatWibDateTime(log.createdAtUtc),
            ),
          ],
          showBottomDivider: showDivider,
        );
      },
    );
  }
}

class _BatchHistoryThumbTile extends StatelessWidget {
  const _BatchHistoryThumbTile({
    required this.batch,
    required this.showDivider,
    required this.onTap,
  });

  final FoodBatchItem batch;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String statusText;
    final Color statusColor;
    if (batch.hasAnomalyReport) {
      statusText = 'Anomali Dilaporkan';
      statusColor = AppColors.dangerFg;
    } else if (batch.isPendingSync) {
      statusText = 'Belum Terkirim (Offline)';
      statusColor = AppColors.infoFg;
    } else {
      statusText = 'Tersegel · ${batch.portionCount} porsi';
      statusColor = AppColors.primary;
    }

    return KitchenBatchPhotoBuilder(
      localPhotoPath: batch.localPhotoPath,
      storagePath: batch.packagingPhotoUrl,
      builder: (context, imageProvider) {
        return BorderlessThumbTile(
          thumbnail: imageProvider,
          fallbackIcon: Icons.qr_code_2_rounded,
          title: batch.menuName,
          statusText: statusText,
          statusColor: statusColor,
          metadata: [
            BorderlessMetaItem(
              icon: Icons.qr_code_2_rounded,
              label: '${batch.batchCode} · ${batch.riskCategory.label}',
            ),
            BorderlessMetaItem(
              icon: Icons.schedule_rounded,
              label: formatWibDateTime(batch.sealedAtUtc),
            ),
          ],
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          showBottomDivider: showDivider,
          onTap: onTap,
        );
      },
    );
  }
}

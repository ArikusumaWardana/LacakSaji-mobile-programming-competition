import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

/// D05: Kitchen batch history & plate-waste evaluation analytics screen.
class KitchenHistoryScreen extends ConsumerWidget {
  const KitchenHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(kitchenHistoryRangeProvider);
    final historyAsync = ref.watch(kitchenHistoryProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Riwayat & Sisa Pangan')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(kitchenHistoryProvider);
            await ref.read(kitchenHistoryProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              AppSpacing.lg,
              horizontalPad,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LacakSegmentedControl<HistoryTimeRange>(
                      options: HistoryTimeRange.values
                          .map(
                            (option) => LacakSegmentOption(
                              value: option,
                              label: option.label,
                            ),
                          )
                          .toList(growable: false),
                      selectedValue: range,
                      onChanged: (selected) {
                        ref
                            .read(kitchenHistoryRangeProvider.notifier)
                            .selectRange(selected);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    historyAsync.when(
                      loading: () => const LacakSkeletonList(
                        itemCount: 3,
                        showHeaderBlock: true,
                        loadingLabel:
                            'Memuat riwayat batch dan data sisa makanan...',
                      ),
                      error: (error, _) => LacakErrorState(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(kitchenHistoryProvider),
                      ),
                      data: (data) => _HistoryBody(data: data),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Analitik Sisa Makanan (${data.range.label})',
          style: AppTypography.titleSection,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (summary.sampleCount == 0)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Belum ada data evaluasi sisa makanan pada rentang waktu ini.',
                    style: AppTypography.bodyLarge,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(
            'Rata-rata dari ${summary.sampleCount} laporan ompreng sekolah binaan:',
            style: AppTypography.tabular(AppTypography.bodyMedium),
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
          const SizedBox(height: AppSpacing.md),
          ...summary.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    summary.hasHighWasteAlert
                        ? Icons.warning_amber_rounded
                        : Icons.fact_check_rounded,
                    size: 20,
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
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Riwayat Evaluasi Sekolah (${data.wasteLogs.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.wasteLogs.isEmpty)
          const LacakEmptyState(
            icon: Icons.restaurant_rounded,
            title: 'Belum ada catatan sisa makanan',
            message:
                'Laporan persentase sisa ompreng yang dikirim Guru / PIC sekolah akan tercatat di sini.',
          )
        else
          LacakSectionSurface.separated(
            children: data.wasteLogs
                .map((log) => _WasteLogRow(log: log))
                .toList(growable: false),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Riwayat Batch Makanan (${data.batches.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.sm),
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
          LacakSectionSurface.separated(
            children: data.batches
                .map(
                  (batch) => _HistoryBatchRow(
                    batch: batch,
                    onTap: () => context.push(
                      AppRoutes.batchDetailPath(batch.id),
                      extra: batch,
                    ),
                  ),
                )
                .toList(growable: false),
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
              child: Text(label, style: AppTypography.titleItem),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$percent%',
              style: AppTypography.tabular(
                AppTypography.titleItem.copyWith(
                  color: isHigh ? AppColors.warnFg : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: (percent.clamp(0, 100)) / 100.0,
            minHeight: 10,
            backgroundColor: AppColors.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

class _WasteLogRow extends StatelessWidget {
  const _WasteLogRow({required this.log});

  final PlateWasteLogItem log;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(log.schoolName, style: AppTypography.titleItem),
              LacakStatusTag(
                level: log.needsMenuReview
                    ? LacakStatusLevel.warning
                    : LacakStatusLevel.safe,
                label: log.needsMenuReview ? 'Perlu Evaluasi' : 'Baik',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${log.menuName} · ${log.batchCode} · ${formatWibDateTime(log.createdAtUtc)}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nasi ${log.carbWastePct}% · Lauk ${log.proteinWastePct}% · Sayur ${log.vegWastePct}%',
            style: AppTypography.tabular(
              AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBatchRow extends StatelessWidget {
  const _HistoryBatchRow({required this.batch, required this.onTap});

  final FoodBatchItem batch;
  final VoidCallback onTap;

  LacakStatusTag _buildTag() {
    if (batch.hasAnomalyReport) {
      return const LacakStatusTag(
        level: LacakStatusLevel.danger,
        label: 'Anomali',
      );
    }
    if (batch.isPendingSync) {
      return const LacakStatusTag(
        level: LacakStatusLevel.offline,
        label: 'Belum Terkirim',
      );
    }
    return const LacakStatusTag(
      level: LacakStatusLevel.safe,
      label: 'Tersegel',
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(batch.menuName, style: AppTypography.titleItem),
                      _buildTag(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${batch.batchCode} · ${formatWibDateTime(batch.sealedAtUtc)}',
                    style: AppTypography.tabular(AppTypography.bodyMedium),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${batch.riskCategory.label} · ${batch.portionCount} porsi · ${batch.inspectedSchoolIds.length} sekolah memindai',
                    style: AppTypography.tabular(AppTypography.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

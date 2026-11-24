import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/supervisor_models.dart';
import 'supervisor_providers.dart';

/// B01: Editorial read-only BGN/Dinkes supervisor national and per-SPPG compliance screen.
class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final dateFilter = ref.watch(supervisorDateFilterProvider);
    final selectedRegion = ref.watch(supervisorRegionFilterProvider);
    final overviewAsync = ref.watch(supervisorOverviewProvider);

    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = width >= 900 ? 920.0 : AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pemantauan Wilayah · Hanya Baca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile?.fullName.isNotEmpty == true
                              ? profile!.fullName
                              : 'Pengawas BGN Wilayah',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlinePage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    onPressed: () => ref.invalidate(supervisorOverviewProvider),
                    tooltip: 'Muat Ulang Ringkasan',
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Material(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    child: IconButton(
                      onPressed: () => context.push(AppRoutes.settings),
                      tooltip: 'Pengaturan & Keluar',
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      icon: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(supervisorOverviewProvider);
                await ref.read(supervisorOverviewProvider.future);
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
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pemantauan agregat keamanan distribusi dan evaluasi sisa pangan seluruh SPPG mitra.',
                                style: AppTypography.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    size: 17,
                                    color: AppColors.safeFg,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      'Audit Lintas Wilayah · ${formatIndonesianDate(DateTime.now().toUtc())}',
                                      style: AppTypography.tabular(
                                        AppTypography.captionMuted.copyWith(
                                          color: AppColors.safeFg,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FilterChipStrip<SupervisorDateFilter>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: dateFilter,
                          onSelected: (next) => ref
                              .read(supervisorDateFilterProvider.notifier)
                              .setFilter(next),
                          items: SupervisorDateFilter.values
                              .map(
                                (item) => FilterChipItem<SupervisorDateFilter>(
                                  value: item,
                                  label: item.label,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        overviewAsync.when(
                          loading: () => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: const LacakSkeletonList(
                              itemCount: 3,
                              showHeaderBlock: true,
                              loadingLabel:
                                  'Memuat ringkasan kepatuhan lintas SPPG...',
                            ),
                          ),
                          error: (error, _) => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: LacakErrorState(
                              title: 'Ringkasan pengawas belum dapat dimuat',
                              message:
                                  'Periksa koneksi internet Anda lalu muat ulang data pengawasan.',
                              onRetry: () =>
                                  ref.invalidate(supervisorOverviewProvider),
                            ),
                          ),
                          data: (overview) => _SupervisorOverviewBody(
                            overview: overview,
                            selectedRegion: selectedRegion,
                            horizontalPad: horizontalPad,
                            onSelectRegion: (region) => ref
                                .read(supervisorRegionFilterProvider.notifier)
                                .setRegion(region),
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

class _SupervisorOverviewBody extends StatelessWidget {
  const _SupervisorOverviewBody({
    required this.overview,
    required this.selectedRegion,
    required this.horizontalPad,
    required this.onSelectRegion,
  });

  final SupervisorNationalOverview overview;
  final String selectedRegion;
  final double horizontalPad;
  final ValueChanged<String> onSelectRegion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.availableRegions.length > 1) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: Text('Filter Wilayah', style: AppTypography.titleSection),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipStrip<String>(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            selectedValue: overview.regionFilter,
            onSelected: onSelectRegion,
            items: overview.availableRegions
                .map((region) => FilterChipItem<String>(value: region, label: region))
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ringkasan Nasional', style: AppTypography.titleSection),
              const SizedBox(height: 2),
              Text(
                'Cakupan: ${overview.totalSppgCount} Dapur SPPG · ${overview.totalApprovedSchoolsCount} Sekolah Mitra · ${overview.totalBatches} Total Batch',
                style: AppTypography.tabular(AppTypography.captionMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              _NationalMetricsTonalBlock(overview: overview),
              const SizedBox(height: AppSpacing.lg),
              if (overview.activeAlertsCount > 0) ...[
                _ActiveAlertsSection(
                  activeAlertsCount: overview.activeAlertsCount,
                  alerts: overview.activeAlerts,
                ),
                const SizedBox(height: AppSpacing.xl),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.safeBg,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSurface,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.safeFg,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tidak Ada Alarm Anomali Aktif',
                              style: AppTypography.titleItem.copyWith(
                                color: AppColors.safeFg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Seluruh distribusi pada wilayah dan rentang waktu terpilih belum memiliki laporan KLB aktif.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Kepatuhan & Sisa Pangan Per SPPG (${overview.sppgSummaries.length})',
                style: AppTypography.tabular(AppTypography.titleSection),
              ),
              const SizedBox(height: 2),
              Text(
                'Rincian status distribusi dan rata-rata sisa ompreng di masing-masing dapur mitra.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (overview.sppgSummaries.isEmpty)
                const LacakEmptyState(
                  icon: Icons.soup_kitchen_rounded,
                  title: 'Belum ada SPPG pada filter wilayah ini',
                  message:
                      'Pilih Semua Wilayah untuk melihat seluruh dapur SPPG terdaftar.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useTwoCols = constraints.maxWidth >= 740;
                    if (!useTwoCols) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0;
                              i < overview.sppgSummaries.length;
                              i++) ...[
                            _SppgSummaryRow(
                              summary: overview.sppgSummaries[i],
                            ),
                            if (i < overview.sppgSummaries.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      );
                    }
                    final colWidth =
                        (constraints.maxWidth - AppSpacing.xl) / 2;
                    return Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.md,
                      children: overview.sppgSummaries
                          .map(
                            (summary) => SizedBox(
                              width: colWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SppgSummaryRow(summary: summary),
                                  const Divider(height: 1),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Diperbarui: ${formatWibDateTime(overview.generatedAtUtc)}',
                style: AppTypography.tabular(AppTypography.captionLegal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NationalMetricsTonalBlock extends StatelessWidget {
  const _NationalMetricsTonalBlock({required this.overview});

  final SupervisorNationalOverview overview;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cells = [
      _MetricCell(
        label: 'Batch Aman',
        value: '${overview.safeBatches}',
        valueColor: AppColors.safeFg,
        caption: 'Tersegel & lolos',
      ),
      _MetricCell(
        label: 'Batch Bermasalah',
        value: '${overview.problemBatches}',
        valueColor: overview.problemBatches > 0
            ? AppColors.dangerFg
            : AppColors.textPrimary,
        caption: 'Butuh tindak lanjut',
      ),
      _MetricCell(
        label: 'Alarm Aktif',
        value: '${overview.activeAlertsCount}',
        valueColor: overview.activeAlertsCount > 0
            ? AppColors.dangerFg
            : AppColors.safeFg,
        caption: 'Laporan anomali/KLB',
      ),
      _MetricCell(
        label: 'Rata Sisa Makan',
        value: '${overview.avgWastePct}%',
        valueColor: overview.avgWastePct >= 40
            ? AppColors.warnFg
            : AppColors.textPrimary,
        caption: 'Rata-rata gabungan',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackAll = constraints.maxWidth < 300 || textScale >= 1.3;
          if (stackAll) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  cells[i],
                  if (i < cells.length - 1) const Divider(height: 1),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cells[0]),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.borderHairline,
                    ),
                    Expanded(child: cells[1]),
                  ],
                ),
              ),
              const Divider(height: 1),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cells[2]),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.borderHairline,
                    ),
                    Expanded(child: cells[3]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.caption,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.captionMuted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.tabular(
              AppTypography.displayStatus.copyWith(color: valueColor),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(caption, style: AppTypography.captionLegal),
        ],
      ),
    );
  }
}

class _ActiveAlertsSection extends StatelessWidget {
  const _ActiveAlertsSection({
    required this.activeAlertsCount,
    required this.alerts,
  });

  final int activeAlertsCount;
  final List<SupervisorAlertBrief> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LacakStatusBanner(
          level: LacakStatusLevel.danger,
          icon: Icons.notification_important_rounded,
          title: '$activeAlertsCount Alarm Anomali / KLB Aktif Terdeteksi',
          description:
              'Segera koordinasikan tindak lanjut Puskesmas dan hentikan sementara kloter dapur terkait.',
        ),
        for (var i = 0; i < alerts.length; i++) ...[
          _SupervisorAlertRow(alert: alerts[i]),
          if (i < alerts.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SupervisorAlertRow extends StatelessWidget {
  const _SupervisorAlertRow({required this.alert});

  final SupervisorAlertBrief alert;

  @override
  Widget build(BuildContext context) {
    final stageText = alert.stage == ClusterAlertStage.postConsumption
        ? 'Pasca-Konsumsi (${alert.symptomCount} siswa bergejala)'
        : 'Pra-Konsumsi (Tahan Distribusi)';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(alert.sppgName, style: AppTypography.titleItem),
              LacakStatusTag(
                level: LacakStatusLevel.danger,
                label: alert.stage == ClusterAlertStage.postConsumption
                    ? 'TAHAP 2 KLB'
                    : 'TAHAP 1 STOP',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${alert.menuName} (${alert.batchCode})',
            style: AppTypography.tabular(
              AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$stageText · ${formatWibDateTime(alert.createdAtUtc)}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _SppgSummaryRow extends StatelessWidget {
  const _SppgSummaryRow({required this.summary});

  final SupervisorSppgSummary summary;

  LacakStatusTag _statusTag() {
    if (summary.activeAlertsCount > 0 || summary.problemBatches > 0) {
      return LacakStatusTag(
        level: LacakStatusLevel.danger,
        label: summary.activeAlertsCount > 0 ? 'ALARM AKTIF' : 'BERMASALAH',
      );
    }
    if (summary.wasteLogCount > 0 && summary.avgOverallWastePct >= 40) {
      return const LacakStatusTag(
        level: LacakStatusLevel.warning,
        label: 'PERLU EVALUASI',
      );
    }
    return const LacakStatusTag(
      level: LacakStatusLevel.safe,
      label: 'AMAN',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(summary.sppgName, style: AppTypography.titleItem),
              _statusTag(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
                ),
                child: Text(
                  summary.inviteCode,
                  style: AppTypography.tabular(
                    AppTypography.captionLegal.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Text(
                '${summary.regionName} · ${summary.approvedSchoolCount} Sekolah',
                style: AppTypography.tabular(AppTypography.captionMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Batch Aman: ${summary.safeBatches} · Bermasalah: ${summary.problemBatches} · Alarm: ${summary.activeAlertsCount}',
            style: AppTypography.tabular(
              AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary.wasteLogCount == 0)
            Text(
              'Belum ada laporan sisa makanan pada rentang waktu ini.',
              style: AppTypography.bodyMedium,
            )
          else ...[
            Text(
              'Rata-rata sisa pangan (${summary.wasteLogCount} laporan · Gabungan ${summary.avgOverallWastePct}%)',
              style: AppTypography.tabular(AppTypography.captionMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SupervisorWasteBar(
              label: 'Nasi / Karbohidrat',
              percent: summary.avgCarbWastePct,
            ),
            const SizedBox(height: AppSpacing.xs),
            _SupervisorWasteBar(
              label: 'Lauk / Protein',
              percent: summary.avgProteinWastePct,
            ),
            const SizedBox(height: AppSpacing.xs),
            _SupervisorWasteBar(
              label: 'Sayuran',
              percent: summary.avgVegWastePct,
            ),
          ],
        ],
      ),
    );
  }
}

class _SupervisorWasteBar extends StatelessWidget {
  const _SupervisorWasteBar({required this.label, required this.percent});

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
            Expanded(child: Text(label, style: AppTypography.bodyMedium)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$percent%',
              style: AppTypography.tabular(
                AppTypography.bodyMedium.copyWith(
                  color: isHigh ? AppColors.warnFg : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent.clamp(0, 100)) / 100.0,
            minHeight: 8,
            backgroundColor: AppColors.surfaceSoft,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

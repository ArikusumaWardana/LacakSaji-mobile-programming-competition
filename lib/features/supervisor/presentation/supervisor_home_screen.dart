import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_logo.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/supervisor_models.dart';
import 'supervisor_providers.dart';

/// B01: Read-only BGN/Dinkes supervisor national and per-SPPG compliance screen.
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
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(
        title: Row(
          children: [
            const LacakLogoMark(size: 28),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Pemantauan Wilayah (Hanya Baca)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(supervisorOverviewProvider),
            tooltip: 'Muat Ulang Ringkasan',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Pengaturan & Keluar',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            icon: const Icon(Icons.person_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(supervisorOverviewProvider);
            await ref.read(supervisorOverviewProvider.future);
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
                    // Open editorial header on canvas (aligned with D01 & G01)
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          profile?.fullName.isNotEmpty == true
                              ? profile!.fullName
                              : 'Pengawas BGN Wilayah',
                          style: AppTypography.headlinePage.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const LacakStatusTag(
                          level: LacakStatusLevel.safe,
                          icon: Icons.visibility_rounded,
                          label: 'HANYA BACA',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pemantauan agregat keamanan distribusi dan evaluasi sisa pangan seluruh SPPG mitra.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: AppColors.safeFg,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Audit Lintas Wilayah · ${formatIndonesianDate(DateTime.now().toUtc())}',
                            style: AppTypography.tabular(
                              AppTypography.bodyMedium.copyWith(
                                color: AppColors.safeFg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Text('Rentang Waktu', style: AppTypography.titleSection),
                    const SizedBox(height: AppSpacing.sm),
                    LacakSegmentedControl<SupervisorDateFilter>(
                      selectedValue: dateFilter,
                      onChanged: (next) => ref
                          .read(supervisorDateFilterProvider.notifier)
                          .setFilter(next),
                      options: SupervisorDateFilter.values
                          .map(
                            (item) => LacakSegmentOption<SupervisorDateFilter>(
                              value: item,
                              label: item.label,
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    overviewAsync.when(
                      loading: () => const LacakSkeletonList(
                        itemCount: 3,
                        showHeaderBlock: true,
                        loadingLabel:
                            'Memuat ringkasan kepatuhan lintas SPPG...',
                      ),
                      error: (error, _) => LacakErrorState(
                        title: 'Ringkasan pengawas belum dapat dimuat',
                        message:
                            'Periksa koneksi internet Anda lalu muat ulang data pengawasan.',
                        onRetry: () =>
                            ref.invalidate(supervisorOverviewProvider),
                      ),
                      data: (overview) => _SupervisorOverviewBody(
                        overview: overview,
                        selectedRegion: selectedRegion,
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
    );
  }
}

class _SupervisorOverviewBody extends StatelessWidget {
  const _SupervisorOverviewBody({
    required this.overview,
    required this.selectedRegion,
    required this.onSelectRegion,
  });

  final SupervisorNationalOverview overview;
  final String selectedRegion;
  final ValueChanged<String> onSelectRegion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.availableRegions.length > 1) ...[
          Text('Filter Wilayah', style: AppTypography.titleSection),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: overview.availableRegions
                .map(
                  (region) => _RegionFilterChip(
                    label: region,
                    selected: region == overview.regionFilter,
                    onTap: () => onSelectRegion(region),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        // National summary section using flat tonal block (no white card border, matching D01 & G01)
        Text('Ringkasan Nasional', style: AppTypography.titleSection),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cakupan: ${overview.totalSppgCount} Dapur SPPG · ${overview.totalApprovedSchoolsCount} Sekolah Mitra · ${overview.totalBatches} Total Batch',
          style: AppTypography.tabular(AppTypography.bodyMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.safeBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
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
        const SizedBox(height: AppSpacing.xs),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < overview.sppgSummaries.length; i++) ...[
                _SppgSummaryRow(summary: overview.sppgSummaries[i]),
                if (i < overview.sppgSummaries.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderHairline,
                  ),
              ],
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Diperbarui: ${formatWibDateTime(overview.generatedAtUtc)}',
          style: AppTypography.tabular(AppTypography.captionLegal),
        ),
      ],
    );
  }
}

class _RegionFilterChip extends StatelessWidget {
  const _RegionFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTypography.labelTag.copyWith(
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NationalMetricsTonalBlock extends StatelessWidget {
  const _NationalMetricsTonalBlock({required this.overview});

  final SupervisorNationalOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCell(
                    label: 'Batch Aman',
                    value: '${overview.safeBatches}',
                    valueColor: AppColors.safeFg,
                    caption: 'Tersegel & lolos',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.borderHairline,
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Batch Bermasalah',
                    value: '${overview.problemBatches}',
                    valueColor: overview.problemBatches > 0
                        ? AppColors.dangerFg
                        : AppColors.textPrimary,
                    caption: 'Butuh tindak lanjut',
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderHairline,
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCell(
                    label: 'Alarm Aktif',
                    value: '${overview.activeAlertsCount}',
                    valueColor: overview.activeAlertsCount > 0
                        ? AppColors.dangerFg
                        : AppColors.safeFg,
                    caption: 'Laporan anomali/KLB',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.borderHairline,
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Rata Sisa Makan',
                    value: '${overview.avgWastePct}%',
                    valueColor: overview.avgWastePct >= 40
                        ? AppColors.warnFg
                        : AppColors.textPrimary,
                    caption: 'Rata-rata gabungan',
                  ),
                ),
              ],
            ),
          ),
        ],
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
          Text(label, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.tabular(
              AppTypography.displayStatus.copyWith(color: valueColor),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            style: AppTypography.captionLegal.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
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
          if (i < alerts.length - 1)
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderHairline,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
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
          const SizedBox(height: AppSpacing.xs),
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
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
                  border: Border.all(
                    color: AppColors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Text(
                  summary.inviteCode,
                  style: AppTypography.tabular(
                    AppTypography.labelTag.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Text(
                '${summary.regionName} · ${summary.approvedSchoolCount} Sekolah',
                style: AppTypography.tabular(AppTypography.bodyMedium),
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
              style: AppTypography.tabular(AppTypography.labelTag),
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
            backgroundColor: AppColors.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

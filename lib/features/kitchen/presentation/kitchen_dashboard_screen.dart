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
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

/// D01: SPPG Kitchen main dashboard with direct operational actions.
class KitchenDashboardScreen extends ConsumerWidget {
  const KitchenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final kitchen = authState.kitchen;
    final dashboardAsync = ref.watch(kitchenDashboardProvider);
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
            const Expanded(child: Text('Beranda Dapur SPPG')),
          ],
        ),
      ),
      body: SafeArea(
        child: kitchen == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LacakErrorState(
                  message:
                      'Profil dapur SPPG belum dimuat. Coba perbarui status akun di menu Profil.',
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(kitchenDashboardProvider);
                  await ref.read(kitchenDashboardProvider.future);
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
                          // Open editorial header on canvas (no extra card wrapper)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                kitchen.name,
                                style: AppTypography.headlinePage.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const LacakStatusTag(
                                level: LacakStatusLevel.safe,
                                label: 'TERVERIFIKASI',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Kode Mitra:',
                                style: AppTypography.bodyMedium,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusTag,
                                  ),
                                  border: Border.all(
                                    color: AppColors.borderHairline,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  kitchen.inviteCode,
                                  style: AppTypography.tabular(
                                    AppTypography.labelTag.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '· ${formatIndonesianDate(DateTime.now().toUtc())}',
                                style: AppTypography.tabular(
                                  AppTypography.bodyMedium,
                                ),
                              ),
                            ],
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
                                  'Segel Digital Asli Aktif',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.safeFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          dashboardAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 3,
                              showHeaderBlock: true,
                              showHeroActionBlock: true,
                              loadingLabel: 'Memuat ringkasan batch hari ini...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(kitchenDashboardProvider),
                            ),
                            data: (data) => _DashboardContent(data: data),
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

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});

  final KitchenDashboardData data;

  @override
  Widget build(BuildContext context) {
    final todayBatches = data.todayBatches;
    final previewBatches = todayBatches.take(3).toList(growable: false);
    final summary = data.weeklyWasteSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.activeAlertsToday.isNotEmpty) ...[
          LacakStatusBanner(
            level: LacakStatusLevel.danger,
            title:
                'PERINGATAN DARURAT: ${data.activeAlertsToday.length} Laporan Anomali Hari Ini',
            description:
                '${data.activeAlertsToday.first.reporterSchoolName} melaporkan anomali pada batch ${data.activeAlertsToday.first.batchCode} (${data.activeAlertsToday.first.menuName}). Segera koordinasikan penahanan distribusi.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (data.pendingSchoolsCount > 0) ...[
          LacakStatusBanner(
            level: LacakStatusLevel.warning,
            title:
                '${data.pendingSchoolsCount} Sekolah Menunggu Persetujuan',
            description:
                'Tinjau permintaan bergabung agar sekolah binaan dapat memindai QR segel harian.',
            action: LacakSecondaryButton(
              label: 'Tinjau Permintaan Sekolah',
              icon: Icons.school_rounded,
              onPressed: () => context.go(AppRoutes.kitchenSchools),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LacakPrimaryButton(
          label: 'Buat QR Segel Batch Baru',
          icon: Icons.qr_code_2_rounded,
          minHeight: AppSpacing.heroCtaMinHeight,
          onPressed: () => context.push(AppRoutes.kitchenCreateBatch),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Flat tonal 2-column metric bar (inspired by reference 2 metric strip, without white card border)
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricHalf(
                    label: 'Batch Hari Ini',
                    value: '${todayBatches.length}',
                    caption: 'Segel diterbitkan',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.borderHairline,
                ),
                Expanded(
                  child: _MetricHalf(
                    label: 'Sekolah Terima',
                    value:
                        '${data.todayReceivedSchoolsCount} / ${data.approvedSchoolsCount}',
                    caption: 'Sekolah binaan aktif',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text('Batch Hari Ini', style: AppTypography.titleSection),
            TextButton(
              onPressed: () => context.go(AppRoutes.kitchenHistory),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Lihat Semua Riwayat'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (previewBatches.isEmpty)
          LacakEmptyState(
            icon: Icons.qr_code_2_rounded,
            title: 'Belum ada batch hari ini',
            message:
                'Buat QR Segel batch baru saat makanan selesai dikemas sebelum dikirim ke sekolah binaan.',
            actionLabel: 'Buat Batch Pertama',
            onAction: () => context.push(AppRoutes.kitchenCreateBatch),
          )
        else
          LacakSectionSurface.separated(
            children: previewBatches
                .map(
                  (batch) => _BatchRowTile(
                    batch: batch,
                    approvedSchoolsCount: data.approvedSchoolsCount,
                    onTap: () => context.push(
                      AppRoutes.batchDetailPath(batch.id),
                      extra: batch,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Evaluasi Sisa Makanan (7 Hari)',
          style: AppTypography.titleSection,
        ),
        const SizedBox(height: AppSpacing.sm),
        LacakSectionSurface(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: () => context.go(AppRoutes.kitchenHistory),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.sampleCount == 0
                              ? 'Belum ada laporan sisa makanan minggu ini'
                              : 'Nasi ${summary.avgCarbPct}% · Lauk ${summary.avgProteinPct}% · Sayur ${summary.avgVegPct}%',
                          style: AppTypography.tabular(AppTypography.titleItem),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          summary.sampleCount == 0
                              ? 'Ketuk untuk melihat riwayat batch dan sisa makanan.'
                              : (summary.hasHighWasteAlert
                                    ? 'Ada komponen >= 40%. Ketuk untuk tinjau saran menu.'
                                    : 'Berdasarkan ${summary.sampleCount} laporan ompreng sekolah.'),
                          style: AppTypography.bodyMedium.copyWith(
                            color: summary.hasHighWasteAlert
                                ? AppColors.warnFg
                                : AppColors.textSecondary,
                          ),
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
          ),
        ),
      ],
    );
  }
}

class _MetricHalf extends StatelessWidget {
  const _MetricHalf({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
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
            style: AppTypography.tabular(AppTypography.displayStatus),
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

class _BatchRowTile extends StatelessWidget {
  const _BatchRowTile({
    required this.batch,
    required this.approvedSchoolsCount,
    required this.onTap,
  });

  final FoodBatchItem batch;
  final int approvedSchoolsCount;
  final VoidCallback onTap;

  LacakStatusTag _buildStatusTag() {
    if (batch.hasAnomalyReport) {
      return const LacakStatusTag(
        level: LacakStatusLevel.danger,
        label: 'Laporan Anomali',
      );
    }
    if (batch.isPendingSync) {
      return const LacakStatusTag(
        level: LacakStatusLevel.offline,
        label: 'Belum Terkirim',
      );
    }
    if (batch.inspectedSchoolIds.isNotEmpty) {
      return const LacakStatusTag(
        level: LacakStatusLevel.safe,
        label: 'Sudah Dipindai',
      );
    }
    return const LacakStatusTag(
      level: LacakStatusLevel.safe,
      label: 'Siap Kirim',
      icon: Icons.qr_code_2_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
                Text(batch.menuName, style: AppTypography.titleItem),
                _buildStatusTag(),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${batch.batchCode} · ${formatWibTime(batch.sealedAtUtc)} · ${batch.riskCategory.label}',
              style: AppTypography.tabular(AppTypography.bodyMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${batch.inspectedSchoolIds.length} dari $approvedSchoolsCount sekolah terima · ${batch.portionCount} porsi',
              style: AppTypography.tabular(
                AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

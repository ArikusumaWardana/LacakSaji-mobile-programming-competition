import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_logo.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G01: School PIC Dashboard displaying BMKG weather, QR Scan CTA, Bank Sampel summary, and today's batches.
class SchoolDashboardScreen extends ConsumerWidget {
  const SchoolDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(authControllerProvider).school;
    final dashboardAsync = ref.watch(schoolDashboardProvider);
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
            const Expanded(child: Text('Beranda Sekolah')),
          ],
        ),
      ),
      body: SafeArea(
        child: school == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LacakErrorState(
                  message:
                      'Profil sekolah belum termuat. Coba perbarui status akun di menu Profil.',
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(schoolDashboardProvider);
                  await ref.read(schoolDashboardProvider.future);
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
                                school.name,
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
                                'Mitra: ${school.partnerKitchenName ?? 'Dapur SPPG'}',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if ((school.partnerInviteCode ?? '').isNotEmpty)
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
                                    school.partnerInviteCode!,
                                    style: AppTypography.tabular(
                                      AppTypography.labelTag.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'NPSN ${school.npsn} · ${formatIndonesianDate(DateTime.now().toUtc())}',
                            style: AppTypography.tabular(
                              AppTypography.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          dashboardAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 3,
                              showHeaderBlock: true,
                              showHeroActionBlock: true,
                              loadingLabel:
                                  'Memuat suhu BMKG dan ringkasan penerimaan...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(schoolDashboardProvider),
                            ),
                            data: (data) => _DashboardBody(data: data),
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final SchoolDashboardData data;

  @override
  Widget build(BuildContext context) {
    final weather = data.weather;
    final nearestExpiry = data.nearestSampleExpiryUtc;
    final remainingText = nearestExpiry == null
        ? 'Belum ada sampel tersimpan di kulkas.'
        : _formatRemainingVault(nearestExpiry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact flat weather & offline key strip (no bulky card wrapper)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.thermostat_rounded,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          weather.formattedTemperature,
                          style: AppTypography.tabular(
                            AppTypography.headlinePage,
                          ),
                        ),
                        Text(
                          weather.isHot ? 'Cuaca Panas' : 'Suhu Normal',
                          style: AppTypography.titleItem.copyWith(
                            color: weather.isHot
                                ? AppColors.warnFg
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '· ${resolveAdm4VillageName(data.school.adm4Code)} · ${weather.source.label}',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppConstants.bmkgShortAttribution,
                style: AppTypography.captionLegal,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    data.partnerKeyCached
                        ? Icons.verified_user_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: data.partnerKeyCached
                        ? AppColors.safeFg
                        : AppColors.warnFg,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      data.partnerKeyCached
                          ? 'Koneksi SPPG Aktif: Siap verifikasi QR 100% offline.'
                          : 'Kunci verifikasi SPPG belum tersimpan lokal. Hubungkan internet sekali di menu Profil.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: data.partnerKeyCached
                            ? AppColors.safeFg
                            : AppColors.warnFg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LacakPrimaryButton(
          label: 'Pindai QR Makanan Masuk',
          icon: Icons.qr_code_scanner_rounded,
          minHeight: AppSpacing.heroCtaMinHeight,
          onPressed: () => context.push(AppRoutes.schoolScanQr),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Aksi Operasional Sekolah', style: AppTypography.titleSection),
        const SizedBox(height: AppSpacing.sm),
        LacakSectionSurface.separated(
          children: [
            _QuickActionTile(
              icon: Icons.kitchen_rounded,
              title: 'Bank Sampel 48 Jam (${data.activeSampleCount} aktif)',
              subtitle: remainingText,
              onTap: () => context.go(AppRoutes.schoolSamples),
            ),
            _QuickActionTile(
              icon: Icons.restaurant_rounded,
              title: 'Catat Sisa Makanan Siswa',
              subtitle: 'Foto 3-5 ompreng bekas makan untuk evaluasi Dapur SPPG.',
              onTap: () => context.go(AppRoutes.schoolPlateWaste),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Penerimaan Hari Ini (${data.todayInspections.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.todayInspections.isEmpty)
          LacakEmptyState(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Belum ada penerimaan makanan hari ini',
            message:
                'Pindai Kode QR pada HP kurir atau label wadah kiriman SPPG saat makanan tiba di sekolah.',
            actionLabel: 'Pindai QR Sekarang',
            onAction: () => context.push(AppRoutes.schoolScanQr),
          )
        else
          LacakSectionSurface.separated(
            children: data.todayInspections
                .map(
                  (item) => _InspectionRowTile(
                    item: item,
                    onTap: () => _showInspectionDetailSheet(
                      context,
                      school: data.school,
                      item: item,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  void _showInspectionDetailSheet(
    BuildContext context, {
    required SchoolProfile school,
    required SchoolInspectionItem item,
  }) {
    final sppgName = school.partnerKitchenName ?? 'Dapur SPPG Mitra';
    final sealedAtUtc = item.effectiveSealedAtUtc;
    final parentRouter = GoRouter.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSurface),
        ),
        side: BorderSide(color: AppColors.borderHairline, width: 1),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.menuName, style: AppTypography.headlinePage),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Batch ${item.batchCode} · $sppgName',
                  style: AppTypography.tabular(AppTypography.bodyMedium),
                ),
                const SizedBox(height: AppSpacing.md),
                LacakSectionSurface.separated(
                  children: [
                    _DetailSheetRow(
                      label: 'Jam Segel Dapur',
                      value: formatWibDateTime(sealedAtUtc),
                    ),
                    _DetailSheetRow(
                      label: 'Jam Terima Sekolah',
                      value: formatWibDateTime(item.scannedAtUtc),
                    ),
                    _DetailSheetRow(
                      label: 'Durasi & Suhu',
                      value:
                          '${formatDurationMinutes(item.elapsedMinutes)} · ${item.bmkgTempC.toStringAsFixed(1)} C',
                    ),
                    _DetailSheetRow(
                      label: 'Keputusan Inspeksi',
                      value: item.finalDecision == 'REJECTED'
                          ? 'Dihentikan / Ditolak'
                          : 'Lolos Diterima',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                LacakDangerButton(
                  label: 'Laporkan Anomali / Siswa Bergejala',
                  icon: Icons.notification_important_rounded,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    parentRouter.push(
                      AppRoutes.schoolReportAlert,
                      extra: AnomalyHandoffArgs(
                        batchId: item.batchId,
                        batchCode: item.batchCode,
                        menuName: item.menuName,
                        sppgId: school.sppgId,
                        sppgName: sppgName,
                        sealedAtUtc: sealedAtUtc,
                        scannedAtUtc: item.scannedAtUtc,
                        elapsedMinutes: item.elapsedMinutes,
                        bmkgTempC: item.bmkgTempC,
                        bmkgSource: item.bmkgSource,
                        dangerStatus: item.dangerStatus,
                        localPhotoPath: item.localPhotoPath,
                        sampleLabelCode: item.sampleLabelCode,
                        inspectionId: item.id,
                        reasonSummary:
                            'Pelaporan pasca-penerimaan untuk batch ${item.batchCode} (${item.menuName}).',
                        initialStage: ClusterAlertStage.postConsumption,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                LacakSecondaryButton(
                  label: 'Tutup',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRemainingVault(DateTime expiresAtUtc) {
    final diff = expiresAtUtc.toUtc().difference(DateTime.now().toUtc());
    if (diff <= Duration.zero) {
      return 'Ada sampel mencapai batas 48 jam dan siap dimusnahkan.';
    }
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return 'Pengingat terdekat tersisa $hours jam $mins menit.';
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.tabular(AppTypography.titleItem),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
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

class _InspectionRowTile extends StatelessWidget {
  const _InspectionRowTile({required this.item, required this.onTap});

  final SchoolInspectionItem item;
  final VoidCallback onTap;

  LacakStatusTag _buildTag() {
    if (item.finalDecision == 'REJECTED' ||
        item.dangerStatus == DangerZoneStatus.red) {
      return const LacakStatusTag(
        level: LacakStatusLevel.danger,
        label: 'Ditolak / Stop',
      );
    }
    if (item.isPendingSync) {
      return const LacakStatusTag(
        level: LacakStatusLevel.offline,
        label: 'Belum Terkirim',
      );
    }
    if (item.dangerStatus == DangerZoneStatus.yellow) {
      return const LacakStatusTag(
        level: LacakStatusLevel.warning,
        label: 'Periksa Ketat',
      );
    }
    return const LacakStatusTag(
      level: LacakStatusLevel.safe,
      label: 'Aman Dibagikan',
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
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.menuName, style: AppTypography.titleItem),
                      _buildTag(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${item.batchCode} · ${formatWibTime(item.scannedAtUtc)} · ${formatDurationMinutes(item.elapsedMinutes)} · ${item.bmkgTempC.toStringAsFixed(1)} C',
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

class _DetailSheetRow extends StatelessWidget {
  const _DetailSheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTypography.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.tabular(AppTypography.titleItem),
            ),
          ),
        ],
      ),
    );
  }
}

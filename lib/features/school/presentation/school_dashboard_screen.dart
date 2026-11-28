import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';
import 'widgets/parent_summary_share_sheet.dart';

enum _SchoolDashFilter {
  today,
  samples,
  plateWaste,
  history,
}

/// G01: Editorial School PIC Dashboard with MinimalTopHeader, Search + Scan QR button,
/// filter chips, FeaturedVisualCard batch carousel, and borderless Bank Sampel 48h list.
class SchoolDashboardScreen extends ConsumerStatefulWidget {
  const SchoolDashboardScreen({super.key});

  @override
  ConsumerState<SchoolDashboardScreen> createState() =>
      _SchoolDashboardScreenState();
}

class _SchoolDashboardScreenState extends ConsumerState<SchoolDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SchoolDashFilter _filter = _SchoolDashFilter.today;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNotificationsSheet({
    required SchoolDashboardData? dashData,
    required List<SampleVaultItem> activeSamples,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final readySamples = activeSamples
        .where((s) => s.isReadyToDispose(nowUtc))
        .toList(growable: false);
    final issueInspections = (dashData?.todayInspections ?? const [])
        .where(
          (i) =>
              i.finalDecision == 'REJECTED' ||
              i.dangerStatus == DangerZoneStatus.red,
        )
        .toList(growable: false);
    final missingKey = dashData != null && !dashData.partnerKeyCached;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCanvas,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusHero),
        ),
      ),
      builder: (sheetContext) {
        final hasAny =
            missingKey || readySamples.isNotEmpty || issueInspections.isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pemberitahuan Sekolah',
                        style: AppTypography.titleSection,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      tooltip: 'Tutup',
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!hasAny)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'Tidak ada peringatan tertunda. Verifikasi QR offline dan Bank Sampel 48 jam dalam kondisi aman.',
                      style: AppTypography.bodyMedium,
                    ),
                  )
                else ...[
                  if (missingKey) ...[
                    Text(
                      'Kunci verifikasi SPPG belum tersimpan lokal. Hubungkan internet sekali di menu Profil.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.warnFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (readySamples.isNotEmpty) ...[
                    Text(
                      '${readySamples.length} sampel di kulkas telah melewati 48 jam dan siap ditandai selesai.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.warnFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LacakSecondaryButton(
                      label: 'Buka Bank Sampel',
                      icon: Icons.kitchen_rounded,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.go(AppRoutes.schoolSamples);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (issueInspections.isNotEmpty)
                    Text(
                      '${issueInspections.length} batch hari ini ditahan atau ditolak pada inspeksi.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.dangerFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<SchoolInspectionItem> _filterInspections(
    List<SchoolInspectionItem> items,
  ) {
    if (_searchQuery.isEmpty) {
      return items;
    }
    return items.where((item) {
      return item.menuName.toLowerCase().contains(_searchQuery) ||
          item.batchCode.toLowerCase().contains(_searchQuery);
    }).toList(growable: false);
  }

  List<SampleVaultItem> _filterSamples(List<SampleVaultItem> items) {
    if (_searchQuery.isEmpty) {
      return items;
    }
    return items.where((item) {
      return item.labelCode.toLowerCase().contains(_searchQuery) ||
          item.menuName.toLowerCase().contains(_searchQuery);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(authControllerProvider).school;
    final dashboardAsync = ref.watch(schoolDashboardProvider);
    final activeSamplesAsync = ref.watch(activeSampleVaultsProvider);
    final historySamplesAsync = ref.watch(historySampleVaultsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = width >= 900 ? 960.0 : AppSpacing.maxContentWidth(width);

    if (school == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(
              message:
                  'Profil sekolah belum dimuat. Coba perbarui status akun di menu Profil.',
            ),
          ),
        ),
      );
    }

    final dashData = dashboardAsync.value;
    final activeSamples = activeSamplesAsync.value ?? const <SampleVaultItem>[];
    final allSamples = <SampleVaultItem>[
      ...activeSamples,
      ...(historySamplesAsync.value ?? const <SampleVaultItem>[]),
    ];
    final nowUtc = DateTime.now().toUtc();
    final hasAlert = (dashData != null && !dashData.partnerKeyCached) ||
        activeSamples.any((s) => s.isReadyToDispose(nowUtc)) ||
        (dashData?.todayInspections.any(
              (i) =>
                  i.finalDecision == 'REJECTED' ||
                  i.dangerStatus == DangerZoneStatus.red,
            ) ??
            false);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          MinimalTopHeader(
            contextLabel: 'Sekolah Binaan · NPSN ${school.npsn}',
            title: school.name,
            hasUnreadAlert: hasAlert,
            onNotificationTap: () => _showNotificationsSheet(
              dashData: dashData,
              activeSamples: activeSamples,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(schoolDashboardProvider);
                await ref.read(schoolDashboardProvider.future);
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
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            AppSpacing.sm,
                            horizontalPad,
                            AppSpacing.md,
                          ),
                          child: SearchAndActionBar(
                            controller: _searchController,
                            hintText: 'Cari menu, batch, atau kode sampel...',
                            onChanged: (value) => setState(
                              () => _searchQuery = value.trim().toLowerCase(),
                            ),
                            actionIcon: Icons.qr_code_scanner_rounded,
                            actionTooltip: 'Pindai QR Makanan',
                            onActionTap: () =>
                                context.push(AppRoutes.schoolScanQr),
                          ),
                        ),
                        FilterChipStrip<_SchoolDashFilter>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: _filter,
                          onSelected: (next) {
                            setState(() => _filter = next);
                          },
                          items: const [
                            FilterChipItem(
                              value: _SchoolDashFilter.today,
                              label: 'Hari Ini',
                            ),
                            FilterChipItem(
                              value: _SchoolDashFilter.samples,
                              label: 'Bank Sampel',
                            ),
                            FilterChipItem(
                              value: _SchoolDashFilter.plateWaste,
                              label: 'Sisa Makan',
                            ),
                            FilterChipItem(
                              value: _SchoolDashFilter.history,
                              label: 'Riwayat',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        dashboardAsync.when(
                          loading: () => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: const LacakSkeletonList(
                              itemCount: 3,
                              showHeaderBlock: true,
                              showHeroActionBlock: true,
                              loadingLabel:
                                  'Memuat suhu BMKG dan ringkasan penerimaan...',
                            ),
                          ),
                          error: (error, _) => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(schoolDashboardProvider),
                            ),
                          ),
                          data: (data) => _SchoolDashboardBody(
                            data: data,
                            filter: _filter,
                            filteredInspections: _filterInspections(
                              data.todayInspections,
                            ),
                            filteredSamples: _filterSamples(activeSamples),
                            horizontalPad: horizontalPad,
                            hasQuery: _searchQuery.isNotEmpty,
                            onInspectTap: (item) => _showInspectionDetailSheet(
                              context,
                              school: data.school,
                              item: item,
                              allSamples: allSamples,
                            ),
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

  void _showInspectionDetailSheet(
    BuildContext context, {
    required SchoolProfile school,
    required SchoolInspectionItem item,
    required List<SampleVaultItem> allSamples,
  }) {
    final sppgName = school.partnerKitchenName ?? 'Dapur SPPG Mitra';
    final sealedAtUtc = item.effectiveSealedAtUtc;
    final parentRouter = GoRouter.of(context);
    final matchedSample = allSamples
        .where((s) => s.inspectionId == item.id)
        .cast<SampleVaultItem?>()
        .firstWhere((s) => s != null, orElse: () => null);
    final effectiveSampleLabel =
        (item.sampleLabelCode != null && item.sampleLabelCode!.isNotEmpty)
            ? item.sampleLabelCode
            : matchedSample?.labelCode;
    final canShareParentSummary =
        item.finalDecision == 'APPROVED' &&
        item.dangerStatus != DangerZoneStatus.red &&
        effectiveSampleLabel != null &&
        effectiveSampleLabel.isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusHero),
        ),
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
                  style: AppTypography.tabular(AppTypography.captionMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1),
                _DetailSheetRow(
                  label: 'Jam Segel Dapur',
                  value: formatWibDateTime(sealedAtUtc),
                ),
                const Divider(height: 1),
                _DetailSheetRow(
                  label: 'Jam Terima Sekolah',
                  value: formatWibDateTime(item.scannedAtUtc),
                ),
                const Divider(height: 1),
                _DetailSheetRow(
                  label: 'Durasi & Suhu',
                  value:
                      '${formatDurationMinutes(item.elapsedMinutes)} · ${item.bmkgTempC.toStringAsFixed(1)} C',
                ),
                const Divider(height: 1),
                _DetailSheetRow(
                  label: 'Keputusan Inspeksi',
                  value: item.finalDecision == 'REJECTED'
                      ? 'Dihentikan / Ditolak'
                      : 'Lolos Diterima',
                ),
                const Divider(height: 1),
                if (effectiveSampleLabel != null &&
                    effectiveSampleLabel.isNotEmpty) ...[
                  _DetailSheetRow(
                    label: 'Label Bank Sampel',
                    value: effectiveSampleLabel,
                  ),
                  const Divider(height: 1),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (canShareParentSummary) ...[
                  LacakPrimaryButton(
                    label: 'Bagikan Ringkasan ke Wali Murid',
                    icon: Icons.share_rounded,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.tabletFormMaxWidth,
                        ),
                        backgroundColor: AppColors.bgCanvas,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusHero),
                          ),
                        ),
                        builder: (_) => ParentSummaryShareSheet(
                          schoolName: school.name,
                          dateUtc: item.scannedAtUtc,
                          menuName: item.menuName,
                          batchCode: item.batchCode,
                          cookedAtUtc: sealedAtUtc,
                          arrivedAtUtc: item.scannedAtUtc,
                          sampleLabelCode: effectiveSampleLabel,
                          allergenTags: item.allergenTags,
                          localPhotoPath: item.localPhotoPath,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
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
}

class _SchoolDashboardBody extends StatelessWidget {
  const _SchoolDashboardBody({
    required this.data,
    required this.filter,
    required this.filteredInspections,
    required this.filteredSamples,
    required this.horizontalPad,
    required this.hasQuery,
    required this.onInspectTap,
  });

  final SchoolDashboardData data;
  final _SchoolDashFilter filter;
  final List<SchoolInspectionItem> filteredInspections;
  final List<SampleVaultItem> filteredSamples;
  final double horizontalPad;
  final bool hasQuery;
  final ValueChanged<SchoolInspectionItem> onInspectTap;

  @override
  Widget build(BuildContext context) {
    final weather = data.weather;

    final batchCarouselSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filter == _SchoolDashFilter.history
                      ? 'Riwayat Penerimaan Hari Ini'
                      : 'Batch Penerimaan Hari Ini',
                  style: AppTypography.titleSection,
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.schoolScanQr),
                child: const Text('Pindai QR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filteredInspections.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: LacakEmptyState(
              icon: Icons.qr_code_scanner_rounded,
              title: hasQuery
                  ? 'Tidak ada batch yang cocok'
                  : 'Belum ada penerimaan makanan hari ini',
              message: hasQuery
                  ? 'Ubah kata kunci pencarian Anda.'
                  : 'Pindai Kode QR pada HP kurir atau wadah kiriman SPPG saat makanan tiba.',
              actionLabel: 'Pindai QR Masuk',
              onAction: () => context.push(AppRoutes.schoolScanQr),
            ),
          )
        else
          SizedBox(
            height: 256,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              itemCount: filteredInspections.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = filteredInspections[index];
                return _InspectionCarouselCard(
                  item: item,
                  onTap: () => onInspectTap(item),
                );
              },
            ),
          ),
      ],
    );

    final samplesSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Aktivitas & Bank Sampel 48 Jam',
                  style: AppTypography.titleSection,
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.schoolSamples),
                child: const Text('Lihat semua'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: filteredSamples.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BorderlessThumbTile(
                      fallbackIcon: Icons.kitchen_rounded,
                      title: data.activeSampleCount > 0
                          ? '${data.activeSampleCount} Sampel Aktif di Kulkas'
                          : 'Belum Ada Sampel di Kulkas',
                      statusText: data.nearestSampleExpiryUtc != null
                          ? 'Sisa waktu terdekat tersimpan aman'
                          : 'Simpan 1 porsi sampel setelah inspeksi',
                      metadata: [
                        BorderlessMetaItem(
                          icon: Icons.schedule_rounded,
                          label: 'Retensi wajib 48 jam (< 5 C)',
                        ),
                      ],
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () => context.go(AppRoutes.schoolSamples),
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final visible = filteredSamples.take(6).toList(
                      growable: false,
                    );
                    final useTwoCols = constraints.maxWidth >= 680;
                    if (!useTwoCols) {
                      return Column(
                        children: [
                          for (var i = 0; i < visible.length; i++)
                            _SampleVaultBorderlessTile(
                              item: visible[i],
                              showDivider: i < visible.length - 1,
                              onTap: () => context.go(AppRoutes.schoolSamples),
                            ),
                        ],
                      );
                    }
                    final colWidth =
                        (constraints.maxWidth - AppSpacing.xl) / 2;
                    return Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.xs,
                      children: visible
                          .map(
                            (sample) => SizedBox(
                              width: colWidth,
                              child: _SampleVaultBorderlessTile(
                                item: sample,
                                showDivider: true,
                                onTap: () => context.go(AppRoutes.schoolSamples),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
        ),
      ],
    );

    final plateWasteActionStrip = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          BorderlessThumbTile(
            fallbackIcon: Icons.restaurant_rounded,
            title: 'Catat Sisa Makanan Siswa',
            statusText: 'Kirim evaluasi 3-5 ompreng ke Dapur SPPG',
            metadata: const [
              BorderlessMetaItem(
                icon: Icons.photo_camera_rounded,
                label: 'Kamera langsung + estimasi otomatis',
              ),
            ],
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onTap: () => context.go(AppRoutes.schoolPlateWaste),
          ),
          const Divider(height: 1),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.thermostat_rounded,
                      size: 22,
                      color: weather.isHot
                          ? AppColors.warnFg
                          : AppColors.primary,
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
                            '· ${resolveAdm4VillageName(data.school.adm4Code)}',
                            style: AppTypography.captionMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${weather.source.label} · ${AppConstants.bmkgShortAttribution}',
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
                            ? 'Koneksi SPPG Aktif: Verifikasi QR 100% siap offline.'
                            : 'Kunci verifikasi SPPG belum tersimpan lokal.',
                        style: AppTypography.captionMuted.copyWith(
                          color: data.partnerKeyCached
                              ? AppColors.safeFg
                              : AppColors.warnFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (filter == _SchoolDashFilter.samples) ...[
          samplesSection,
          const SizedBox(height: AppSpacing.xxl),
          batchCarouselSection,
        ] else if (filter == _SchoolDashFilter.plateWaste) ...[
          plateWasteActionStrip,
          const SizedBox(height: AppSpacing.xl),
          batchCarouselSection,
          const SizedBox(height: AppSpacing.xxl),
          samplesSection,
        ] else ...[
          batchCarouselSection,
          const SizedBox(height: AppSpacing.xxl),
          samplesSection,
          const SizedBox(height: AppSpacing.xl),
          plateWasteActionStrip,
        ],
      ],
    );
  }
}

class _InspectionCarouselCard extends StatelessWidget {
  const _InspectionCarouselCard({
    required this.item,
    required this.onTap,
  });

  final SchoolInspectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String statusLabel;
    final Color placeholderBg;
    final Color placeholderFg;
    final IconData placeholderIcon;

    if (item.finalDecision == 'REJECTED' ||
        item.dangerStatus == DangerZoneStatus.red) {
      statusLabel = 'Stop - Ditolak';
      placeholderBg = AppColors.dangerBg;
      placeholderFg = AppColors.dangerFg;
      placeholderIcon = Icons.dangerous_rounded;
    } else if (item.dangerStatus == DangerZoneStatus.yellow) {
      statusLabel = 'Periksa Ketat';
      placeholderBg = AppColors.warnBg;
      placeholderFg = AppColors.warnFg;
      placeholderIcon = Icons.warning_amber_rounded;
    } else {
      statusLabel = 'Aman Dibagikan';
      placeholderBg = AppColors.primaryTint;
      placeholderFg = AppColors.primary;
      placeholderIcon = Icons.verified_user_rounded;
    }

    ImageProvider? localImage;
    final path = item.localPhotoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      localImage = FileImage(File(path));
    }

    return FeaturedVisualCard(
      width: 232,
      height: 256,
      image: localImage,
      imagePlaceholder: Container(
        color: placeholderBg,
        alignment: Alignment.center,
        padding: const EdgeInsets.only(bottom: 42),
        child: Icon(placeholderIcon, size: 46, color: placeholderFg),
      ),
      badgeLabel:
          '${item.bmkgTempC.toStringAsFixed(0)} C · ${formatDurationMinutes(item.elapsedMinutes)}',
      badgeIcon: Icons.thermostat_rounded,
      title: item.menuName,
      subtitle: '$statusLabel · ${item.batchCode}',
      onTap: onTap,
    );
  }
}

class _SampleVaultBorderlessTile extends StatelessWidget {
  const _SampleVaultBorderlessTile({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final SampleVaultItem item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final remaining = item.remainingFrom(nowUtc);
    final ready = item.isReadyToDispose(nowUtc);

    return BorderlessThumbTile(
      fallbackIcon: Icons.kitchen_rounded,
      fallbackBgColor: ready ? AppColors.warnBg : AppColors.safeBg,
      fallbackIconColor: ready ? AppColors.warnFg : AppColors.safeFg,
      title: item.labelCode,
      statusText: ready
          ? '48 Jam Selesai - Siap Dimusnahkan'
          : 'Sisa ${remaining.inHours}j ${remaining.inMinutes % 60}m (< 5 C)',
      statusColor: ready ? AppColors.warnFg : AppColors.safeFg,
      metadata: [
        BorderlessMetaItem(
          icon: Icons.restaurant_menu_rounded,
          label: item.menuName,
        ),
        BorderlessMetaItem(
          icon: Icons.schedule_rounded,
          label: formatWibTime(item.storedAtUtc),
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
  }
}

class _DetailSheetRow extends StatelessWidget {
  const _DetailSheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 310 || textScale >= 1.25) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.captionMuted),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.tabular(AppTypography.titleItem)),
              ],
            );
          }
          return Row(
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
          );
        },
      ),
    );
  }
}

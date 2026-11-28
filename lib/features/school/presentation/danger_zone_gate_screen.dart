import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/sensors/ble_thermometer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../allergens/domain/allergen_models.dart';
import '../../allergens/presentation/allergen_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../../traceability/domain/traceability_models.dart';
import '../../traceability/presentation/traceability_providers.dart';
import '../../traceability/presentation/widgets/supply_chain_timeline.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';
import 'widgets/audit_detail_sections.dart';

/// G03: Langkah 1 dari 3 - Editorial Danger-Zone Clock & BMKG weather inspection gate.
class DangerZoneGateScreen extends ConsumerStatefulWidget {
  const DangerZoneGateScreen({super.key, this.scanContext});

  final VerifiedBatchScanContext? scanContext;

  @override
  ConsumerState<DangerZoneGateScreen> createState() =>
      _DangerZoneGateScreenState();
}

class _DangerZoneGateScreenState extends ConsumerState<DangerZoneGateScreen> {
  final TextEditingController _manualTempController = TextEditingController();
  VerifiedBatchScanContext? _overrideContext;
  int _tempMode = 0; // 0 = manual, 1 = BLE ready
  BleThermometerAvailability? _bleAvailability;
  bool _readingBle = false;
  String? _tempError;
  bool _savingStop = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBleAvailability);
  }

  @override
  void didUpdateWidget(covariant DangerZoneGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanContext != widget.scanContext) {
      _overrideContext = null;
      _tempError = null;
    }
  }

  @override
  void dispose() {
    _manualTempController.dispose();
    super.dispose();
  }

  Future<void> _loadBleAvailability() async {
    try {
      final status = await ref
          .read(bleThermometerServiceProvider)
          .checkAvailability();
      if (mounted) {
        setState(() => _bleAvailability = status);
      }
    } catch (_) {
      // Safe no-crash fallback if device lacks BLE hardware.
    }
  }

  void _applyActualTemperature(
    VerifiedBatchScanContext baseCtx, {
    required double tempC,
    required FoodTemperatureSource source,
  }) {
    final reEvaluated = DangerZoneCalculator.evaluate(
      riskCategory: baseCtx.riskCategory,
      sealedAtUtc: baseCtx.sealedAtUtc,
      scanAtUtc: baseCtx.scannedAtUtc,
      temperatureC: baseCtx.weather.temperatureC,
      actualTempC: tempC,
      tempSource: source,
    );
    setState(() {
      _tempError = null;
      _overrideContext = baseCtx.copyWithActualTemp(
        actualTempC: tempC,
        tempSource: source,
        dangerEvaluation: reEvaluated,
      );
    });
  }

  void _applyManualTemperature(VerifiedBatchScanContext baseCtx) {
    final raw = _manualTempController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed < -5.0 || parsed > 110.0) {
      setState(() {
        _tempError = 'Masukkan angka suhu makanan yang valid (-5 s.d. 110 C).';
      });
      return;
    }
    _applyActualTemperature(
      baseCtx,
      tempC: parsed,
      source: FoodTemperatureSource.manualThermometer,
    );
  }

  Future<void> _scanBleThermometer(VerifiedBatchScanContext baseCtx) async {
    if (_readingBle) {
      return;
    }
    setState(() {
      _readingBle = true;
      _tempError = null;
    });
    try {
      final service = ref.read(bleThermometerServiceProvider);
      final avail = await service.checkAvailability();
      final reading = await service.readContainerTemperature();
      if (!mounted) {
        return;
      }
      setState(() {
        _bleAvailability = avail;
        _readingBle = false;
      });
      if (reading != null) {
        _manualTempController.text = reading.temperatureC.toStringAsFixed(1);
        _applyActualTemperature(
          baseCtx,
          tempC: reading.temperatureC,
          source: FoodTemperatureSource.bleSensor,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Belum ada sensor BLE kontainer yang terpasang. Gunakan Termometer Manual atau lanjutkan dengan estimasi BMKG.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _readingBle = false;
        _tempError =
            'Sensor BLE belum terhubung. Gunakan Termometer Manual atau estimasi BMKG.';
      });
    }
  }

  void _resetToBmkg(VerifiedBatchScanContext baseCtx) {
    final reEvaluated = DangerZoneCalculator.evaluate(
      riskCategory: baseCtx.riskCategory,
      sealedAtUtc: baseCtx.sealedAtUtc,
      scanAtUtc: baseCtx.scannedAtUtc,
      temperatureC: baseCtx.weather.temperatureC,
    );
    setState(() {
      _tempError = null;
      _manualTempController.clear();
      _overrideContext = baseCtx.copyWithActualTemp(
        actualTempC: null,
        tempSource: FoodTemperatureSource.bmkgEstimate,
        dangerEvaluation: reEvaluated,
      );
    });
  }

  Future<void> _stopAndReport(
    VerifiedBatchScanContext ctx, {
    required String reasonSummary,
  }) async {
    if (_savingStop) {
      return;
    }
    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() => _savingStop = true);
    final isOffline = ref.read(isOfflineProvider).value ?? false;
    try {
      final inspection = await ref.read(schoolRepositoryProvider).saveInspection(
            school: school,
            scanContext: ctx,
            samplePhoto: null,
            onDeviceResult: null,
            cloudResult: null,
            manualSmellOk: false,
            manualVisualOk: true,
            manualPackOk: true,
            approved: false,
            isOffline: isOffline,
          );
      invalidateSchoolProviders(ref);
      if (!mounted) {
        return;
      }
      context.pushReplacement(
        AppRoutes.schoolReportAlert,
        extra: AnomalyHandoffArgs(
          batchId: ctx.payload.batchId,
          batchCode: ctx.payload.batchCode,
          menuName: ctx.payload.menuName,
          sppgId: ctx.payload.sppgId,
          sppgName: ctx.sppgName,
          sealedAtUtc: ctx.sealedAtUtc,
          scannedAtUtc: ctx.scannedAtUtc,
          elapsedMinutes: ctx.dangerEvaluation.elapsedMinutes,
          bmkgTempC: ctx.weather.temperatureC,
          bmkgSource: ctx.weather.source,
          dangerStatus: ctx.dangerEvaluation.status,
          inspectionId: inspection.id,
          reasonSummary: reasonSummary,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _savingStop = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencatat laporan penahanan: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseCtx = widget.scanContext;
    final ctx = _overrideContext ?? baseCtx;
    final school = ref.watch(authControllerProvider).school;
    final schoolAllergens =
        ref.watch(schoolAllergensProvider).value ?? const <SchoolAllergenEntry>[];
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    if (ctx == null) {
      return Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(horizontalPad),
            child: LacakErrorState(
              title: 'Data QR belum tersedia',
              message:
                  'Silakan pindai ulang Kode QR makanan masuk dari Beranda Sekolah.',
              onRetry: () => context.go(AppRoutes.schoolHome),
              retryLabel: 'Kembali ke Beranda',
            ),
          ),
        ),
      );
    }

    final status = ctx.dangerEvaluation.status;
    final isRed = status == DangerZoneStatus.red;
    final isYellow = status == DangerZoneStatus.yellow;
    final effectiveAllergenEntries = schoolAllergens.isNotEmpty
        ? schoolAllergens
        : ctx.matchedAllergens;
    final allergenWarning = AllergenMatchWarning.intersect(
      batchAllergenTags: ctx.payload.allergenTags,
      schoolEntries: effectiveAllergenEntries,
    );

    final Color heroBg = isRed
        ? AppColors.dangerBg
        : (isYellow ? AppColors.warnBg : AppColors.safeBg);
    final Color heroFg = isRed
        ? AppColors.dangerFg
        : (isYellow ? AppColors.warnFg : AppColors.safeFg);
    final IconData heroIcon = isRed
        ? Icons.dangerous_rounded
        : (isYellow ? Icons.warning_amber_rounded : Icons.verified_user_rounded);
    final String summaryStatusText = isRed
        ? 'Tahan Distribusi'
        : (isYellow ? 'Waspada' : 'Aman');

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth == double.infinity
                        ? double.infinity
                        : maxWidth + horizontalPad * 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: FramedHeroHeader(
                            height: 248,
                            imagePlaceholder: Container(
                              color: heroBg,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.only(bottom: 56),
                              child: Icon(heroIcon, size: 56, color: heroFg),
                            ),
                            onBackTap: () => Navigator.of(context).maybePop(),
                            actionIcon: isRed
                                ? null
                                : Icons.notification_important_rounded,
                            actionTooltip: 'Laporkan Makanan Bermasalah',
                            onActionTap: isRed
                                ? null
                                : () => _stopAndReport(
                                    ctx,
                                    reasonSummary:
                                        'Petugas sekolah mencurigai makanan tercium basi sebelum uji visual selesai.',
                                  ),
                            title: ctx.payload.menuName,
                            subtitle:
                                '${status.bannerTitle} · ${ctx.payload.batchCode}',
                            metrics: [
                              HeroMetricItem(
                                icon: Icons.schedule_rounded,
                                label: formatDurationMinutes(
                                  ctx.dangerEvaluation.elapsedMinutes,
                                ),
                              ),
                              HeroMetricItem(
                                icon: Icons.thermostat_rounded,
                                label: ctx.formattedEffectiveTemp,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (ctx.dangerEvaluation.hasClockSkew)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            AppSpacing.md,
                            horizontalPad,
                            0,
                          ),
                          child: LacakStatusBanner(
                            level: LacakStatusLevel.warning,
                            icon: Icons.schedule_rounded,
                            title: 'Jam HP Tidak Sinkron dengan Waktu Dapur',
                            description:
                                'Jam pada perangkat ini tertinggal ${ctx.dangerEvaluation.rawElapsedMinutes.abs()} menit dari waktu segel dapur. Aktifkan Tanggal & Waktu Otomatis di pengaturan HP dan periksa kesegaran makanan secara teliti.',
                          ),
                        ),
                      if (allergenWarning.hasMatches)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            AppSpacing.md,
                            horizontalPad,
                            0,
                          ),
                          child: LacakStatusBanner(
                            level: LacakStatusLevel.danger,
                            icon: Icons.health_and_safety_rounded,
                            title:
                                'PERINGATAN ALERGEN SISWA (${allergenWarning.totalReportedCases} SISWA TERDAMPAK)',
                            description: allergenWarning.buildSummaryMessage(),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          AppSpacing.xl,
                          horizontalPad,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Langkah 1 dari 3 · Cek Waktu & Suhu',
                              style: AppTypography.captionMuted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ExpandableAuditSummary(
                              title: 'Ringkasan Pemeriksaan',
                              text: ctx.dangerEvaluation.explanation,
                              extraDetails: Text(
                                ctx.gpsWithinRadius
                                    ? 'Lokasi GPS sekolah tervalidasi dalam radius aman (<= 500 m). Sumber waktu: ${ctx.timestampSource.label}.'
                                    : 'Catatan GPS: posisi di luar radius profil (${ctx.distanceMeters?.round() ?? 0} m). Sumber waktu: ${ctx.timestampSource.label}.',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.lg),
                            PartnerContactRow(
                              name: ctx.sppgName,
                              roleLabel: 'Dapur SPPG Mitra · Segel Digital Asli',
                              phoneOrWaNumber: school?.puskesmasWa,
                              copyFallbackCode: school?.partnerInviteCode,
                              waPrefillMessage:
                                  'Koordinasi batch ${ctx.payload.batchCode} (${ctx.payload.menuName}) di ${school?.name ?? 'Sekolah'}. Status waktu-suhu: ${status.bannerTitle}.',
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            const AuditEvidenceGallery(
                              title: 'Galeri Bukti Audit',
                              slots: [
                                AuditGallerySlot(
                                  label: 'Segel QR',
                                  fallbackIcon: Icons.qr_code_2_rounded,
                                  active: true,
                                ),
                                AuditGallerySlot(
                                  label: 'Suhu BMKG',
                                  fallbackIcon: Icons.thermostat_rounded,
                                  active: true,
                                ),
                                AuditGallerySlot(
                                  label: 'Foto Sampel',
                                  fallbackIcon: Icons.photo_camera_rounded,
                                ),
                                AuditGallerySlot(
                                  label: 'Bank Sampel',
                                  fallbackIcon: Icons.kitchen_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _ActualTemperatureSection(
                              ctx: ctx,
                              tempMode: _tempMode,
                              onModeChanged: (next) =>
                                  setState(() => _tempMode = next),
                              manualController: _manualTempController,
                              tempError: _tempError,
                              onApplyManual: () =>
                                  _applyManualTemperature(ctx),
                              bleAvailability: _bleAvailability,
                              readingBle: _readingBle,
                              onScanBle: () => _scanBleThermometer(ctx),
                              onResetBmkg: () => _resetToBmkg(ctx),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _GateSupplyChainTimelineSection(ctx: ctx),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Rincian Verifikasi Pengiriman',
                              style: AppTypography.titleSection,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Divider(height: 1),
                            _FlatGateRow(
                              label: 'Kode Batch',
                              value: ctx.payload.batchCode,
                              tabular: true,
                            ),
                            if (ctx.payload.allergenTags.isNotEmpty) ...[
                              const Divider(height: 1),
                              _FlatGateRow(
                                label: 'Tag Alergen Menu',
                                value: ctx.payload.allergenTags
                                    .map(AllergenTag.displayLabelFor)
                                    .join(', '),
                              ),
                            ],
                            const Divider(height: 1),
                            _FlatGateRow(
                              label: 'Jam Segel Dapur',
                              value: formatWibDateTime(ctx.sealedAtUtc),
                              subtitle: ctx.timestampSource.label,
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            _FlatGateRow(
                              label: 'Kategori Risiko',
                              value: ctx.riskCategory.label,
                            ),
                            const Divider(height: 1),
                            _FlatGateRow(
                              label: ctx.actualTempC != null
                                  ? 'Suhu Acuan Aktif'
                                  : 'Suhu Wilayah',
                              value: ctx.actualTempC != null
                                  ? '${ctx.formattedEffectiveTemp} · ${ctx.tempSource.label}'
                                  : '${ctx.weather.formattedTemperature} · ${ctx.weather.source.label}',
                              subtitle: ctx.actualTempC != null
                                  ? 'Default BMKG: ${ctx.weather.formattedTemperature} (${AppConstants.bmkgShortAttribution})'
                                  : AppConstants.bmkgShortAttribution,
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            _FlatGateRow(
                              label: 'Lokasi Sekolah',
                              value: ctx.gpsWithinRadius
                                  ? 'Dalam area sekolah (<= 500 m)'
                                  : 'Luar radius profil (${ctx.distanceMeters?.round() ?? 0} m)',
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            if (!isRed) ...[
                              const SizedBox(height: AppSpacing.md),
                              TextButton.icon(
                                onPressed: _savingStop
                                    ? null
                                    : () => _stopAndReport(
                                        ctx,
                                        reasonSummary:
                                            'Petugas sekolah mencurigai makanan tercium basi sebelum uji visual selesai.',
                                      ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    double.infinity,
                                    AppSpacing.minTouchTarget,
                                  ),
                                  foregroundColor: AppColors.dangerFg,
                                ),
                                icon: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 19,
                                ),
                                label: const Text(
                                  'Makanan tercium basi? Laporkan sekarang',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          StickyBottomActionBar(
            summaryLabel: 'Status Keamanan',
            summaryValue: summaryStatusText,
            summaryValueColor: heroFg,
            ctaLabel: isRed ? 'Hentikan & Lapor' : 'Lanjut Foto Sampel',
            ctaIcon: isRed
                ? Icons.notification_important_rounded
                : Icons.photo_camera_rounded,
            ctaColor: isRed ? AppColors.emergencyBg : AppColors.primary,
            isLoading: _savingStop,
            onCtaPressed: isRed
                ? () => _stopAndReport(
                    ctx,
                    reasonSummary:
                        'Durasi perjalanan (${formatDurationMinutes(ctx.dangerEvaluation.elapsedMinutes)}) melewati batas aman pada suhu ${ctx.formattedEffectiveTemp}.',
                  )
                : () => context.push(AppRoutes.schoolVisualAudit, extra: ctx),
          ),
        ],
      ),
    );
  }
}

class _FlatGateRow extends StatelessWidget {
  const _FlatGateRow({
    required this.label,
    required this.value,
    this.subtitle,
    this.tabular = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final valueStyle = tabular
        ? AppTypography.tabular(AppTypography.titleItem)
        : AppTypography.titleItem;

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
                Text(value, style: valueStyle),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTypography.captionLegal),
                ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, textAlign: TextAlign.right, style: valueStyle),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.right,
                        style: AppTypography.captionLegal,
                      ),
                    ],
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

class _GateSupplyChainTimelineSection extends ConsumerWidget {
  const _GateSupplyChainTimelineSection({required this.ctx});

  final VerifiedBatchScanContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(
      batchSupplyChainTimelineProvider((
        sppgId: ctx.payload.sppgId,
        batchId: ctx.payload.batchId,
        sealedAtUtc: ctx.sealedAtUtc,
        schoolScannedAtUtc: ctx.scannedAtUtc,
      )),
    );

    final fallback = SupplyChainTimelineData(
      batchId: ctx.payload.batchId,
      sealedAtUtc: ctx.sealedAtUtc,
      schoolScannedAtUtc: ctx.scannedAtUtc,
    );

    return SupplyChainTimeline(
      timeline: timelineAsync.value ?? fallback,
    );
  }
}

class _ActualTemperatureSection extends StatelessWidget {
  const _ActualTemperatureSection({
    required this.ctx,
    required this.tempMode,
    required this.onModeChanged,
    required this.manualController,
    required this.tempError,
    required this.onApplyManual,
    required this.bleAvailability,
    required this.readingBle,
    required this.onScanBle,
    required this.onResetBmkg,
  });

  final VerifiedBatchScanContext ctx;
  final int tempMode;
  final ValueChanged<int> onModeChanged;
  final TextEditingController manualController;
  final String? tempError;
  final VoidCallback onApplyManual;
  final BleThermometerAvailability? bleAvailability;
  final bool readingBle;
  final VoidCallback onScanBle;
  final VoidCallback onResetBmkg;

  @override
  Widget build(BuildContext context) {
    final hasActual = ctx.actualTempC != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Ukur Suhu Aktual Makanan (Opsional)',
              style: AppTypography.titleSection,
            ),
            if (hasActual)
              LacakStatusTag(
                level: LacakStatusLevel.safe,
                label: ctx.tempSource.label,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Default otomatis memakai suhu BMKG Rp0. Jika tersedia termometer tusuk atau sensor kontainer, ukur suhu inti untuk pembaruan langsung.',
          style: AppTypography.captionMuted,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilterChipStrip<int>(
          padding: EdgeInsets.zero,
          selectedValue: tempMode,
          onSelected: onModeChanged,
          items: const [
            FilterChipItem(
              value: 0,
              label: 'Termometer Manual',
              icon: Icons.thermostat_rounded,
            ),
            FilterChipItem(
              value: 1,
              label: 'Sensor BLE',
              icon: Icons.bluetooth_searching_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          ),
          child: tempMode == 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LacakTextField(
                      label: 'Suhu Inti Makanan (Celsius)',
                      controller: manualController,
                      hintText: 'Contoh: 64.5',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    if (tempError != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tempError!,
                        style: AppTypography.captionMuted.copyWith(
                          color: AppColors.dangerFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    LacakSecondaryButton(
                      label: 'Terapkan Suhu Aktual',
                      icon: Icons.check_rounded,
                      onPressed: onApplyManual,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      bleAvailability?.status.label ?? 'Siap Dihubungkan',
                      style: AppTypography.titleItem,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bleAvailability?.detail ??
                          'Arsitektur siap menghubungkan sensor suhu Bluetooth Low Energy (BLE) kontainer tanpa mengganggu alur offline.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LacakSecondaryButton(
                      label: 'Pindai Sensor BLE Kontainer',
                      icon: Icons.bluetooth_connected_rounded,
                      isLoading: readingBle,
                      onPressed: onScanBle,
                    ),
                  ],
                ),
        ),
        if (hasActual) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onResetBmkg,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Kembali ke Estimasi BMKG'),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/media/live_camera_webp_service.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hybrid_vision_service.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';
import 'widgets/audit_detail_sections.dart';

/// G04: Langkah 2 dari 3 - Editorial Hybrid Visual Organoleptic Audit
/// (FramedHeroHeader + Expandable summary + Partner contact + 4-slot Gallery + Borderless checklist + StickyBottomActionBar).
class VisualAuditScreen extends ConsumerStatefulWidget {
  const VisualAuditScreen({super.key, this.scanContext});

  final VerifiedBatchScanContext? scanContext;

  @override
  ConsumerState<VisualAuditScreen> createState() => _VisualAuditScreenState();
}

class _VisualAuditScreenState extends ConsumerState<VisualAuditScreen> {
  CapturedWebpPhoto? _samplePhoto;
  bool _capturing = false;
  bool _runningOnDevice = false;
  bool _runningCloud = false;
  bool _cloudSkippedByUser = false;
  bool _submitting = false;

  OnDeviceVisualResult? _onDeviceResult;
  CloudVisionResult? _cloudResult;
  String? _validationError;

  // 3-question rapid organoleptic manual checklist (null until consciously chosen).
  bool? _smellOk;
  bool? _visualOk;
  bool? _packOk;

  Future<void> _captureSamplePhoto(VerifiedBatchScanContext ctx) async {
    if (_capturing || _submitting) {
      return;
    }
    setState(() {
      _capturing = true;
      _validationError = null;
    });

    try {
      final photo =
          await ref.read(liveCameraWebpServiceProvider).captureAndCompress();
      if (!mounted) {
        return;
      }
      if (photo == null) {
        setState(() => _capturing = false);
        return;
      }

      setState(() {
        _samplePhoto = photo;
        _capturing = false;
        _runningOnDevice = true;
        _runningCloud = true;
        _cloudSkippedByUser = false;
        _onDeviceResult = null;
        _cloudResult = null;
      });

      final vision = ref.read(hybridVisionServiceProvider);
      final isOffline = ref.read(isOfflineProvider).value ?? false;

      // Layer 1: On-device TFLite/pixel isolate check (< 1s offline).
      final localResult = await vision.analyzeOnDevice(photo.bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _onDeviceResult = localResult;
        _runningOnDevice = false;
      });

      // Layer 2: Gemini Vision Edge Function collaborating with Layer 1 local screening.
      final cloud = await vision.analyzeCloudOrganoleptic(
        photoBytes: photo.bytes,
        menuName: ctx.payload.menuName,
        isOffline: isOffline,
        localScreening: localResult,
      );
      if (!mounted || _cloudSkippedByUser) {
        return;
      }
      setState(() {
        _cloudResult = cloud;
        _runningCloud = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _capturing = false;
        _runningOnDevice = false;
        _runningCloud = false;
        _validationError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _skipCloudAndUseManual() {
    setState(() {
      _cloudSkippedByUser = true;
      _runningCloud = false;
      _cloudResult = const CloudVisionResult(
        ok: false,
        provider: 'manual_skip',
        fallbackRequired: true,
        summaryText: 'Pemeriksaan lanjutan dilewati. Menggunakan cek manual.',
      );
    });
  }

  bool get _hasManualAnomaly =>
      _smellOk == false || _visualOk == false || _packOk == false;

  bool get _allChecklistAnswered =>
      _smellOk != null && _visualOk != null && _packOk != null;

  String _buildWaPrefillMessage({
    required VerifiedBatchScanContext ctx,
    String? schoolName,
  }) {
    final base =
        'Laporan audit organoleptik batch ${ctx.payload.batchCode} (${ctx.payload.menuName}) di ${schoolName ?? 'Sekolah'}.';
    final cloud = _cloudResult;
    if (cloud != null && cloud.ok && cloud.hasMenuMismatch) {
      final note = (cloud.menuMatchNote ?? '').isNotEmpty
          ? cloud.menuMatchNote!
          : cloud.menuMatch!.displayLabel;
      return '$base Catatan ketidaksesuaian menu: $note';
    }
    return base;
  }

  Future<void> _submitDecision(VerifiedBatchScanContext ctx) async {
    if (_submitting) {
      return;
    }

    if (!_allChecklistAnswered) {
      setState(() {
        _validationError =
            'Lengkapi seluruh 3 pertanyaan pemeriksaan manual sebelum menyimpan keputusan.';
      });
      return;
    }

    final anomaly = _hasManualAnomaly;
    if (!anomaly && _samplePhoto == null) {
      setState(() {
        _validationError =
            'Ambil foto sampel makanan terlebih dahulu menggunakan kamera langsung.';
      });
      return;
    }

    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _validationError = null;
    });

    final isOffline = ref.read(isOfflineProvider).value ?? false;
    final repo = ref.read(schoolRepositoryProvider);

    try {
      final saved = await repo.saveInspection(
        school: school,
        scanContext: ctx,
        samplePhoto: _samplePhoto,
        onDeviceResult: _onDeviceResult,
        cloudResult: _cloudResult,
        manualSmellOk: _smellOk ?? false,
        manualVisualOk: _visualOk ?? false,
        manualPackOk: _packOk ?? false,
        approved: !anomaly,
        isOffline: isOffline,
      );
      invalidateSchoolProviders(ref);
      if (!mounted) {
        return;
      }

      if (anomaly) {
        final reasons = <String>[
          if (_smellOk == false) 'bau asam/basi',
          if (_visualOk == false) 'tampilan berlendir atau berubah warna',
          if (_packOk == false) 'kemasan menggembung atau bocor',
        ].join(', ');
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
            localPhotoPath: _samplePhoto?.filePath,
            inspectionId: saved.id,
            reasonSummary: 'Temuan pemeriksaan kondisi makanan: $reasons.',
          ),
        );
      } else {
        final labelCode = repo.generateSampleLabelCode(DateTime.now().toUtc());
        context.pushReplacement(
          AppRoutes.schoolSampleSave,
          extra: SampleVaultOnboardingArgs(
            inspectionId: saved.id,
            menuName: ctx.payload.menuName,
            batchCode: ctx.payload.batchCode,
            suggestedLabelCode: labelCode,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _validationError = 'Gagal menyimpan hasil audit: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.scanContext;
    final school = ref.watch(authControllerProvider).school;
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
              title: 'Data pemeriksaan belum tersedia',
              message:
                  'Pindai ulang Kode QR makanan masuk dari Beranda Sekolah.',
              onRetry: () => context.go(AppRoutes.schoolHome),
              retryLabel: 'Kembali ke Beranda',
            ),
          ),
        ),
      );
    }

    final String footerStatusValue;
    final Color footerStatusColor;
    if (_hasManualAnomaly) {
      footerStatusValue = 'Tahan Distribusi';
      footerStatusColor = AppColors.dangerFg;
    } else if (_allChecklistAnswered) {
      footerStatusValue = 'Aman Dibagikan';
      footerStatusColor = AppColors.safeFg;
    } else {
      footerStatusValue = 'Lengkapi Cek Manual';
      footerStatusColor = AppColors.textSecondary;
    }

    final photoImage = _samplePhoto != null
        ? MemoryImage(_samplePhoto!.bytes)
        : null;

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
                            height: 252,
                            image: photoImage,
                            imagePlaceholder: Container(
                              color: AppColors.primaryTint,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.only(bottom: 44),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 48,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Potret 1 porsi sampel makanan',
                                    style: AppTypography.labelTag.copyWith(
                                      color: AppColors.onPrimaryTint,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onBackTap: () => Navigator.of(context).maybePop(),
                            actionIcon: Icons.photo_camera_rounded,
                            actionTooltip: 'Ambil Foto Sampel',
                            onActionTap: () => _captureSamplePhoto(ctx),
                            title: ctx.payload.menuName,
                            subtitle:
                                'Langkah 2 dari 3 · ${ctx.payload.batchCode}',
                            metrics: [
                              HeroMetricItem(
                                icon: Icons.schedule_rounded,
                                label: formatDurationMinutes(
                                  ctx.dangerEvaluation.elapsedMinutes,
                                ),
                              ),
                              HeroMetricItem(
                                icon: Icons.thermostat_rounded,
                                label: ctx.weather.formattedTemperature,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          AppSpacing.lg,
                          horizontalPad,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LacakSecondaryButton(
                              label: _samplePhoto == null
                                  ? 'Ambil Foto Sampel'
                                  : 'Foto Ulang Sampel',
                              icon: Icons.photo_camera_rounded,
                              isLoading: _capturing,
                              onPressed: () => _captureSamplePhoto(ctx),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            if (_samplePhoto != null) ...[
                              _UnifiedPhotoAuditSummary(
                                isRunningOnDevice: _runningOnDevice,
                                isRunningCloud: _runningCloud,
                                onDeviceResult: _onDeviceResult,
                                cloudResult: _cloudResult,
                                onSkipCloud: _skipCloudAndUseManual,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ] else ...[
                              ExpandableAuditSummary(
                                title: 'Ringkasan Pemeriksaan',
                                text:
                                    'Ambil foto 1 porsi makanan menggunakan kamera langsung untuk menjalankan pemeriksaan cepat di HP dan verifikasi AI. Lengkapi 3 pengecekan bau, tampilan, dan kemasan di bawah.',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.lg),
                            PartnerContactRow(
                              name: ctx.sppgName,
                              roleLabel: 'Dapur SPPG Mitra · PIC Pengiriman',
                              phoneOrWaNumber: school?.puskesmasWa,
                              copyFallbackCode: school?.partnerInviteCode,
                              waPrefillMessage: _buildWaPrefillMessage(
                                ctx: ctx,
                                schoolName: school?.name,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AuditEvidenceGallery(
                              title: 'Galeri Bukti Audit',
                              slots: [
                                AuditGallerySlot(
                                  label: 'Sampel',
                                  fallbackIcon: Icons.photo_camera_rounded,
                                  image: photoImage,
                                  active: _samplePhoto != null,
                                ),
                                const AuditGallerySlot(
                                  label: 'Segel QR',
                                  fallbackIcon: Icons.qr_code_2_rounded,
                                  active: true,
                                ),
                                const AuditGallerySlot(
                                  label: 'Suhu BMKG',
                                  fallbackIcon: Icons.thermostat_rounded,
                                  active: true,
                                ),
                                AuditGallerySlot(
                                  label: 'Kulkas 48j',
                                  fallbackIcon: Icons.kitchen_rounded,
                                  active: _allChecklistAnswered &&
                                      !_hasManualAnomaly,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Checklist Organoleptik Manual (Wajib)',
                              style: AppTypography.titleSection,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _ManualCheckQuestionRow(
                              question: '1. Bau Makanan',
                              safeLabel: 'Bau Normal',
                              issueLabel: 'Asam / Basi',
                              value: _smellOk,
                              onSelect: (val) => setState(() {
                                _smellOk = val;
                                _validationError = null;
                              }),
                            ),
                            const Divider(height: 1),
                            _ManualCheckQuestionRow(
                              question: '2. Tampilan & Lendir',
                              safeLabel: 'Tampak Segar',
                              issueLabel: 'Berlendir / Berubah Warna',
                              value: _visualOk,
                              onSelect: (val) => setState(() {
                                _visualOk = val;
                                _validationError = null;
                              }),
                            ),
                            const Divider(height: 1),
                            _ManualCheckQuestionRow(
                              question: '3. Kemasan / Susu',
                              safeLabel: 'Kemasan Utuh',
                              issueLabel: 'Menggembung / Bocor',
                              value: _packOk,
                              onSelect: (val) => setState(() {
                                _packOk = val;
                                _validationError = null;
                              }),
                            ),
                            const Divider(height: 1),
                            if (_validationError != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 20,
                                    color: AppColors.dangerFg,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      _validationError!,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.dangerFg,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
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
            summaryLabel: 'Status Akhir',
            summaryValue: footerStatusValue,
            summaryValueColor: footerStatusColor,
            ctaLabel:
                _hasManualAnomaly ? 'Hentikan & Lapor' : 'Simpan & Lanjut',
            ctaIcon: _hasManualAnomaly
                ? Icons.notification_important_rounded
                : Icons.kitchen_rounded,
            ctaColor:
                _hasManualAnomaly ? AppColors.emergencyBg : AppColors.primary,
            isLoading: _submitting,
            onCtaPressed: () => _submitDecision(ctx),
          ),
        ],
      ),
    );
  }
}

class _UnifiedPhotoAuditSummary extends StatelessWidget {
  const _UnifiedPhotoAuditSummary({
    required this.isRunningOnDevice,
    required this.isRunningCloud,
    required this.onDeviceResult,
    required this.cloudResult,
    required this.onSkipCloud,
  });

  final bool isRunningOnDevice;
  final bool isRunningCloud;
  final OnDeviceVisualResult? onDeviceResult;
  final CloudVisionResult? cloudResult;
  final VoidCallback onSkipCloud;

  ({
    LacakStatusLevel level,
    String statusTitle,
    String badgeLabel,
    String summary,
    String? helperNote,
  })
  _resolveUnifiedOutput() {
    final local = onDeviceResult;
    final cloud = cloudResult;

    if (local == null || isRunningOnDevice || isRunningCloud) {
      return (
        level: LacakStatusLevel.offline,
        statusTitle: 'Memeriksa Foto dengan AI...',
        badgeLabel: 'MEMERIKSA',
        summary:
            'Sedang menganalisis kondisi nasi, lauk, sayur, dan kemasan dari foto. Mohon tunggu sebentar.',
        helperNote: null,
      );
    }

    final localFlagged = local.label != OnDeviceVisualLabel.freshLikely;
    final cloudSucceeded = cloud != null && cloud.ok;
    final cloudFlagged =
        cloudSucceeded &&
        ((cloud.freshnessStatus != null &&
                cloud.freshnessStatus != OnDeviceVisualLabel.freshLikely) ||
            cloud.slimeOrDiscolorationDetected == true ||
            cloud.packagingIssueDetected == true);

    if (cloudFlagged || (!cloudSucceeded && localFlagged)) {
      final isPack = cloudFlagged
          ? (cloud.packagingIssueDetected == true ||
                cloud.freshnessStatus == OnDeviceVisualLabel.packagingAnomaly)
          : local.label == OnDeviceVisualLabel.packagingAnomaly;
      final isHighRisk = _isHighRiskVisualDefect(cloud, local);
      final level = (isPack || isHighRisk)
          ? LacakStatusLevel.danger
          : LacakStatusLevel.warning;
      final statusTitle = isPack
          ? 'PERLU CEK KEMASAN'
          : (isHighRisk ? 'TERINDIKASI TIDAK LAYAK' : 'PERLU PERIKSA KETAT');
      final badgeLabel = (isPack || isHighRisk) ? 'BAHAYA' : 'PERHATIAN';
      final summary = cloudFlagged ? cloud.summaryText : local.summaryText;
      return (
        level: level,
        statusTitle: statusTitle,
        badgeLabel: badgeLabel,
        summary: summary,
        helperNote: !cloudSucceeded
            ? 'Terdeteksi dari pemeriksaan cepat di HP. Lengkapi cek bau dan tampilan di bawah.'
            : (isHighRisk
                  ? 'Temuan berisiko tinggi (jamur, busuk, atau basi). Segera tahan distribusi jika terkonfirmasi.'
                  : 'Tetap pastikan bau, rasa, dan kemasan pada daftar periksa di bawah.'),
      );
    }

    if (cloudSucceeded) {
      return (
        level: LacakStatusLevel.safe,
        statusTitle: 'TAMPAK WAJAR SECARA VISUAL',
        badgeLabel: 'WAJAR',
        summary: cloud.summaryText,
        helperNote:
            'Hasil pemeriksaan AI selesai. Tetap lengkapi 3 pengecekan manual di bawah.',
      );
    }

    final isOfflineFallback = cloud == null || cloud.provider == 'offline_mode';
    if (isOfflineFallback) {
      return (
        level: LacakStatusLevel.safe,
        statusTitle: 'TAMPAK WAJAR SECARA VISUAL',
        badgeLabel: 'CEK HP',
        summary: local.summaryText,
        helperNote: cloud?.summaryText,
      );
    }

    return (
      level: LacakStatusLevel.offline,
      statusTitle: 'PERIKSA MANUAL LANGSUNG',
      badgeLabel: 'CEK MANUAL',
      summary: cloud.summaryText,
      helperNote:
          'Pemeriksaan AI server belum aktif pada foto ini. Pastikan kelayakan makanan dengan 3 pengecekan manual di bawah.',
    );
  }

  bool _isHighRiskVisualDefect(
    CloudVisionResult? cloud,
    OnDeviceVisualResult local,
  ) {
    if (cloud != null && cloud.ok) {
      if (cloud.anomaliesFound.length >= 2) {
        return true;
      }
      final combined = [
        cloud.summaryText,
        ...cloud.anomaliesFound,
        cloud.riceCheck ?? '',
        cloud.proteinCheck ?? '',
        cloud.vegetableCheck ?? '',
        cloud.fruitAndPackCheck ?? '',
      ].join(' ').toLowerCase();
      return RegExp(
        r'\b(jamur|kapang|busuk|basi|lendir|berlendir|berbuih|berbusa|hangus)\b',
      ).hasMatch(combined);
    }
    return local.localHints.length >= 2;
  }

  bool _hasComponentDetails(CloudVisionResult cloud) {
    return (cloud.riceCheck ?? '').isNotEmpty ||
        (cloud.vegetableCheck ?? '').isNotEmpty ||
        (cloud.proteinCheck ?? '').isNotEmpty ||
        (cloud.fruitAndPackCheck ?? '').isNotEmpty ||
        (cloud.menuMatchNote ?? '').isNotEmpty ||
        cloud.anomaliesFound.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final verdict = _resolveUnifiedOutput();
    final isWarningOrDanger =
        verdict.level == LacakStatusLevel.warning ||
        verdict.level == LacakStatusLevel.danger;
    final bgColor = switch (verdict.level) {
      LacakStatusLevel.danger => AppColors.dangerBg,
      LacakStatusLevel.warning => AppColors.warnBg,
      LacakStatusLevel.offline => AppColors.infoBg,
      _ => AppColors.surfaceSoft,
    };
    final titleColor = switch (verdict.level) {
      LacakStatusLevel.danger => AppColors.dangerFg,
      LacakStatusLevel.warning => AppColors.warnFg,
      LacakStatusLevel.offline => AppColors.infoFg,
      _ => AppColors.textPrimary,
    };

    Widget? detailsWidget;
    if (!isRunningCloud &&
        cloudResult != null &&
        cloudResult!.ok &&
        _hasComponentDetails(cloudResult!)) {
      detailsWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((cloudResult!.riceCheck ?? '').isNotEmpty)
            _ComponentCheckBullet(
              label: 'Nasi',
              detail: cloudResult!.riceCheck!,
            ),
          if ((cloudResult!.vegetableCheck ?? '').isNotEmpty)
            _ComponentCheckBullet(
              label: 'Sayur',
              detail: cloudResult!.vegetableCheck!,
            ),
          if ((cloudResult!.proteinCheck ?? '').isNotEmpty)
            _ComponentCheckBullet(
              label: 'Lauk',
              detail: cloudResult!.proteinCheck!,
            ),
          if ((cloudResult!.fruitAndPackCheck ?? '').isNotEmpty)
            _ComponentCheckBullet(
              label: 'Buah & Kemasan',
              detail: cloudResult!.fruitAndPackCheck!,
            ),
          if ((cloudResult!.menuMatchNote ?? '').isNotEmpty)
            _ComponentCheckBullet(
              label: 'Kesesuaian Menu',
              detail: cloudResult!.menuMatchNote!,
            ),
          if (cloudResult!.anomaliesFound.isNotEmpty)
            _ComponentCheckBullet(
              label: 'Temuan Utama',
              detail: cloudResult!.anomaliesFound.join('; '),
            ),
          if (verdict.helperNote != null &&
              verdict.helperNote != verdict.summary) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(verdict.helperNote!, style: AppTypography.captionMuted),
          ],
        ],
      );
    } else if (verdict.helperNote != null &&
        verdict.helperNote != verdict.summary) {
      detailsWidget = Text(
        verdict.helperNote!,
        style: AppTypography.captionMuted,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWarningOrDanger
                            ? Icons.warning_amber_rounded
                            : Icons.fact_check_rounded,
                        size: 20,
                        color: titleColor,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          verdict.statusTitle,
                          style: AppTypography.titleItem.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isRunningOnDevice &&
                      !isRunningCloud &&
                      onDeviceResult != null)
                    LacakStatusTag(
                      level: verdict.level,
                      label: verdict.badgeLabel,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isRunningOnDevice) ...[
                const LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceBase,
                  minHeight: 3,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Memeriksa kondisi makanan dari foto...',
                  style: AppTypography.bodyMedium,
                ),
              ] else ...[
                ExpandableAuditSummary(
                  title: 'Ringkasan Pemeriksaan',
                  text: verdict.summary,
                  collapsedMaxLines: 3,
                  extraDetails: detailsWidget,
                ),
                if (isRunningCloud) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceBase,
                    minHeight: 3,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Menyempurnakan pemeriksaan lanjutan...',
                    style: AppTypography.captionMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LacakSecondaryButton(
                    label: 'Lewati & Gunakan Cek Manual',
                    onPressed: onSkipCloud,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (!isRunningCloud &&
            cloudResult != null &&
            cloudResult!.ok &&
            cloudResult!.hasMenuMismatch) ...[
          const SizedBox(height: AppSpacing.md),
          LacakStatusBanner(
            level: LacakStatusLevel.warning,
            title: cloudResult!.menuMatch == MenuMatchStatus.mismatch
                ? 'Isi Tidak Sesuai Menu'
                : 'Sebagian Menu Tidak Sesuai',
            description: (cloudResult!.menuMatchNote ?? '').isNotEmpty
                ? cloudResult!.menuMatchNote!
                : 'Isi ompreng tampak berbeda dari menu pada label QR. Catatan ini tersimpan pada hasil pemeriksaan dan dapat dikonfirmasi ke Dapur SPPG.',
          ),
        ],
      ],
    );
  }
}

class _ComponentCheckBullet extends StatelessWidget {
  const _ComponentCheckBullet({
    required this.label,
    required this.detail,
  });

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: RichText(
        text: TextSpan(
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: detail),
          ],
        ),
      ),
    );
  }
}

class _ManualCheckQuestionRow extends StatelessWidget {
  const _ManualCheckQuestionRow({
    required this.question,
    required this.safeLabel,
    required this.issueLabel,
    required this.value,
    required this.onSelect,
  });

  final String question;
  final String safeLabel;
  final String issueLabel;
  final bool? value;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question, style: AppTypography.titleItem),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 320 || textScale >= 1.25;
              final safeChip = _ChecklistToggleChip(
                label: safeLabel,
                selected: value == true,
                isIssue: false,
                onTap: () => onSelect(true),
              );
              final issueChip = _ChecklistToggleChip(
                label: issueLabel,
                selected: value == false,
                isIssue: true,
                onTap: () => onSelect(false),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    safeChip,
                    const SizedBox(height: AppSpacing.sm),
                    issueChip,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: safeChip),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: issueChip),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChecklistToggleChip extends StatelessWidget {
  const _ChecklistToggleChip({
    required this.label,
    required this.selected,
    required this.isIssue,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isIssue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (isIssue ? AppColors.emergencyBg : AppColors.primary)
        : AppColors.surfaceSoft;
    final fgColor = selected ? AppColors.onPrimary : AppColors.chipInactiveText;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? (isIssue
                              ? Icons.dangerous_rounded
                              : Icons.check_circle_rounded)
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: fgColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelTag.copyWith(
                        color: fgColor,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

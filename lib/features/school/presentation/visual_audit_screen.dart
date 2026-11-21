import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/media/live_camera_webp_service.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hybrid_vision_service.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G04: Langkah 2 dari 3 - Hybrid Visual Organoleptic Audit (TFLite Isolate + Gemini Edge Function + 3-Tap Manual Checklist).
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
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Cek Kondisi Makanan')),
      body: SafeArea(
        child: ctx == null
            ? Padding(
                padding: EdgeInsets.all(horizontalPad),
                child: LacakErrorState(
                  title: 'Data pemeriksaan belum tersedia',
                  message:
                      'Pindai ulang Kode QR makanan masuk dari Beranda Sekolah.',
                  onRetry: () => context.go(AppRoutes.schoolHome),
                  retryLabel: 'Kembali ke Beranda',
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
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
                              Text(
                                'Langkah 2 dari 3: Cek Kondisi Makanan',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${ctx.payload.menuName} · ${ctx.payload.batchCode}',
                                style: AppTypography.tabular(
                                  AppTypography.bodyMedium,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Container(
                                constraints: _samplePhoto == null
                                    ? const BoxConstraints(minHeight: 152)
                                    : const BoxConstraints(
                                        minHeight: 152,
                                        maxHeight: 220,
                                      ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusControl,
                                  ),
                                  border: Border.all(
                                    color: AppColors.borderHairline,
                                    width: 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _samplePhoto == null
                                    ? Padding(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.lg,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.photo_camera_rounded,
                                              size: 36,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            Text(
                                              'Potret 1 Porsi Sampel Makanan',
                                              textAlign: TextAlign.center,
                                              style: AppTypography.titleItem,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              'Gunakan kamera langsung untuk pra-skrining visual cepat dan bukti inspeksi sekolah.',
                                              textAlign: TextAlign.center,
                                              style: AppTypography.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      )
                                    : Image.memory(
                                        _samplePhoto!.bytes,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LacakSecondaryButton(
                                label: _samplePhoto == null
                                    ? 'Ambil Foto Sampel'
                                    : 'Foto Ulang',
                                icon: Icons.photo_camera_rounded,
                                isLoading: _capturing,
                                onPressed: () => _captureSamplePhoto(ctx),
                              ),
                              if (_samplePhoto != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'Hasil Pemeriksaan Foto',
                                  style: AppTypography.titleSection,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _UnifiedPhotoAuditCard(
                                  isRunningOnDevice: _runningOnDevice,
                                  isRunningCloud: _runningCloud,
                                  onDeviceResult: _onDeviceResult,
                                  cloudResult: _cloudResult,
                                  onSkipCloud: _skipCloudAndUseManual,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Pemeriksaan Manual Kondisi Makanan (Wajib)',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              LacakSectionSurface.separated(
                                children: [
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
                                ],
                              ),
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
                                        style: AppTypography.bodyMedium
                                            .copyWith(
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
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceBase,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.borderHairline,
                          width: 1,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      AppSpacing.md,
                      horizontalPad,
                      AppSpacing.md,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: _hasManualAnomaly
                            ? LacakDangerButton(
                                label:
                                    'Temukan Masalah, Hentikan & Laporkan',
                                isLoading: _submitting,
                                onPressed: () => _submitDecision(ctx),
                              )
                            : LacakPrimaryButton(
                                label: 'Makanan Aman, Lanjut Simpan Sampel',
                                icon: Icons.kitchen_rounded,
                                isLoading: _submitting,
                                onPressed: () => _submitDecision(ctx),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UnifiedPhotoAuditCard extends StatelessWidget {
  const _UnifiedPhotoAuditCard({
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
    final cloudFlagged =
        cloud != null &&
        cloud.ok &&
        ((cloud.freshnessStatus != null &&
                cloud.freshnessStatus != OnDeviceVisualLabel.freshLikely) ||
            cloud.slimeOrDiscolorationDetected == true ||
            cloud.packagingIssueDetected == true);

    if (localFlagged || cloudFlagged) {
      final isPack =
          local.label == OnDeviceVisualLabel.packagingAnomaly ||
          cloud?.packagingIssueDetected == true ||
          cloud?.freshnessStatus == OnDeviceVisualLabel.packagingAnomaly;
      final level = isPack ? LacakStatusLevel.danger : LacakStatusLevel.warning;
      final statusTitle = isPack
          ? 'PERLU CEK KEMASAN'
          : 'PERLU PERIKSA KETAT';
      final summary = cloudFlagged
          ? cloud.summaryText
          : local.summaryText;
      return (
        level: level,
        statusTitle: statusTitle,
        badgeLabel: 'PERHATIAN',
        summary: summary,
        helperNote: cloud != null && !cloud.ok
            ? 'Terdeteksi dari pemeriksaan cepat di HP. Lengkapi cek bau dan tampilan di bawah.'
            : 'Tetap pastikan bau, rasa, dan kemasan pada daftar periksa di bawah.',
      );
    }

    if (cloud != null && cloud.ok) {
      return (
        level: LacakStatusLevel.safe,
        statusTitle: 'TAMPAK WAJAR SECARA VISUAL',
        badgeLabel: 'WAJAR',
        summary: cloud.summaryText,
        helperNote:
            'Hasil pemeriksaan AI selesai. Tetap lengkapi 3 pengecekan manual di bawah.',
      );
    }

    // Offline mode keeps local quick-check verdict; online server failure never claims WAJAR falsely.
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

  bool _hasComponentDetails(CloudVisionResult cloud) {
    return (cloud.riceCheck ?? '').isNotEmpty ||
        (cloud.vegetableCheck ?? '').isNotEmpty ||
        (cloud.proteinCheck ?? '').isNotEmpty ||
        (cloud.fruitAndPackCheck ?? '').isNotEmpty;
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
      _ => AppColors.surfaceBase,
    };
    final borderColor = switch (verdict.level) {
      LacakStatusLevel.danger => AppColors.dangerBorder,
      LacakStatusLevel.warning => AppColors.warnBorder,
      LacakStatusLevel.offline => AppColors.infoBorder,
      _ => AppColors.borderHairline,
    };
    final titleColor = switch (verdict.level) {
      LacakStatusLevel.danger => AppColors.dangerFg,
      LacakStatusLevel.warning => AppColors.warnFg,
      LacakStatusLevel.offline => AppColors.infoFg,
      _ => AppColors.textPrimary,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
        border: Border.all(
          color: borderColor,
          width: isWarningOrDanger ? 1.5 : 1,
        ),
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
              if (!isRunningOnDevice && !isRunningCloud && onDeviceResult != null)
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
              backgroundColor: AppColors.surfaceSubtle,
              minHeight: 3,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Memeriksa kondisi makanan dari foto...',
              style: AppTypography.bodyMedium,
            ),
          ] else ...[
            Text(
              verdict.summary,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (!isRunningCloud &&
                cloudResult != null &&
                cloudResult!.ok &&
                _hasComponentDetails(cloudResult!)) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusControl,
                  ),
                  border: Border.all(
                    color: AppColors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Rincian Pemeriksaan AI per Komponen',
                      style: AppTypography.labelTag.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
                  ],
                ),
              ),
            ],
            if (isRunningCloud) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceSubtle,
                minHeight: 3,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Menyempurnakan pemeriksaan lanjutan...',
                style: AppTypography.captionLegal.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LacakSecondaryButton(
                label: 'Lewati & Gunakan Cek Manual',
                onPressed: onSkipCloud,
              ),
            ] else if (verdict.helperNote != null &&
                verdict.helperNote != verdict.summary) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                verdict.helperNote!,
                style: AppTypography.captionLegal.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question, style: AppTypography.titleItem),
          const SizedBox(height: AppSpacing.sm),
          _ChecklistChoiceButton(
            label: safeLabel,
            selected: value == true,
            isIssue: false,
            onTap: () => onSelect(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChecklistChoiceButton(
            label: issueLabel,
            selected: value == false,
            isIssue: true,
            onTap: () => onSelect(false),
          ),
        ],
      ),
    );
  }
}

class _ChecklistChoiceButton extends StatelessWidget {
  const _ChecklistChoiceButton({
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
        ? (isIssue ? AppColors.dangerBg : AppColors.primaryTint)
        : AppColors.surfaceBase;
    final borderColor = selected
        ? (isIssue ? AppColors.dangerFg : AppColors.primary)
        : AppColors.borderHairline;
    final fgColor = selected
        ? (isIssue ? AppColors.dangerFg : AppColors.onPrimaryTint)
        : AppColors.textPrimary;

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? (isIssue
                            ? Icons.dangerous_rounded
                            : Icons.check_circle_rounded)
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? fgColor : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.left,
                    style: AppTypography.labelButton.copyWith(
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
    );
  }
}

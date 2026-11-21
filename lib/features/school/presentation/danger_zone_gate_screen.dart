import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G03: Langkah 1 dari 3 - Danger-Zone Clock & BMKG weather inspection gate.
class DangerZoneGateScreen extends ConsumerStatefulWidget {
  const DangerZoneGateScreen({super.key, this.scanContext});

  final VerifiedBatchScanContext? scanContext;

  @override
  ConsumerState<DangerZoneGateScreen> createState() =>
      _DangerZoneGateScreenState();
}

class _DangerZoneGateScreenState extends ConsumerState<DangerZoneGateScreen> {
  bool _savingStop = false;

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

  LacakStatusLevel _bannerLevel(DangerZoneStatus status) {
    switch (status) {
      case DangerZoneStatus.green:
        return LacakStatusLevel.safe;
      case DangerZoneStatus.yellow:
        return LacakStatusLevel.warning;
      case DangerZoneStatus.red:
        return LacakStatusLevel.danger;
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
      appBar: AppBar(title: const Text('Cek Waktu & Suhu')),
      body: SafeArea(
        child: ctx == null
            ? Padding(
                padding: EdgeInsets.all(horizontalPad),
                child: LacakErrorState(
                  title: 'Data QR belum tersedia',
                  message:
                      'Silakan pindai ulang Kode QR makanan masuk dari Beranda Sekolah.',
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
                                'Langkah 1 dari 3: Cek Waktu & Suhu',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LacakStatusBanner(
                                level: _bannerLevel(
                                  ctx.dangerEvaluation.status,
                                ),
                                title: ctx.dangerEvaluation.status.bannerTitle,
                                description: ctx.dangerEvaluation.explanation,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Rincian Verifikasi Pengiriman',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              LacakSectionSurface.separated(
                                children: [
                                  _GateDetailRow(
                                    label: 'Menu Makanan',
                                    value: ctx.payload.menuName,
                                  ),
                                  _GateDetailRow(
                                    label: 'Dapur SPPG',
                                    value: ctx.sppgName,
                                    subtitle: 'Segel Digital Asli',
                                  ),
                                  _GateDetailRow(
                                    label: 'Kode Batch',
                                    value: ctx.payload.batchCode,
                                    tabular: true,
                                  ),
                                  _GateDetailRow(
                                    label: 'Jam Segel Dapur',
                                    value: formatWibDateTime(ctx.sealedAtUtc),
                                    subtitle: ctx.timestampSource.label,
                                    tabular: true,
                                  ),
                                  _GateDetailRow(
                                    label: 'Durasi di Perjalanan',
                                    value: formatDurationMinutes(
                                      ctx.dangerEvaluation.elapsedMinutes,
                                    ),
                                    tabular: true,
                                  ),
                                  _GateDetailRow(
                                    label: 'Kategori Risiko Menu',
                                    value: ctx.riskCategory.label,
                                  ),
                                  _GateDetailRow(
                                    label: 'Suhu Wilayah',
                                    value:
                                        '${ctx.weather.formattedTemperature} · ${ctx.weather.source.label}',
                                    subtitle: AppConstants.bmkgShortAttribution,
                                    tabular: true,
                                  ),
                                  _GateDetailRow(
                                    label: 'Status Lokasi Sekolah',
                                    value: ctx.gpsWithinRadius
                                        ? 'Dalam area sekolah (<= 500 m)'
                                        : 'Di luar radius GPS profil (${ctx.distanceMeters?.round() ?? 0} m). Penerimaan tetap dapat dilanjutkan.',
                                    tabular: true,
                                  ),
                                ],
                              ),
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
                        child: ctx.dangerEvaluation.status ==
                                DangerZoneStatus.red
                            ? LacakDangerButton(
                                label: 'Hentikan Distribusi & Buat Laporan',
                                isLoading: _savingStop,
                                onPressed: () => _stopAndReport(
                                  ctx,
                                  reasonSummary:
                                      'Durasi perjalanan (${formatDurationMinutes(ctx.dangerEvaluation.elapsedMinutes)}) melewati batas aman pada suhu ${ctx.weather.formattedTemperature}.',
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LacakPrimaryButton(
                                    label: 'Lanjut: Foto Sampel Makanan',
                                    icon: Icons.photo_camera_rounded,
                                    isLoading: _savingStop,
                                    onPressed: () => context.push(
                                      AppRoutes.schoolVisualAudit,
                                      extra: ctx,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  TextButton(
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
                                    child: const Text(
                                      'Makanan tercium basi? Laporkan sekarang',
                                    ),
                                  ),
                                ],
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

class _GateDetailRow extends StatelessWidget {
  const _GateDetailRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTypography.captionLegal.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.left,
            style: tabular
                ? AppTypography.tabular(AppTypography.titleItem)
                : AppTypography.titleItem,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              textAlign: TextAlign.left,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

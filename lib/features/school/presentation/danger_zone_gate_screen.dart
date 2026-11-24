import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
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
                                label: ctx.weather.formattedTemperature,
                              ),
                            ],
                          ),
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
                              label: 'Suhu Wilayah',
                              value:
                                  '${ctx.weather.formattedTemperature} · ${ctx.weather.source.label}',
                              subtitle: AppConstants.bmkgShortAttribution,
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
                        'Durasi perjalanan (${formatDurationMinutes(ctx.dangerEvaluation.elapsedMinutes)}) melewati batas aman pada suhu ${ctx.weather.formattedTemperature}.',
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

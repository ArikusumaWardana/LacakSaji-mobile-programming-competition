import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/sync/offline_sync_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_offline_bar.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_sync_queue_sheet.dart';
import '../../alerts/data/cluster_alert_repository.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../data/klb_pdf_service.dart';
import '../domain/danger_zone_calculator.dart';

/// G07 (Laporan Instan Puskesmas): 1-page KLB PDF generator and 1-tap WhatsApp dispatch.
class PuskesmasReportDraftScreen extends ConsumerStatefulWidget {
  const PuskesmasReportDraftScreen({super.key, this.args});

  final PuskesmasDraftArgs? args;

  @override
  ConsumerState<PuskesmasReportDraftScreen> createState() =>
      _PuskesmasReportDraftScreenState();
}

class _PuskesmasReportDraftScreenState
    extends ConsumerState<PuskesmasReportDraftScreen> {
  bool _sendingPdf = false;
  bool _openingWa = false;
  late bool _pdfDispatched;

  @override
  void initState() {
    super.initState();
    _pdfDispatched = widget.args?.initialPdfDispatched ?? false;
  }

  Future<void> _sendPdfAndSummary(
    PuskesmasDraftArgs args,
    String schoolId,
  ) async {
    if (_sendingPdf) {
      return;
    }
    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() => _sendingPdf = true);
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    try {
      await ref.read(klbReportPdfServiceProvider).generateAndSharePdfToWhatsApp(
            args: args,
            school: school,
          );
      await ref.read(clusterAlertRepositoryProvider).markPdfDispatched(
            alertId: args.alertId,
            reporterSchoolId: schoolId,
            isOffline: isOffline,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingPdf = false;
        _pdfDispatched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            'PDF Berita Acara KLB siap dibagikan ke WhatsApp atau Email Puskesmas.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _sendingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyiapkan file PDF laporan: $error')),
      );
    }
  }

  Future<void> _openDirectWaChat(
    PuskesmasDraftArgs args,
    String puskesmasWa,
    String summaryText,
  ) async {
    if (_openingWa) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _openingWa = true);
    final launched = await ref
        .read(klbReportPdfServiceProvider)
        .openDirectWhatsAppChat(
          puskesmasWa: puskesmasWa,
          summaryText: summaryText,
        );
    if (!mounted) {
      return;
    }
    setState(() => _openingWa = false);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aplikasi WhatsApp tidak tersedia. Gunakan tombol Kirim PDF di atas atau hubungi $puskesmasWa.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final school = ref.watch(authControllerProvider).school;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingSyncCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);

    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    final summaryText = (args != null && school != null)
        ? ref.read(klbReportPdfServiceProvider).buildWhatsAppSummaryText(
              args: args,
              school: school,
            )
        : '';

    final hasLocalPhoto = args?.localPhotoPath != null &&
        args!.localPhotoPath!.isNotEmpty &&
        File(args.localPhotoPath!).existsSync();

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Draf Laporan Puskesmas')),
      body: SafeArea(
        child: Column(
          children: [
            LacakOfflineBar(
              isOffline: isOffline,
              pendingSyncCount: pendingSyncCount,
              isSyncing: syncState.isSyncing,
              statusErrorMessage: syncState.lastError,
              onSyncTap: () => runInteractiveSyncWithFeedback(context, ref),
              onInspectTap: () => showPendingSyncQueueSheet(context, ref),
            ),
            Expanded(
              child: args == null || school == null
                  ? SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPad),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: LacakErrorState(
                            title: 'Draf laporan belum tersedia',
                            message:
                                'Buat laporan terlebih dahulu dari pemeriksaan batch hari ini.',
                            onRetry: () => context.go(AppRoutes.schoolHome),
                            retryLabel: 'Kembali ke Beranda Sekolah',
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        AppSpacing.lg,
                        horizontalPad,
                        96,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LacakStatusBanner(
                                level: _pdfDispatched
                                    ? LacakStatusLevel.safe
                                    : LacakStatusLevel.danger,
                                title: _pdfDispatched
                                    ? 'Berita Acara KLB Telah Dibagikan'
                                    : 'Berita Acara KLB Siap Kirim (PDF 1 Halaman)',
                                description: args.isPendingSync
                                    ? 'Laporan tersimpan aman di HP dan akan otomatis dikirim ke server serta sekolah mitra saat sinyal kembali.'
                                    : 'Ringkasan kronologi waktu-suhu, foto sampel, dan Kode Bank Sampel siap dikirim ke WhatsApp Puskesmas.',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Ringkasan Isi PDF Berita Acara',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              LacakSectionSurface.separated(
                                children: [
                                  _DraftRow(
                                    label: 'Nomor WA Puskesmas',
                                    value: school.puskesmasWa,
                                    tabular: true,
                                  ),
                                  _DraftRow(
                                    label: 'Menu & Kode Batch',
                                    value: '${args.menuName}\n(${args.batchCode})',
                                    tabular: true,
                                  ),
                                  _DraftRow(
                                    label: 'Dapur SPPG',
                                    value: args.sppgName,
                                  ),
                                  _DraftRow(
                                    label: 'Kronologi Waktu',
                                    value:
                                        'Segel: ${formatWibDateTime(args.sealedAtUtc)}\nTerima: ${formatWibDateTime(args.scannedAtUtc)}\nDurasi: ${formatDurationMinutes(args.elapsedMinutes)}',
                                    tabular: true,
                                  ),
                                  _DraftRow(
                                    label: 'Suhu Wilayah',
                                    value:
                                        '${args.bmkgTempC.toStringAsFixed(1)} C (${AppConstants.bmkgShortAttribution})',
                                    tabular: true,
                                  ),
                                  _DraftRow(
                                    label: 'Kode Label Bank Sampel',
                                    value: (args.sampleLabelCode != null &&
                                            args.sampleLabelCode!.isNotEmpty)
                                        ? args.sampleLabelCode!
                                        : 'Tidak ada (dihentikan pra-sampel)',
                                    tabular: true,
                                  ),
                                ],
                              ),
                              if (hasLocalPhoto) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'Foto Sampel Terlampir dalam PDF',
                                  style: AppTypography.titleItem,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusControl,
                                    ),
                                    border: Border.all(
                                      color: AppColors.borderHairline,
                                      width: 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.file(
                                    File(args.localPhotoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Pratinjau Pesan Ringkasan WhatsApp',
                                style: AppTypography.titleItem,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusControl,
                                  ),
                                ),
                                child: Text(
                                  summaryText,
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              LacakPrimaryButton(
                                label:
                                    'Kirim PDF & Ringkasan ke WhatsApp Puskesmas',
                                icon: Icons.picture_as_pdf_rounded,
                                isLoading: _sendingPdf,
                                minHeight: AppSpacing.heroCtaMinHeight,
                                onPressed: () =>
                                    _sendPdfAndSummary(args, school.id),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LacakSecondaryButton(
                                label:
                                    'Buka Chat WA Puskesmas (${school.puskesmasWa})',
                                icon: Icons.share_rounded,
                                isLoading: _openingWa,
                                onPressed: () => _openDirectWaChat(
                                  args,
                                  school.puskesmasWa,
                                  summaryText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LacakSecondaryButton(
                                label: 'Kembali ke Beranda Sekolah',
                                icon: Icons.home_rounded,
                                onPressed: () => context.go(AppRoutes.schoolHome),
                              ),
                            ],
                          ),
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

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final String label;
  final String value;
  final bool tabular;

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
              style: tabular
                  ? AppTypography.tabular(AppTypography.titleItem)
                  : AppTypography.titleItem,
            ),
          ),
        ],
      ),
    );
  }
}

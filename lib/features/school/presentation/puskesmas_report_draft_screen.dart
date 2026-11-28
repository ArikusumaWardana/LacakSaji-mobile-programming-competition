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
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_offline_bar.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_sync_queue_sheet.dart';
import '../../alerts/data/cluster_alert_repository.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../../traceability/presentation/traceability_providers.dart';
import '../data/klb_pdf_service.dart';
import '../domain/danger_zone_calculator.dart';

/// G06b / G07 (Laporan Instan Puskesmas): Editorial 1-page KLB PDF generator
/// with borderless summary, 20dp framed evidence photo, and StickyBottomActionBar.
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
  bool _sharingOther = false;
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
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            'PDF Berita Acara KLB dan pesan ringkasan diarahkan ke WhatsApp Puskesmas (${school.formattedPuskesmasWa}).',
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

  Future<void> _shareToOtherApps(
    PuskesmasDraftArgs args,
    String schoolId,
  ) async {
    if (_sharingOther) {
      return;
    }
    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() => _sharingOther = true);
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    try {
      await ref.read(klbReportPdfServiceProvider).sharePdfToOtherApps(
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
        _sharingOther = false;
        _pdfDispatched = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _sharingOther = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membagikan file PDF: $error')),
      );
    }
  }

  Future<void> _openDirectWaChat(
    PuskesmasDraftArgs args,
    String puskesmasWaRaw,
    String formattedWa,
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
          puskesmasWa: puskesmasWaRaw,
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
            'Aplikasi WhatsApp tidak tersedia. Gunakan tombol Bagikan PDF di bawah atau hubungi $formattedWa.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = widget.args;
    final school = ref.watch(authControllerProvider).school;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingSyncCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);

    final liveIngredients = rawArgs != null
        ? ref
              .watch(
                batchIngredientLogsProvider((
                  sppgId: rawArgs.sppgId,
                  batchId: rawArgs.batchId,
                )),
              )
              .value
        : null;
    final liveTimeline = rawArgs != null
        ? ref
              .watch(
                batchSupplyChainTimelineProvider((
                  sppgId: rawArgs.sppgId,
                  batchId: rawArgs.batchId,
                  sealedAtUtc: rawArgs.sealedAtUtc,
                  schoolScannedAtUtc: rawArgs.scannedAtUtc,
                )),
              )
              .value
        : null;

    final args = rawArgs?.withTraceability(
      ingredientLogs: rawArgs.ingredientLogs.isNotEmpty
          ? rawArgs.ingredientLogs
          : liveIngredients,
      transitHandover: rawArgs.transitHandover ?? liveTimeline?.handover,
    );

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

    final hasSampleLabel = args?.sampleLabelCode != null &&
        args!.sampleLabelCode!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    AppSpacing.md,
                    horizontalPad,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: AppColors.surfaceSoft,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: 'Kembali',
                          constraints: const BoxConstraints(
                            minWidth: AppSpacing.minTouchTarget,
                            minHeight: AppSpacing.minTouchTarget,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 19,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Berita Acara KLB',
                              style: AppTypography.captionMuted,
                            ),
                            Text(
                              'Draf Laporan Puskesmas',
                              style: AppTypography.headlinePage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                LacakOfflineBar(
                  isOffline: isOffline,
                  pendingSyncCount: pendingSyncCount,
                  isSyncing: syncState.isSyncing,
                  statusErrorMessage: syncState.lastError,
                  onSyncTap: () => runInteractiveSyncWithFeedback(context, ref),
                  onInspectTap: () => showPendingSyncQueueSheet(context, ref),
                ),
              ],
            ),
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
                      AppSpacing.md,
                      horizontalPad,
                      AppSpacing.xxl,
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
                                  : LacakStatusLevel.warning,
                              icon: _pdfDispatched
                                  ? Icons.check_circle_rounded
                                  : Icons.picture_as_pdf_rounded,
                              title: _pdfDispatched
                                  ? 'Berita Acara KLB Telah Dibagikan'
                                  : 'Berita Acara KLB Siap Kirim (PDF 1 Halaman)',
                              description: args.isPendingSync
                                  ? 'Laporan tersimpan aman di HP dan akan otomatis dikirim ke server serta sekolah mitra saat sinyal kembali.'
                                  : 'Kronologi waktu-suhu, foto sampel, dan Kode Bank Sampel siap dikirim langsung ke WhatsApp Puskesmas.',
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Ringkasan Isi PDF Berita Acara',
                              style: AppTypography.titleSection,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    args.menuName,
                                    style: AppTypography.titleItem.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${args.batchCode} · ${args.sppgName}',
                                    style: AppTypography.tabular(
                                      AppTypography.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            _DraftStackedRow(
                              label: 'Nomor WA Puskesmas',
                              value: school.formattedPuskesmasWa,
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kronologi Waktu',
                                    style: AppTypography.captionMuted,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _TimelineMiniRow(
                                    label: 'Jam Segel Dapur',
                                    value: formatWibDateTime(args.sealedAtUtc),
                                  ),
                                  const SizedBox(height: 4),
                                  _TimelineMiniRow(
                                    label: 'Jam Terima Sekolah',
                                    value: formatWibDateTime(args.scannedAtUtc),
                                  ),
                                  const SizedBox(height: 4),
                                  _TimelineMiniRow(
                                    label: 'Durasi Distribusi',
                                    value: formatDurationMinutes(
                                      args.elapsedMinutes,
                                    ),
                                  ),
                                  if (args.transitHandover != null) ...[
                                    const SizedBox(height: 4),
                                    _TimelineMiniRow(
                                      label: 'Durasi Transit Kurir',
                                      value: args.transitHandover!
                                                  .transitDurationMinutes !=
                                              null
                                          ? formatDurationMinutes(
                                              args.transitHandover!
                                                  .transitDurationMinutes!,
                                            )
                                          : 'Dimuat ${formatWibTime(args.transitHandover!.effectiveDepartedAtUtc)}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            _DraftStackedRow(
                              label: 'Riwayat Hulu Bahan Baku',
                              value: args.ingredientLogs.isEmpty
                                  ? 'Belum ada log pemasok bahan tertaut'
                                  : args.ingredientLogs
                                        .take(4)
                                        .map(
                                          (item) =>
                                              '${item.ingredientName} (${item.supplierName}, Lot ${item.supplierBatchNo}, Exp ${item.formattedExpiryDate})',
                                        )
                                        .join('; '),
                              mutedValue: args.ingredientLogs.isEmpty,
                            ),
                            const Divider(height: 1),
                            _DraftStackedRow(
                              label: 'Suhu Wilayah',
                              value: '${args.bmkgTempC.toStringAsFixed(1)} C',
                              caption:
                                  '${args.bmkgSource.label} · ${AppConstants.bmkgShortAttribution}',
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            _DraftStackedRow(
                              label: 'Kode Label Bank Sampel',
                              value: hasSampleLabel
                                  ? args.sampleLabelCode!.trim()
                                  : 'Tidak ada (dihentikan pra-sampel)',
                              tabular: true,
                              highlightValue: hasSampleLabel,
                              mutedValue: !hasSampleLabel,
                            ),
                            const Divider(height: 1),
                            if (hasLocalPhoto) ...[
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Foto Sampel Terlampir dalam PDF',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusHero,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Image.file(
                                    File(args.localPhotoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Foto bukti lapangan ini otomatis dimasukkan ke halaman PDF Berita Acara.',
                                style: AppTypography.captionLegal,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Pratinjau Pesan Ringkasan WhatsApp',
                              style: AppTypography.titleSection,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSurface,
                                ),
                              ),
                              child: _WhatsAppFormattedPreview(
                                text: summaryText,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            LacakSecondaryButton(
                              label:
                                  'Buka Chat WA Puskesmas (${school.formattedPuskesmasWa})',
                              icon: Icons.chat_rounded,
                              isLoading: _openingWa,
                              onPressed: () => _openDirectWaChat(
                                args,
                                school.puskesmasWa,
                                school.formattedPuskesmasWa,
                                summaryText,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Center(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    AppSpacing.minTouchTarget,
                                    AppSpacing.minTouchTarget,
                                  ),
                                  foregroundColor: AppColors.primary,
                                ),
                                onPressed: _sharingOther
                                    ? null
                                    : () => _shareToOtherApps(args, school.id),
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: Text(
                                  _sharingOther
                                      ? 'Menyiapkan file PDF...'
                                      : 'Bagikan PDF ke Email / Aplikasi Lain',
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
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
          if (args != null && school != null)
            StickyBottomActionBar(
              summaryLabel: 'WA Puskesmas',
              summaryValue: school.formattedPuskesmasWa,
              ctaLabel: 'Kirim WA + PDF',
              ctaIcon: Icons.picture_as_pdf_rounded,
              isLoading: _sendingPdf,
              onCtaPressed: () => _sendPdfAndSummary(args, school.id),
            ),
        ],
      ),
    );
  }
}

class _DraftStackedRow extends StatelessWidget {
  const _DraftStackedRow({
    required this.label,
    required this.value,
    this.caption,
    this.tabular = false,
    this.highlightValue = false,
    this.mutedValue = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool tabular;
  final bool highlightValue;
  final bool mutedValue;

  @override
  Widget build(BuildContext context) {
    final baseStyle = mutedValue
        ? AppTypography.bodyMedium
        : AppTypography.titleItem.copyWith(
            color: highlightValue ? AppColors.primary : AppColors.textPrimary,
            fontWeight: highlightValue ? FontWeight.w700 : FontWeight.w600,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.captionMuted),
          const SizedBox(height: 2),
          Text(
            value,
            style: tabular ? AppTypography.tabular(baseStyle) : baseStyle,
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(caption!, style: AppTypography.captionLegal),
          ],
        ],
      ),
    );
  }
}

class _TimelineMiniRow extends StatelessWidget {
  const _TimelineMiniRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 2,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.tabular(
            AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders WhatsApp `*bold*` and `_italic_` markup cleanly in the on-screen preview.
class _WhatsAppFormattedPreview extends StatelessWidget {
  const _WhatsAppFormattedPreview({required this.text});

  final String text;

  static final RegExp _tokenPattern = RegExp(
    r'(\*[^*\n]+\*|_[^_\n]+_)',
  );

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTypography.bodyMedium.copyWith(
      color: AppColors.textPrimary,
      height: 1.5,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('*') && token.endsWith('*')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('_') && token.endsWith('_')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }
}

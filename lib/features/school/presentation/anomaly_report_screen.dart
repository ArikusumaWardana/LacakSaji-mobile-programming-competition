import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/bmkg_weather_service.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/sync/offline_sync_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_offline_bar.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_sync_queue_sheet.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../alerts/data/cluster_alert_repository.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../../traceability/domain/traceability_models.dart';
import '../../traceability/presentation/traceability_providers.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G06: Editorial Anti-hoaks Anomaly / KLB Report screen with borderless layout
/// and StickyBottomActionBar.
class AnomalyReportScreen extends ConsumerStatefulWidget {
  const AnomalyReportScreen({super.key, this.args});

  final AnomalyHandoffArgs? args;

  @override
  ConsumerState<AnomalyReportScreen> createState() =>
      _AnomalyReportScreenState();
}

class _AnomalyReportScreenState extends ConsumerState<AnomalyReportScreen> {
  late ClusterAlertStage _stage;
  int _symptomCount = 1;
  bool _broadcastEnabled = true;
  bool _submitting = false;
  String? _resolvedSampleLabel;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stage = widget.args?.initialStage ?? ClusterAlertStage.preConsumption;
    _resolvedSampleLabel = widget.args?.sampleLabelCode;
    if (_resolvedSampleLabel == null && widget.args != null) {
      Future.microtask(_loadSampleLabel);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSampleLabel() async {
    final args = widget.args;
    final school = ref.read(authControllerProvider).school;
    if (args == null || school == null) {
      return;
    }
    try {
      final found = await ref
          .read(clusterAlertRepositoryProvider)
          .findSampleLabelForInspection(
            schoolId: school.id,
            inspectionId: args.inspectionId,
          );
      if (mounted && found != null && found.isNotEmpty) {
        setState(() => _resolvedSampleLabel = found);
      }
    } catch (_) {
      // Optional lookup.
    }
  }

  bool _isBatchWithin48hWindow(AnomalyHandoffArgs? args) {
    if (args == null ||
        args.batchId.trim().isEmpty ||
        args.inspectionId.trim().isEmpty) {
      return false;
    }
    final anchorUtc = (args.scannedAtUtc ?? args.sealedAtUtc).toUtc();
    final elapsed = DateTime.now().toUtc().difference(anchorUtc);
    return elapsed <= const Duration(hours: 48) &&
        elapsed >= const Duration(hours: -2);
  }

  Future<void> _submitReport(AnomalyHandoffArgs args) async {
    if (_submitting) {
      return;
    }
    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }
    final sppgId = args.sppgId ?? school.sppgId ?? '';
    if (sppgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sekolah belum memiliki mitra Dapur SPPG aktif.'),
        ),
      );
      return;
    }

    final confirmMessage = _broadcastEnabled
        ? 'Laporan ini akan menyiapkan Berita Acara PDF 1 halaman untuk Puskesmas dan mengirim Peringatan Darurat ke sekolah lain yang disuplai ${args.sppgName}. Lanjutkan?'
        : 'Laporan ini akan mencatat penahanan distribusi dan menyiapkan Berita Acara PDF 1 halaman untuk Puskesmas. Lanjutkan?';

    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: 'Kirim Peringatan & Siapkan PDF?',
      message: confirmMessage,
      confirmLabel: 'Ya, Kirim & Siapkan PDF',
      isDanger: true,
      confirmIcon: Icons.notification_important_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    try {
      final event = await ref
          .read(clusterAlertRepositoryProvider)
          .submitClusterAlert(
            school: school,
            sppgId: sppgId,
            sppgName: args.sppgName,
            batchId: args.batchId,
            batchCode: args.batchCode,
            menuName: args.menuName,
            inspectionId: args.inspectionId,
            stage: _stage,
            symptomCount: _stage == ClusterAlertStage.postConsumption
                ? _symptomCount
                : 0,
            broadcastEnabled: _broadcastEnabled,
            isOffline: isOffline,
            notes: _notesController.text.trim(),
            sampleLabelCode: _resolvedSampleLabel,
          );
      invalidateSchoolProviders(ref);
      if (!mounted) {
        return;
      }

      final scannedAt = args.scannedAtUtc ?? DateTime.now().toUtc();
      final elapsed = args.elapsedMinutes ??
          scannedAt
              .difference(args.sealedAtUtc.toUtc())
              .inMinutes
              .clamp(0, 1440);
      List<IngredientLogItem> ingredientLogs = const [];
      TransitHandoverItem? transitHandover;
      try {
        final traceRepo = ref.read(traceabilityRepositoryProvider);
        ingredientLogs = await traceRepo.fetchIngredientLogsByBatch(
          sppgId: sppgId,
          batchId: args.batchId,
        );
        final timeline = await traceRepo.fetchSupplyChainTimeline(
          sppgId: sppgId,
          batchId: args.batchId,
          sealedAtUtc: args.sealedAtUtc,
          schoolScannedAtUtc: scannedAt,
        );
        transitHandover = timeline.handover;
      } catch (_) {
        // Non-blocking lookup: never delay emergency alert PDF creation.
      }
      if (!mounted) {
        return;
      }
      final draftArgs = PuskesmasDraftArgs(
        alertId: event.id,
        batchId: args.batchId,
        batchCode: args.batchCode,
        menuName: args.menuName,
        sppgId: sppgId,
        sppgName: args.sppgName,
        sealedAtUtc: args.sealedAtUtc,
        scannedAtUtc: scannedAt,
        elapsedMinutes: elapsed,
        bmkgTempC: args.bmkgTempC,
        bmkgSource: args.bmkgSource ?? BmkgSource.fallbackOffline,
        dangerStatus: args.dangerStatus ?? DangerZoneStatus.red,
        stage: _stage,
        symptomCount:
            _stage == ClusterAlertStage.postConsumption ? _symptomCount : 0,
        notes: event.notes,
        reasonSummary: args.reasonSummary,
        localPhotoPath: args.localPhotoPath,
        sampleLabelCode: event.sampleLabelCode ?? _resolvedSampleLabel,
        broadcastEnabled: _broadcastEnabled,
        isPendingSync: event.isPendingSync,
        reportedAtUtc: event.createdAtUtc,
        ingredientLogs: ingredientLogs,
        transitHandover: transitHandover,
      );

      context.pushReplacement(
        AppRoutes.schoolPuskesmasDraft,
        extra: draftArgs,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim laporan darurat: $error')),
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
    final validWindow = _isBatchWithin48hWindow(args);

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
                              'Penahanan & KLB',
                              style: AppTypography.captionMuted,
                            ),
                            Text(
                              'Lapor Anomali Pangan',
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
            child: !validWindow || args == null
                ? SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPad),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: LacakErrorState(
                          title: 'Akses Pelaporan Terkunci',
                          message:
                              'Laporan darurat hanya dapat dibuat dari batch makanan yang telah dipindai dan diverifikasi dalam 48 jam terakhir (sesuai masa retensi Bank Sampel).',
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
                              level: LacakStatusLevel.danger,
                              title: _stage == ClusterAlertStage.postConsumption
                                  ? 'LAPORAN DUGAAN KLB PASCA-KONSUMSI'
                                  : 'DISTRIBUSI DIHENTIKAN: JANGAN DIBAGIKAN',
                              description:
                                  _stage == ClusterAlertStage.postConsumption
                                  ? 'Peringatan ini akan menyiagakan sekolah mitra lain untuk menahan kloter berikutnya dan menyiapkan Bank Sampel Puskesmas.'
                                  : args.reasonSummary,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Batch Terkunci Hari Ini',
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
                            _ReportDetailRow(
                              label: 'Jam Segel Dapur',
                              value: formatWibDateTime(args.sealedAtUtc),
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            _ReportDetailRow(
                              label: 'Suhu Wilayah',
                              value: '${args.bmkgTempC.toStringAsFixed(1)} C',
                              caption: AppConstants.bmkgShortAttribution,
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            _ReportDetailRow(
                              label: 'Kode Bank Sampel',
                              value: _resolvedSampleLabel ??
                                  'Belum ada (ditahan pra-sampel)',
                              tabular: true,
                              highlightValue: _resolvedSampleLabel != null,
                              mutedValue: _resolvedSampleLabel == null,
                            ),
                            const Divider(height: 1),
                            _ReportDetailRow(
                              label: 'WA Puskesmas Tujuan',
                              value: school?.formattedPuskesmasWa ?? '-',
                              tabular: true,
                            ),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Pilih Kondisi Pelaporan',
                              style: AppTypography.titleSection,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StageChoiceTile(
                              stage: ClusterAlertStage.preConsumption,
                              selected:
                                  _stage == ClusterAlertStage.preConsumption,
                              onTap: () => setState(
                                () => _stage = ClusterAlertStage.preConsumption,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StageChoiceTile(
                              stage: ClusterAlertStage.postConsumption,
                              selected:
                                  _stage == ClusterAlertStage.postConsumption,
                              onTap: () => setState(
                                () => _stage = ClusterAlertStage.postConsumption,
                              ),
                            ),
                            if (_stage == ClusterAlertStage.postConsumption) ...[
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Jumlah Siswa Bergejala (Tanpa Nama)',
                                style: AppTypography.titleSection,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSurface,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _StepperIconButton(
                                      icon: Icons.remove_rounded,
                                      tooltip: 'Kurangi jumlah siswa',
                                      onPressed: _symptomCount <= 1
                                          ? null
                                          : () => setState(
                                              () => _symptomCount--,
                                            ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            '$_symptomCount',
                                            style: AppTypography.tabular(
                                              AppTypography.displayStatus,
                                            ),
                                          ),
                                          Text(
                                            'siswa mengalami gejala',
                                            textAlign: TextAlign.center,
                                            style: AppTypography.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StepperIconButton(
                                      icon: Icons.add_rounded,
                                      tooltip: 'Tambah jumlah siswa',
                                      onPressed: () => setState(
                                        () => _symptomCount++,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            LacakTextField(
                              label: 'Catatan Singkat Lapangan (Opsional)',
                              controller: _notesController,
                              hintText:
                                  'Contoh: Bau asam menyengat atau gejala mual pukul 10.15 WIB',
                              maxLines: 2,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(height: 1),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              activeThumbColor: AppColors.primary,
                              title: Text(
                                'Kirim Peringatan Darurat ke Sekolah Lain',
                                style: AppTypography.titleItem,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Bunyikan alarm darurat di semua sekolah mitra dari ${args.sppgName}.',
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                              value: _broadcastEnabled,
                              onChanged: (value) => setState(
                                () => _broadcastEnabled = value,
                              ),
                            ),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.md),
                            LacakSecondaryButton(
                              label: 'Kembali ke Beranda Sekolah',
                              icon: Icons.home_rounded,
                              onPressed: _submitting
                                  ? null
                                  : () => context.go(AppRoutes.schoolHome),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (validWindow && args != null)
            StickyBottomActionBar(
              summaryLabel: 'Tindakan Darurat',
              summaryValue:
                  _broadcastEnabled ? 'Alarm & PDF KLB' : 'PDF Puskesmas',
              summaryValueColor: AppColors.dangerFg,
              ctaLabel: 'Kirim & Siapkan PDF',
              ctaIcon: Icons.notification_important_rounded,
              ctaColor: AppColors.emergencyBg,
              isLoading: _submitting,
              onCtaPressed: () => _submitReport(args),
            ),
        ],
      ),
    );
  }
}

class _StageChoiceTile extends StatelessWidget {
  const _StageChoiceTile({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final ClusterAlertStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.dangerBg : AppColors.surfaceSoft;
    final fgColor = selected ? AppColors.dangerFg : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: stage.title,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          side: selected
              ? const BorderSide(color: AppColors.dangerFg, width: 1.8)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : (stage == ClusterAlertStage.postConsumption
                              ? Icons.medical_services_rounded
                              : Icons.dangerous_rounded),
                    size: 22,
                    color: selected ? AppColors.dangerFg : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.title,
                          style: AppTypography.titleItem.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(stage.subtitle, style: AppTypography.bodyMedium),
                      ],
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

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AppSpacing.minTouchTarget,
          AppSpacing.minTouchTarget,
        ),
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        ),
      ),
      icon: Icon(icon, size: 22, color: AppColors.textPrimary),
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({
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

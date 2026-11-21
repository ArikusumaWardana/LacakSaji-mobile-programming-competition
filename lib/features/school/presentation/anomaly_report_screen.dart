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
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_offline_bar.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_sync_queue_sheet.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../alerts/data/cluster_alert_repository.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G06: Anti-hoaks Anomaly / KLB Report screen (strictly gated by today's verified QR batch).
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

  bool _isBatchVerifiedToday(AnomalyHandoffArgs? args) {
    if (args == null ||
        args.batchId.trim().isEmpty ||
        args.inspectionId.trim().isEmpty) {
      return false;
    }
    final anchorUtc = args.scannedAtUtc ?? args.sealedAtUtc;
    return isSameWibCalendarDay(anchorUtc, DateTime.now().toUtc());
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
          scannedAt.difference(args.sealedAtUtc.toUtc()).inMinutes.clamp(0, 1440);
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
        symptomCount: _stage == ClusterAlertStage.postConsumption
            ? _symptomCount
            : 0,
        notes: event.notes,
        reasonSummary: args.reasonSummary,
        localPhotoPath: args.localPhotoPath,
        sampleLabelCode: event.sampleLabelCode ?? _resolvedSampleLabel,
        broadcastEnabled: _broadcastEnabled,
        isPendingSync: event.isPendingSync,
        reportedAtUtc: event.createdAtUtc,
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
    final validToday = _isBatchVerifiedToday(args);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Lapor Anomali & KLB')),
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
              child: !validToday || args == null
                  ? SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPad),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: LacakErrorState(
                            title: 'Akses Pelaporan Terkunci',
                            message:
                                'Laporan darurat hanya dapat dibuat dari batch makanan yang telah dipindai dan diverifikasi pada hari ini.',
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
                              const SizedBox(height: AppSpacing.sm),
                              LacakSectionSurface.separated(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          args.menuName,
                                          style: AppTypography.titleItem
                                              .copyWith(
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
                                  _ReportDetailRow(
                                    label: 'Jam Segel Dapur',
                                    value: formatWibDateTime(args.sealedAtUtc),
                                    tabular: true,
                                  ),
                                  _ReportDetailRow(
                                    label: 'Suhu Wilayah',
                                    value:
                                        '${args.bmkgTempC.toStringAsFixed(1)} C',
                                    caption: AppConstants.bmkgShortAttribution,
                                    tabular: true,
                                  ),
                                  _ReportDetailRow(
                                    label: 'Kode Bank Sampel',
                                    value:
                                        _resolvedSampleLabel ??
                                        'Belum ada (ditahan sebelum simpan sampel)',
                                    tabular: true,
                                    highlightValue:
                                        _resolvedSampleLabel != null,
                                    mutedValue: _resolvedSampleLabel == null,
                                  ),
                                  _ReportDetailRow(
                                    label: 'WA Puskesmas Tujuan',
                                    value:
                                        school?.formattedPuskesmasWa ?? '-',
                                    tabular: true,
                                  ),
                                ],
                              ),
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
                                  () =>
                                      _stage = ClusterAlertStage.postConsumption,
                                ),
                              ),
                              if (_stage ==
                                  ClusterAlertStage.postConsumption) ...[
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  'Jumlah Siswa Bergejala (Tanpa Nama Siswa)',
                                  style: AppTypography.titleSection,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                LacakSectionSurface(
                                  padding: const EdgeInsets.all(AppSpacing.md),
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
                              LacakSectionSurface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.xs,
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
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
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              LacakDangerButton(
                                label: 'Kirim Peringatan & Siapkan PDF Puskesmas',
                                icon: Icons.notification_important_rounded,
                                isLoading: _submitting,
                                minHeight: AppSpacing.heroCtaMinHeight,
                                onPressed: () => _submitReport(args),
                              ),
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
          ],
        ),
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
    return Material(
      color: selected ? AppColors.primaryTint : AppColors.surfaceBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.borderHairline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
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
                size: 24,
                color: selected ? AppColors.onPrimaryTint : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.title,
                      style: AppTypography.titleItem.copyWith(
                        color: selected
                            ? AppColors.onPrimaryTint
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(stage.subtitle, style: AppTypography.bodyMedium),
                  ],
                ),
              ),
            ],
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
        minimumSize: const Size(48, 48),
        backgroundColor: AppColors.surfaceSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          side: const BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
      icon: Icon(icon, size: 24, color: AppColors.textPrimary),
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
        ? AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)
        : AppTypography.titleItem.copyWith(
            color: highlightValue ? AppColors.primary : AppColors.textPrimary,
            fontWeight: highlightValue ? FontWeight.w700 : FontWeight.w600,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelTag.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
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

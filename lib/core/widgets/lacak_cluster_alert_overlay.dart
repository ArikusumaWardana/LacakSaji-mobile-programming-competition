import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/alerts/domain/cluster_alert_models.dart';
import '../../features/alerts/presentation/cluster_alert_controller.dart';
import '../../features/alerts/presentation/widgets/alert_resolution_sheet.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/kitchen/domain/kitchen_models.dart';
import '../constants/app_routes.dart';
import '../router/app_router.dart';
import '../sync/offline_sync_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_buttons.dart';
import 'lacak_floating_notice.dart';
import 'lacak_status_badge.dart';

/// App-root host keeping O02 background auto-sync and O01 emergency Cluster Alert active on all screens.
class GlobalEmergencySyncHost extends ConsumerWidget {
  const GlobalEmergencySyncHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(offlineSyncControllerProvider);
    final alertState = ref.watch(clusterAlertControllerProvider);
    final authNotice = ref.watch(authFeedbackProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (alertState.activeAlert == null)
          LacakFloatingAuthNotice(
            notice: authNotice,
            onDismiss: () => ref.read(authFeedbackProvider.notifier).dismiss(),
          ),
        if (alertState.activeAlert != null)
          Positioned.fill(
            child: LacakClusterAlertOverlay(
              event: alertState.activeAlert!,
              pendingMoreCount: alertState.pendingQueue.length,
              isAcknowledging: alertState.isAcknowledging,
            ),
          ),
      ],
    );
  }
}

/// Global Overlay O01: High-contrast full-screen emergency Cluster Alert modal
/// with crisp editorial typography, borderless detail rows, and 12dp-radius solid CTAs.
class LacakClusterAlertOverlay extends ConsumerWidget {
  const LacakClusterAlertOverlay({
    super.key,
    required this.event,
    this.pendingMoreCount = 0,
    this.isAcknowledging = false,
  });

  final ClusterAlertEvent event;
  final int pendingMoreCount;
  final bool isAcknowledging;

  Future<void> _ackAndStay(WidgetRef ref) async {
    await ref
        .read(clusterAlertControllerProvider.notifier)
        .acknowledgeActiveAlert();
  }

  Future<void> _ackAndNavigate(WidgetRef ref, String targetRoute) async {
    await ref
        .read(clusterAlertControllerProvider.notifier)
        .acknowledgeActiveAlert();
    ref.read(goRouterProvider).go(targetRoute);
  }

  Future<void> _openResolutionSheet(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
  ) async {
    final verifierName = auth.profile?.fullName.isNotEmpty == true
        ? auth.profile!.fullName
        : (auth.kitchen?.name ?? auth.school?.name ?? 'Pejabat Terverifikasi');
    await showModalBottomSheet<ClusterAlertEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCanvas,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusHero),
        ),
      ),
      builder: (_) => AlertResolutionSheet(
        alert: event,
        verifierName: verifierName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isSchoolUser = auth.school != null;
    final isClarifiedSafe =
        event.resolutionStatus == AlertResolutionStatus.clarifiedSafe;
    final isConfirmedKlb =
        event.resolutionStatus == AlertResolutionStatus.confirmedKlb;
    final canResolve =
        !isConfirmedKlb &&
        canResolveClusterAlert(
          auth: auth,
          sppgId: event.sppgId,
          reporterSchoolId: event.reporterSchoolId,
        );
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    final headerBg = isClarifiedSafe
        ? AppColors.primary
        : AppColors.emergencyBg;
    final headerIcon = isClarifiedSafe
        ? Icons.verified_user_rounded
        : Icons.notification_important_rounded;
    final headerTitle = isClarifiedSafe
        ? 'PEMBARUAN STATUS DARURAT'
        : (isConfirmedKlb
              ? 'TERKONFIRMASI KLB PANGAN'
              : 'PERINGATAN DARURAT MAKANAN');
    final headerSubtitle = isClarifiedSafe
        ? 'Distribusi Aman Dilanjutkan · Klarifikasi Terverifikasi'
        : (isConfirmedKlb
              ? 'Status Ditetapkan KLB: Pertahankan Penahanan & Koordinasi Puskesmas'
              : (event.stage == ClusterAlertStage.postConsumption
                    ? 'Siaga Pasca-Konsumsi: Tahan Kloter & Siapkan Bank Sampel'
                    : 'Stop Distribusi Pra-Konsumsi: Jangan Bagikan Makanan Ini'));

    return PopScope(
      canPop: false,
      child: Material(
        color: AppColors.bgCanvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: headerBg,
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.lg,
                horizontalPad,
                AppSpacing.lg,
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          headerIcon,
                          size: 44,
                          color: AppColors.emergencyFg,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          headerTitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.displayStatus.copyWith(
                            color: AppColors.emergencyFg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headerSubtitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
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
                          LacakStatusBanner(
                            level: isClarifiedSafe
                                ? LacakStatusLevel.safe
                                : LacakStatusLevel.danger,
                            icon: isClarifiedSafe
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            title: isClarifiedSafe
                                ? 'Distribusi Aman Dilanjutkan'
                                : (isConfirmedKlb
                                      ? 'Terkonfirmasi Kejadian Luar Biasa'
                                      : 'Instruksi Tindakan Segera'),
                            description: isClarifiedSafe
                                ? '${event.resolutionNote ?? 'Anomali dinyatakan terlokalisir dan aman dilanjutkan.'}${event.resolvedByName != null && event.resolvedByName!.isNotEmpty ? ' Diverifikasi oleh ${event.resolvedByName}.' : ''}'
                                : (isConfirmedKlb &&
                                          event.resolutionNote != null &&
                                          event.resolutionNote!.isNotEmpty
                                      ? '${event.resolutionNote} ${event.instructionText}'
                                      : event.instructionText),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Rincian Peringatan Dapur Mitra',
                            style: AppTypography.titleSection,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Divider(height: 1),
                          _OverlayDetailRow(
                            label: 'Dapur SPPG',
                            value: event.sppgName,
                          ),
                          const Divider(height: 1),
                          _OverlayDetailRow(
                            label: 'Menu & Kode Batch',
                            value: '${event.menuName} (${event.batchCode})',
                            tabular: true,
                          ),
                          const Divider(height: 1),
                          _OverlayDetailRow(
                            label: 'Sekolah Pelapor',
                            value: event.activeReporterCount > 1
                                ? '${event.reporterSchoolName} (${event.activeReporterCount} sekolah melaporkan)'
                                : event.reporterSchoolName,
                          ),
                          const Divider(height: 1),
                          _OverlayDetailRow(
                            label: 'Waktu Laporan',
                            value: formatWibDateTime(event.createdAtUtc),
                            tabular: true,
                          ),
                          if (event.resolutionStatus !=
                              AlertResolutionStatus.active) ...[
                            const Divider(height: 1),
                            _OverlayDetailRow(
                              label: 'Status Klarifikasi',
                              value: event.resolutionStatus.label,
                            ),
                            if (event.resolvedByName != null &&
                                event.resolvedByName!.isNotEmpty) ...[
                              const Divider(height: 1),
                              _OverlayDetailRow(
                                label: 'Pejabat Pemverifikasi',
                                value: event.resolvedByName!,
                              ),
                            ],
                            if (event.resolvedAtUtc != null) ...[
                              const Divider(height: 1),
                              _OverlayDetailRow(
                                label: 'Waktu Pembaruan Audit',
                                value: formatWibDateTime(event.resolvedAtUtc!),
                                tabular: true,
                              ),
                            ],
                            if (event.resolutionNote != null &&
                                event.resolutionNote!.isNotEmpty) ...[
                              const Divider(height: 1),
                              _OverlayDetailRow(
                                label: 'Catatan Klarifikasi Resmi',
                                value: event.resolutionNote!,
                              ),
                            ],
                          ],
                          if (event.stage ==
                              ClusterAlertStage.postConsumption) ...[
                            const Divider(height: 1),
                            _OverlayDetailRow(
                              label: 'Siswa Bergejala',
                              value: '${event.symptomCount} siswa',
                              tabular: true,
                            ),
                          ],
                          if (event.sampleLabelCode != null &&
                              event.sampleLabelCode!.isNotEmpty) ...[
                            const Divider(height: 1),
                            _OverlayDetailRow(
                              label: 'Label Bank Sampel',
                              value: event.sampleLabelCode!,
                              tabular: true,
                            ),
                          ],
                          if (event.notes != null &&
                              event.notes!.isNotEmpty) ...[
                            const Divider(height: 1),
                            _OverlayDetailRow(
                              label: 'Catatan Lapangan',
                              value: event.notes!,
                            ),
                          ],
                          const Divider(height: 1),
                          if (pendingMoreCount > 0) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Masih ada $pendingMoreCount peringatan darurat lain yang menunggu konfirmasi.',
                              textAlign: TextAlign.center,
                              style: AppTypography.tabular(
                                AppTypography.bodyMedium.copyWith(
                                  color: AppColors.dangerFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          if (isClarifiedSafe)
                            LacakPrimaryButton(
                              label: 'Saya Mengerti & Lanjutkan Distribusi',
                              icon: Icons.check_circle_rounded,
                              isLoading: isAcknowledging,
                              onPressed: () => _ackAndStay(ref),
                            )
                          else
                            LacakDangerButton(
                              label: 'Saya Mengerti & Tahan Distribusi',
                              icon: Icons.check_circle_rounded,
                              isLoading: isAcknowledging,
                              onPressed: () => _ackAndStay(ref),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          if (isSchoolUser)
                            LacakSecondaryButton(
                              label: 'Lihat Bank Sampel Saya',
                              icon: Icons.kitchen_rounded,
                              onPressed: isAcknowledging
                                  ? null
                                  : () => _ackAndNavigate(
                                      ref,
                                      AppRoutes.schoolSamples,
                                    ),
                            )
                          else
                            LacakSecondaryButton(
                              label: 'Buka Beranda Dapur',
                              icon: Icons.home_rounded,
                              onPressed: isAcknowledging
                                  ? null
                                  : () => _ackAndNavigate(
                                      ref,
                                      AppRoutes.kitchenHome,
                                    ),
                            ),
                          if (canResolve) ...[
                            const SizedBox(height: AppSpacing.sm),
                            LacakSecondaryButton(
                              label: isClarifiedSafe
                                  ? 'Ubah ke Terkonfirmasi KLB'
                                  : 'Klarifikasi / Ubah Status Darurat',
                              icon: Icons.verified_user_outlined,
                              onPressed: isAcknowledging
                                  ? null
                                  : () =>
                                        _openResolutionSheet(context, ref, auth),
                            ),
                          ],
                        ],
                      ),
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

class _OverlayDetailRow extends StatelessWidget {
  const _OverlayDetailRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final String label;
  final String value;
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
                  style: valueStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

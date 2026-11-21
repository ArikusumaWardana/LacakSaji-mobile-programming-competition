import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/alerts/domain/cluster_alert_models.dart';
import '../../features/alerts/presentation/cluster_alert_controller.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/kitchen/domain/kitchen_models.dart';
import '../constants/app_routes.dart';
import '../router/app_router.dart';
import '../sync/offline_sync_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_buttons.dart';
import 'lacak_section_surface.dart';
import 'lacak_status_badge.dart';

/// App-root host keeping O02 background auto-sync and O01 emergency Cluster Alert active on all screens.
class GlobalEmergencySyncHost extends ConsumerWidget {
  const GlobalEmergencySyncHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(offlineSyncControllerProvider);
    final alertState = ref.watch(clusterAlertControllerProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
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

/// Global Overlay O01: Full-screen emergency Cluster Alert modal compliant with DESIGN.md Anti-Slop.
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
    await ref.read(clusterAlertControllerProvider.notifier).acknowledgeActiveAlert();
  }

  Future<void> _ackAndNavigate(WidgetRef ref, String targetRoute) async {
    await ref.read(clusterAlertControllerProvider.notifier).acknowledgeActiveAlert();
    ref.read(goRouterProvider).go(targetRoute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isSchoolUser = auth.school != null;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return PopScope(
      canPop: false,
      child: Material(
        color: AppColors.bgCanvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.emergencyBg,
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.xl,
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
                        const Icon(
                          Icons.notification_important_rounded,
                          size: 48,
                          color: AppColors.emergencyFg,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'PERINGATAN DARURAT MAKANAN',
                          textAlign: TextAlign.center,
                          style: AppTypography.headlinePage.copyWith(
                            color: AppColors.emergencyFg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          event.stage == ClusterAlertStage.postConsumption
                              ? 'Siaga Pasca-Konsumsi: Tahan Kloter Siang & Siapkan Bank Sampel'
                              : 'Stop Distribusi Pra-Konsumsi: Jangan Bagikan Makanan Ini',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.emergencyFg,
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
                            level: LacakStatusLevel.danger,
                            icon: Icons.warning_amber_rounded,
                            title: 'Instruksi Tindakan Segera',
                            description: event.instructionText,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Rincian Peringatan Dapur Mitra',
                            style: AppTypography.titleSection,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          LacakSectionSurface.separated(
                            children: [
                              _OverlayDetailRow(
                                label: 'Dapur SPPG',
                                value: event.sppgName,
                              ),
                              _OverlayDetailRow(
                                label: 'Menu & Kode Batch',
                                value: '${event.menuName}\n(${event.batchCode})',
                              ),
                              _OverlayDetailRow(
                                label: 'Sekolah Pelapor',
                                value: event.activeReporterCount > 1
                                    ? '${event.reporterSchoolName} (${event.activeReporterCount} sekolah melaporkan)'
                                    : event.reporterSchoolName,
                              ),
                              _OverlayDetailRow(
                                label: 'Waktu Laporan',
                                value: formatWibDateTime(event.createdAtUtc),
                                tabular: true,
                              ),
                              if (event.stage == ClusterAlertStage.postConsumption)
                                _OverlayDetailRow(
                                  label: 'Siswa Bergejala',
                                  value: '${event.symptomCount} siswa',
                                  tabular: true,
                                ),
                              if (event.sampleLabelCode != null &&
                                  event.sampleLabelCode!.isNotEmpty)
                                _OverlayDetailRow(
                                  label: 'Label Bank Sampel',
                                  value: event.sampleLabelCode!,
                                  tabular: true,
                                ),
                              if (event.notes != null && event.notes!.isNotEmpty)
                                _OverlayDetailRow(
                                  label: 'Catatan Lapangan',
                                  value: event.notes!,
                                ),
                            ],
                          ),
                          if (pendingMoreCount > 0) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Masih ada $pendingMoreCount peringatan darurat lain yang menunggu konfirmasi.',
                              textAlign: TextAlign.center,
                              style: AppTypography.tabular(
                                AppTypography.bodyMedium.copyWith(
                                  color: AppColors.dangerFg,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          LacakDangerButton(
                            label: 'Saya Mengerti & Tahan Distribusi',
                            icon: Icons.check_circle_rounded,
                            isLoading: isAcknowledging,
                            minHeight: AppSpacing.heroCtaMinHeight,
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

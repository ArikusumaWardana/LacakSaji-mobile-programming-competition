import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/lacak_status_badge.dart';
import '../../../kitchen/domain/kitchen_models.dart';
import '../../../school/domain/danger_zone_calculator.dart';
import '../../domain/traceability_models.dart';

/// Editorial borderless supply-chain timeline separating kitchen holding time
/// from courier transit duration (`Dimasak -> Dimuat Kurir -> Tiba di Sekolah`).
class SupplyChainTimeline extends StatelessWidget {
  const SupplyChainTimeline({
    super.key,
    required this.timeline,
    this.title = 'Lini Masa Rantai Pasok',
  });

  final SupplyChainTimelineData timeline;
  final String title;

  @override
  Widget build(BuildContext context) {
    final handover = timeline.handover;
    final loadedAt = timeline.loadedAtUtc;
    final arrivedAt = timeline.arrivedAtUtc;
    final schoolScanned = timeline.schoolScannedAtUtc;

    final kitchenWait = timeline.kitchenWaitMinutes;
    final roadTransit = timeline.courierTransitMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: AppTypography.titleSection),
            if (timeline.hasRoadDelay)
              const LacakStatusTag(
                level: LacakStatusLevel.warning,
                label: 'Transit Jalan Lama',
                icon: Icons.local_shipping_rounded,
              )
            else if (timeline.hasKitchenDelay)
              const LacakStatusTag(
                level: LacakStatusLevel.warning,
                label: 'Tertahan di Dapur',
                icon: Icons.soup_kitchen_rounded,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimelineStepRow(
                stepTitle: 'Dimasak & Disegel Dapur',
                timestampText: formatWibDateTime(timeline.sealedAtUtc),
                detailText: 'QR Segel kriptografis dikunci oleh dapur SPPG.',
                isDone: true,
                isWarning: false,
                showConnector: true,
                connectorLabel: kitchenWait != null
                    ? 'Jeda tunggu muat: ${formatDurationMinutes(kitchenWait)}'
                    : null,
                connectorWarning: timeline.hasKitchenDelay,
              ),
              _TimelineStepRow(
                stepTitle: 'Dimuat Kurir',
                timestampText: loadedAt != null
                    ? formatWibDateTime(loadedAt)
                    : 'Belum dipindai kurir',
                detailText: handover != null
                    ? _buildLoadDetail(handover)
                    : 'Menunggu kurir memindai QR saat pemuatan mobil boks.',
                isDone: loadedAt != null,
                isWarning: timeline.hasKitchenDelay,
                showConnector: true,
                connectorLabel: roadTransit != null
                    ? 'Durasi transit jalan: ${formatDurationMinutes(roadTransit)}'
                    : null,
                connectorWarning: timeline.hasRoadDelay,
              ),
              _TimelineStepRow(
                stepTitle: 'Tiba di Sekolah',
                timestampText: arrivedAt != null
                    ? formatWibDateTime(arrivedAt)
                    : (schoolScanned != null
                          ? '${formatWibDateTime(schoolScanned)} (Scan Sekolah)'
                          : 'Dalam pengiriman / belum tiba'),
                detailText: _buildArrivalDetail(handover, schoolScanned),
                isDone: arrivedAt != null || schoolScanned != null,
                isWarning: timeline.hasRoadDelay,
                showConnector: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildLoadDetail(TransitHandoverItem handover) {
    final parts = <String>['Kurir: ${handover.courierName}'];
    if (handover.loadCoordsText != null) {
      parts.add('GPS ${handover.loadCoordsText}');
    }
    if (handover.isPendingSync) {
      parts.add('Menunggu sinkronisasi');
    }
    return parts.join(' · ');
  }

  String _buildArrivalDetail(
    TransitHandoverItem? handover,
    DateTime? schoolScanned,
  ) {
    if (handover != null && handover.arrivedAtUtc != null) {
      final parts = <String>[];
      if (handover.schoolName != null && handover.schoolName!.isNotEmpty) {
        parts.add(handover.schoolName!);
      } else {
        parts.add('Tiba di gerbang sekolah');
      }
      if (handover.arriveCoordsText != null) {
        parts.add('GPS ${handover.arriveCoordsText}');
      }
      if (schoolScanned != null) {
        parts.add('Diverifikasi PIC ${formatWibTime(schoolScanned)}');
      }
      return parts.join(' · ');
    }
    if (schoolScanned != null) {
      return 'PIC sekolah sudah memindai QR penerimaan pada ${formatWibTime(schoolScanned)}.';
    }
    return 'Menunggu kurir atau PIC sekolah memindai QR saat tiba.';
  }
}

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({
    required this.stepTitle,
    required this.timestampText,
    required this.detailText,
    required this.isDone,
    required this.isWarning,
    required this.showConnector,
    this.connectorLabel,
    this.connectorWarning = false,
  });

  final String stepTitle;
  final String timestampText;
  final String detailText;
  final bool isDone;
  final bool isWarning;
  final bool showConnector;
  final String? connectorLabel;
  final bool connectorWarning;

  @override
  Widget build(BuildContext context) {
    final dotColor = !isDone
        ? AppColors.borderHairline
        : (isWarning ? AppColors.warnFg : AppColors.primary);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDone ? dotColor : AppColors.bgCanvas,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? dotColor : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDone ? AppColors.primary : AppColors.borderHairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? AppSpacing.md : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 2,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        stepTitle,
                        style: AppTypography.titleItem.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        timestampText,
                        style: AppTypography.tabular(
                          AppTypography.captionMuted.copyWith(
                            color: isDone
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (connectorLabel != null && connectorLabel!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: connectorWarning
                            ? AppColors.warnBg
                            : AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusChip,
                        ),
                      ),
                      child: Text(
                        connectorLabel!,
                        style: AppTypography.tabular(
                          AppTypography.captionLegal.copyWith(
                            color: connectorWarning
                                ? AppColors.warnFg
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

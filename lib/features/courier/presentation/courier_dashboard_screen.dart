import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../../school/domain/danger_zone_calculator.dart';
import '../../traceability/domain/traceability_models.dart';
import '../../traceability/presentation/traceability_providers.dart';
import '../../traceability/presentation/widgets/supply_chain_timeline.dart';

/// K01: Courier / Pengantar operational dashboard using MinimalTopHeader,
/// FilterChipStrip, BorderlessThumbTile list, and StickyBottomActionBar.
class CourierDashboardScreen extends ConsumerStatefulWidget {
  const CourierDashboardScreen({super.key});

  @override
  ConsumerState<CourierDashboardScreen> createState() =>
      _CourierDashboardScreenState();
}

class _CourierDashboardScreenState
    extends ConsumerState<CourierDashboardScreen> {
  CourierDeliveryFilter _filter = CourierDeliveryFilter.readyToLoad;

  void _showHandoverSummarySheet(CourierBatchDeliveryItem item) {
    final batch = item.batch;
    final timeline = SupplyChainTimelineData(
      batchId: batch.id,
      sealedAtUtc: batch.sealedAtUtc,
      handover: item.handover,
    );

    showModalBottomSheet<void>(
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
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${batch.menuName} (${batch.batchCode})',
                          style: AppTypography.titleSection,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        tooltip: 'Tutup',
                        constraints: const BoxConstraints(
                          minWidth: AppSpacing.minTouchTarget,
                          minHeight: AppSpacing.minTouchTarget,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SupplyChainTimeline(timeline: timeline),
                  const SizedBox(height: AppSpacing.lg),
                  LacakSecondaryButton(
                    label: 'Tutup',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(authControllerProvider).kitchen;
    final deliveriesAsync = ref.watch(courierDeliveriesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    if (kitchen == null) {
      return Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LacakErrorState(
                  title: 'Akses Kurir SPPG Belum Aktif',
                  message:
                      'Akun kurir Anda belum ditautkan atau sedang dinonaktifkan oleh Admin Dapur SPPG. Hubungi Admin SPPG untuk mengaktifkan kembali akses pengiriman.',
                ),
                const SizedBox(height: AppSpacing.lg),
                LacakSecondaryButton(
                  label: 'Keluar Akun',
                  icon: Icons.logout_rounded,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allItems = deliveriesAsync.value ?? const <CourierBatchDeliveryItem>[];
    final readyCount = allItems
        .where((i) => i.stage == CourierDeliveryFilter.readyToLoad)
        .length;
    final transitCount = allItems
        .where((i) => i.stage == CourierDeliveryFilter.inTransit)
        .length;
    final doneCount = allItems
        .where((i) => i.stage == CourierDeliveryFilter.completed)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          MinimalTopHeader(
            contextLabel: 'Kurir SPPG · ${kitchen.inviteCode}',
            title: kitchen.name,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(courierDeliveriesProvider);
                await ref.read(courierDeliveriesProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: _CourierMetricStrip(
                            readyCount: readyCount,
                            transitCount: transitCount,
                            doneCount: doneCount,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilterChipStrip<CourierDeliveryFilter>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: _filter,
                          onSelected: (next) => setState(() => _filter = next),
                          items: CourierDeliveryFilter.values
                              .map(
                                (item) => FilterChipItem(
                                  value: item,
                                  label: item.label,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: deliveriesAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 4,
                              loadingLabel: 'Memuat daftar pengantaran...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(courierDeliveriesProvider),
                            ),
                            data: (items) {
                              final visible = items
                                  .where((item) => item.stage == _filter)
                                  .toList(growable: false);
                              if (visible.isEmpty) {
                                return LacakEmptyState(
                                  icon: Icons.local_shipping_rounded,
                                  title: 'Tidak ada pengiriman ${_filter.label}',
                                  message:
                                      'Gunakan tombol Pindai QR di bawah untuk mencatat pemuatan di dapur atau kedatangan di sekolah.',
                                  actionLabel: 'Pindai QR Muat / Tiba',
                                  onAction: () =>
                                      context.push(AppRoutes.courierScan),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${_filter.label} (${visible.length})',
                                    style: AppTypography.titleSection,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  for (var i = 0; i < visible.length; i++)
                                    _CourierDeliveryTile(
                                      item: visible[i],
                                      showBottomDivider: i < visible.length - 1,
                                      onTap: () {
                                        final stage = visible[i].stage;
                                        if (stage ==
                                            CourierDeliveryFilter.readyToLoad) {
                                          context.push(
                                            AppRoutes.courierScan,
                                            extra:
                                                CourierScanMode.loadAtKitchen,
                                          );
                                        } else if (stage ==
                                            CourierDeliveryFilter.inTransit) {
                                          context.push(
                                            AppRoutes.courierScan,
                                            extra:
                                                CourierScanMode.arriveAtSchool,
                                          );
                                        } else {
                                          _showHandoverSummarySheet(visible[i]);
                                        }
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          StickyBottomActionBar(
            summaryLabel: 'Pengiriman Hari Ini',
            summaryValue: '$transitCount di jalan · $doneCount tiba',
            ctaLabel: 'Pindai QR Muat / Tiba',
            ctaIcon: Icons.qr_code_scanner_rounded,
            onCtaPressed: () => context.push(
              AppRoutes.courierScan,
              extra: _filter == CourierDeliveryFilter.inTransit
                  ? CourierScanMode.arriveAtSchool
                  : CourierScanMode.loadAtKitchen,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierMetricStrip extends StatelessWidget {
  const _CourierMetricStrip({
    required this.readyCount,
    required this.transitCount,
    required this.doneCount,
  });

  final int readyCount;
  final int transitCount;
  final int doneCount;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cells = [
            _MetricMini(label: 'Siap Muat', value: '$readyCount'),
            _MetricMini(label: 'Di Jalan', value: '$transitCount'),
            _MetricMini(label: 'Selesai', value: '$doneCount'),
          ];
          if (constraints.maxWidth < 280 || textScale >= 1.3) {
            return Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: cells,
            );
          }
          return Row(
            children: cells
                .map((cell) => Expanded(child: cell))
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  const _MetricMini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.captionMuted),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.tabular(AppTypography.displayStatus),
        ),
      ],
    );
  }
}

class _CourierDeliveryTile extends StatelessWidget {
  const _CourierDeliveryTile({
    required this.item,
    required this.showBottomDivider,
    required this.onTap,
  });

  final CourierBatchDeliveryItem item;
  final bool showBottomDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final batch = item.batch;
    final handover = item.handover;
    final stage = item.stage;

    final String statusText;
    final Color statusColor;
    final IconData thumbIcon;
    final Color thumbBg;
    final Color thumbFg;

    switch (stage) {
      case CourierDeliveryFilter.readyToLoad:
        statusText = 'Siap Dimuat (${formatWibTime(batch.sealedAtUtc)})';
        statusColor = AppColors.primary;
        thumbIcon = Icons.inventory_rounded;
        thumbBg = AppColors.surfaceSoft;
        thumbFg = AppColors.primary;
      case CourierDeliveryFilter.inTransit:
        statusText = handover != null
            ? 'Berangkat ${formatWibTime(handover.effectiveDepartedAtUtc)}'
            : 'Dalam Perjalanan';
        statusColor = AppColors.warnFg;
        thumbIcon = Icons.local_shipping_rounded;
        thumbBg = AppColors.warnBg;
        thumbFg = AppColors.warnFg;
      case CourierDeliveryFilter.completed:
        final transitMin = handover?.transitDurationMinutes;
        statusText = transitMin != null
            ? 'Tiba · Transit ${formatDurationMinutes(transitMin)}'
            : 'Tiba di Sekolah';
        statusColor = AppColors.safeFg;
        thumbIcon = Icons.verified_rounded;
        thumbBg = AppColors.safeBg;
        thumbFg = AppColors.safeFg;
    }

    return BorderlessThumbTile(
      title: batch.menuName,
      statusText: statusText,
      statusColor: statusColor,
      fallbackIcon: thumbIcon,
      fallbackBgColor: thumbBg,
      fallbackIconColor: thumbFg,
      showBottomDivider: showBottomDivider,
      onTap: onTap,
      metadata: [
        BorderlessMetaItem(
          icon: Icons.qr_code_2_rounded,
          label: batch.batchCode,
        ),
        if (batch.portionCount > 0)
          BorderlessMetaItem(
            icon: Icons.restaurant_rounded,
            label: '${batch.portionCount} porsi',
          ),
        if (handover?.schoolName != null && handover!.schoolName!.isNotEmpty)
          BorderlessMetaItem(
            icon: Icons.school_rounded,
            label: handover.schoolName!,
          ),
        if (handover?.isPendingSync ?? false)
          const BorderlessMetaItem(
            icon: Icons.cloud_off_rounded,
            label: 'Belum Terkirim',
          ),
      ],
      trailing: Icon(
        stage == CourierDeliveryFilter.completed
            ? Icons.timeline_rounded
            : Icons.qr_code_scanner_rounded,
        size: 22,
        color: AppColors.primary,
      ),
    );
  }
}

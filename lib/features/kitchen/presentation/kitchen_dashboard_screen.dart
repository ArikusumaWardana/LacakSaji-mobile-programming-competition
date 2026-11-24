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
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';
import 'widgets/kitchen_photo_builder.dart';

enum _KitchenDashboardFilter {
  all,
  today,
  highRisk,
  needsAction,
}

/// D01: Editorial SPPG Kitchen dashboard with minimal header, search/quick-create bar,
/// filter chips, photo batch carousel, and borderless school list.
class KitchenDashboardScreen extends ConsumerStatefulWidget {
  const KitchenDashboardScreen({super.key});

  @override
  ConsumerState<KitchenDashboardScreen> createState() =>
      _KitchenDashboardScreenState();
}

class _KitchenDashboardScreenState
    extends ConsumerState<KitchenDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _KitchenDashboardFilter _filter = _KitchenDashboardFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNotificationsSheet(KitchenDashboardData? data) {
    final alerts = data?.activeAlertsToday ?? const <ActiveClusterAlertItem>[];
    final pendingCount = data?.pendingSchoolsCount ?? 0;

    showModalBottomSheet<void>(
      context: context,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pemberitahuan Dapur',
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
                const SizedBox(height: AppSpacing.sm),
                if (alerts.isEmpty && pendingCount == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(
                      'Tidak ada peringatan darurat atau permintaan sekolah yang menunggu hari ini.',
                      style: AppTypography.bodyMedium,
                    ),
                  )
                else ...[
                  if (alerts.isNotEmpty) ...[
                    LacakStatusBanner(
                      level: LacakStatusLevel.danger,
                      title: '${alerts.length} Laporan Anomali Aktif',
                      description:
                          '${alerts.first.reporterSchoolName} melaporkan anomali pada ${alerts.first.menuName} (${alerts.first.batchCode}).',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (pendingCount > 0)
                    LacakStatusBanner(
                      level: LacakStatusLevel.warning,
                      title: '$pendingCount Sekolah Menunggu Persetujuan',
                      description:
                          'Tinjau permintaan sekolah baru agar dapat memindai QR batch harian.',
                      action: LacakSecondaryButton(
                        label: 'Buka Sekolah Binaan',
                        icon: Icons.school_rounded,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.go(AppRoutes.kitchenSchools);
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<FoodBatchItem> _filterBatches(List<FoodBatchItem> batches) {
    final nowUtc = DateTime.now().toUtc();
    return batches.where((batch) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        final match = batch.menuName.toLowerCase().contains(q) ||
            batch.batchCode.toLowerCase().contains(q);
        if (!match) {
          return false;
        }
      }
      return switch (_filter) {
        _KitchenDashboardFilter.all => true,
        _KitchenDashboardFilter.today =>
          isSameWibCalendarDay(batch.sealedAtUtc, nowUtc),
        _KitchenDashboardFilter.highRisk =>
          batch.riskCategory == FoodRiskCategory.high,
        _KitchenDashboardFilter.needsAction =>
          batch.hasAnomalyReport || batch.isPendingSync,
      };
    }).toList(growable: false);
  }

  List<PartnerSchoolItem> _filterSchools(List<PartnerSchoolItem> schools) {
    final nowUtc = DateTime.now().toUtc();
    return schools.where((school) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        final match = school.name.toLowerCase().contains(q) ||
            school.npsn.toLowerCase().contains(q) ||
            school.villageLabel.toLowerCase().contains(q);
        if (!match) {
          return false;
        }
      }
      return switch (_filter) {
        _KitchenDashboardFilter.all => true,
        _KitchenDashboardFilter.today =>
          school.lastScannedAtUtc != null &&
              isSameWibCalendarDay(school.lastScannedAtUtc!, nowUtc),
        _KitchenDashboardFilter.highRisk =>
          school.dailyStatus == SchoolDailyStatus.anomaly,
        _KitchenDashboardFilter.needsAction =>
          school.verificationStatus == SchoolVerificationStatus.pending ||
              school.dailyStatus != SchoolDailyStatus.received,
      };
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final kitchen = authState.kitchen;
    final dashboardAsync = ref.watch(kitchenDashboardProvider);
    final schoolsAsync = ref.watch(kitchenSchoolsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = width >= 900 ? 960.0 : AppSpacing.maxContentWidth(width);

    if (kitchen == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(
              message:
                  'Profil dapur SPPG belum dimuat. Coba perbarui status akun di menu Profil.',
            ),
          ),
        ),
      );
    }

    final dashData = dashboardAsync.value;
    final hasUnread = (dashData?.activeAlertsToday.isNotEmpty ?? false) ||
        (dashData?.pendingSchoolsCount ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          MinimalTopHeader(
            contextLabel: 'Dapur SPPG · ${kitchen.inviteCode}',
            title: kitchen.name,
            hasUnreadAlert: hasUnread,
            onNotificationTap: () => _showNotificationsSheet(dashData),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(kitchenDashboardProvider);
                ref.invalidate(kitchenSchoolsProvider);
                await Future.wait([
                  ref.read(kitchenDashboardProvider.future),
                  ref.read(kitchenSchoolsProvider.future),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            AppSpacing.sm,
                            horizontalPad,
                            AppSpacing.md,
                          ),
                          child: SearchAndActionBar(
                            controller: _searchController,
                            hintText: 'Cari batch menu atau sekolah...',
                            onChanged: (value) {
                              setState(
                                () => _searchQuery = value.trim().toLowerCase(),
                              );
                            },
                            actionIcon: Icons.add_rounded,
                            actionTooltip: 'Buat Batch Baru',
                            onActionTap: () =>
                                context.push(AppRoutes.kitchenCreateBatch),
                          ),
                        ),
                        FilterChipStrip<_KitchenDashboardFilter>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: _filter,
                          onSelected: (next) => setState(() => _filter = next),
                          items: const [
                            FilterChipItem(
                              value: _KitchenDashboardFilter.all,
                              label: 'Semua',
                            ),
                            FilterChipItem(
                              value: _KitchenDashboardFilter.today,
                              label: 'Hari Ini',
                            ),
                            FilterChipItem(
                              value: _KitchenDashboardFilter.highRisk,
                              label: 'Risiko Tinggi',
                            ),
                            FilterChipItem(
                              value: _KitchenDashboardFilter.needsAction,
                              label: 'Butuh Aksi',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        dashboardAsync.when(
                          loading: () => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: const LacakSkeletonList(
                              itemCount: 3,
                              showHeaderBlock: true,
                              showHeroActionBlock: true,
                              loadingLabel: 'Memuat ringkasan batch hari ini...',
                            ),
                          ),
                          error: (error, _) => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: LacakErrorState(
                              message: error.toString(),
                              onRetry: () {
                                ref.invalidate(kitchenDashboardProvider);
                                ref.invalidate(kitchenSchoolsProvider);
                              },
                            ),
                          ),
                          data: (data) => _DashboardContent(
                            data: data,
                            schoolsAsync: schoolsAsync,
                            filteredBatches: _filterBatches(data.todayBatches),
                            filterSchools: _filterSchools,
                            horizontalPad: horizontalPad,
                            hasActiveFilter: _filter !=
                                    _KitchenDashboardFilter.all ||
                                _searchQuery.isNotEmpty,
                            onResetFilter: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filter = _KitchenDashboardFilter.all;
                              });
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
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.data,
    required this.schoolsAsync,
    required this.filteredBatches,
    required this.filterSchools,
    required this.horizontalPad,
    required this.hasActiveFilter,
    required this.onResetFilter,
  });

  final KitchenDashboardData data;
  final AsyncValue<List<PartnerSchoolItem>> schoolsAsync;
  final List<FoodBatchItem> filteredBatches;
  final List<PartnerSchoolItem> Function(List<PartnerSchoolItem>) filterSchools;
  final double horizontalPad;
  final bool hasActiveFilter;
  final VoidCallback onResetFilter;

  @override
  Widget build(BuildContext context) {
    final summary = data.weeklyWasteSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.activeAlertsToday.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: LacakStatusBanner(
              level: LacakStatusLevel.danger,
              title:
                  'PERINGATAN DARURAT: ${data.activeAlertsToday.length} Laporan Anomali',
              description:
                  '${data.activeAlertsToday.first.reporterSchoolName} melaporkan anomali pada batch ${data.activeAlertsToday.first.batchCode} (${data.activeAlertsToday.first.menuName}). Segera koordinasikan penahanan distribusi.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (data.pendingSchoolsCount > 0) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: LacakStatusBanner(
              level: LacakStatusLevel.warning,
              title:
                  '${data.pendingSchoolsCount} Sekolah Menunggu Persetujuan',
              description:
                  'Tinjau permintaan bergabung agar sekolah binaan dapat memindai QR segel harian.',
              action: LacakSecondaryButton(
                label: 'Tinjau Permintaan Sekolah',
                icon: Icons.school_rounded,
                onPressed: () => context.go(AppRoutes.kitchenSchools),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: _OperationalSummaryStrip(
            batchCount: data.todayBatches.length,
            receivedSchools: data.todayReceivedSchoolsCount,
            approvedSchools: data.approvedSchoolsCount,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Batch Aktif Hari Ini',
                  style: AppTypography.titleSection,
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.kitchenHistory),
                child: const Text('Lihat semua'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filteredBatches.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: LacakEmptyState(
              icon: Icons.qr_code_2_rounded,
              title: hasActiveFilter
                  ? 'Tidak ada batch yang cocok'
                  : 'Belum ada batch hari ini',
              message: hasActiveFilter
                  ? 'Ubah kata kunci pencarian atau pilih filter lain.'
                  : 'Buat QR Segel batch baru saat makanan selesai dikemas sebelum dikirim.',
              actionLabel:
                  hasActiveFilter ? 'Tampilkan Semua' : 'Buat Batch Baru',
              onAction: hasActiveFilter
                  ? onResetFilter
                  : () => context.push(AppRoutes.kitchenCreateBatch),
            ),
          )
        else
          SizedBox(
            height: 256,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              itemCount: filteredBatches.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final batch = filteredBatches[index];
                return _BatchCarouselCard(
                  batch: batch,
                  onTap: () => context.push(
                    AppRoutes.batchDetailPath(batch.id),
                    extra: batch,
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sekolah Binaan & Distribusi',
                  style: AppTypography.titleSection,
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.kitchenSchools),
                child: const Text('Lihat semua'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: schoolsAsync.when(
            loading: () => const LacakSkeletonList(
              itemCount: 2,
              loadingLabel: 'Memuat daftar sekolah binaan...',
            ),
            error: (error, _) => Text(
              error.toString(),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.dangerFg),
            ),
            data: (schools) {
              final visibleSchools = filterSchools(schools).take(5).toList(
                growable: false,
              );
              if (visibleSchools.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    hasActiveFilter
                        ? 'Tidak ada sekolah binaan yang cocok dengan filter saat ini.'
                        : 'Belum ada sekolah binaan yang terhubung.',
                    style: AppTypography.bodyMedium,
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final useTwoCols = constraints.maxWidth >= 680;
                  if (!useTwoCols) {
                    return Column(
                      children: [
                        for (var i = 0; i < visibleSchools.length; i++)
                          _SchoolDistributionTile(
                            school: visibleSchools[i],
                            showBottomDivider: i < visibleSchools.length - 1,
                            onTap: () => context.go(AppRoutes.kitchenSchools),
                          ),
                      ],
                    );
                  }
                  final colWidth = (constraints.maxWidth - AppSpacing.xl) / 2;
                  return Wrap(
                    spacing: AppSpacing.xl,
                    runSpacing: AppSpacing.xs,
                    children: visibleSchools
                        .map(
                          (school) => SizedBox(
                            width: colWidth,
                            child: _SchoolDistributionTile(
                              school: school,
                              showBottomDivider: true,
                              onTap: () => context.go(AppRoutes.kitchenSchools),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1),
              InkWell(
                onTap: () => context.go(AppRoutes.kitchenHistory),
                borderRadius: BorderRadius.circular(AppSpacing.radiusThumb),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: summary.hasHighWasteAlert
                              ? AppColors.warnBg
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusThumb,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 20,
                          color: summary.hasHighWasteAlert
                              ? AppColors.warnFg
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.sampleCount == 0
                                  ? 'Evaluasi Sisa Makanan (7 Hari)'
                                  : 'Nasi ${summary.avgCarbPct}% · Lauk ${summary.avgProteinPct}% · Sayur ${summary.avgVegPct}%',
                              style: AppTypography.tabular(
                                AppTypography.titleItem,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.sampleCount == 0
                                  ? 'Belum ada laporan minggu ini. Ketuk untuk lihat riwayat.'
                                  : (summary.hasHighWasteAlert
                                        ? 'Ada komponen >= 40%. Ketuk untuk tinjau evaluasi.'
                                        : 'Rata-rata dari ${summary.sampleCount} laporan ompreng.'),
                              style: AppTypography.bodyMedium.copyWith(
                                color: summary.hasHighWasteAlert
                                    ? AppColors.warnFg
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationalSummaryStrip extends StatelessWidget {
  const _OperationalSummaryStrip({
    required this.batchCount,
    required this.receivedSchools,
    required this.approvedSchools,
  });

  final int batchCount;
  final int receivedSchools;
  final int approvedSchools;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 310 || textScale >= 1.3;
          final leftMetric = _MetricCell(
            label: 'Batch Hari Ini',
            value: '$batchCount',
            caption: 'Segel aktif',
          );
          final rightMetric = _MetricCell(
            label: 'Sekolah Terima',
            value: '$receivedSchools / $approvedSchools',
            caption: 'Sudah pindai',
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftMetric,
                const Divider(height: 1),
                rightMetric,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: leftMetric),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.borderHairline,
                ),
                Expanded(child: rightMetric),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.captionMuted),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.tabular(AppTypography.displayStatus),
          ),
          const SizedBox(height: 2),
          Text(caption, style: AppTypography.captionLegal),
        ],
      ),
    );
  }
}

class _BatchCarouselCard extends StatelessWidget {
  const _BatchCarouselCard({
    required this.batch,
    required this.onTap,
  });

  final FoodBatchItem batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String badgeLabel;
    final IconData badgeIcon;
    if (batch.hasAnomalyReport) {
      badgeLabel = 'Anomali';
      badgeIcon = Icons.warning_amber_rounded;
    } else if (batch.isPendingSync) {
      badgeLabel = 'Offline';
      badgeIcon = Icons.cloud_off_rounded;
    } else {
      badgeLabel = formatWibTime(batch.sealedAtUtc);
      badgeIcon = Icons.schedule_rounded;
    }

    return KitchenBatchPhotoBuilder(
      localPhotoPath: batch.localPhotoPath,
      storagePath: batch.packagingPhotoUrl,
      builder: (context, imageProvider) {
        return FeaturedVisualCard(
          width: 224,
          height: 256,
          image: imageProvider,
          badgeLabel: badgeLabel,
          badgeIcon: badgeIcon,
          title: batch.menuName,
          subtitle: '${batch.portionCount} porsi · ${batch.riskCategory.label}',
          onTap: onTap,
        );
      },
    );
  }
}

class _SchoolDistributionTile extends StatelessWidget {
  const _SchoolDistributionTile({
    required this.school,
    required this.showBottomDivider,
    required this.onTap,
  });

  final PartnerSchoolItem school;
  final bool showBottomDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String statusText;
    final Color statusColor;
    final Color thumbBg;
    final Color thumbIconColor;

    if (school.verificationStatus == SchoolVerificationStatus.pending) {
      statusText = 'Menunggu Persetujuan';
      statusColor = AppColors.warnFg;
      thumbBg = AppColors.warnBg;
      thumbIconColor = AppColors.warnFg;
    } else if (school.dailyStatus == SchoolDailyStatus.anomaly) {
      statusText = 'Anomali Dilaporkan';
      statusColor = AppColors.dangerFg;
      thumbBg = AppColors.dangerBg;
      thumbIconColor = AppColors.dangerFg;
    } else if (school.dailyStatus == SchoolDailyStatus.received) {
      statusText = 'Sudah Terima';
      statusColor = AppColors.safeFg;
      thumbBg = AppColors.safeBg;
      thumbIconColor = AppColors.safeFg;
    } else {
      statusText = 'Belum Scan Hari Ini';
      statusColor = AppColors.primary;
      thumbBg = AppColors.surfaceSoft;
      thumbIconColor = AppColors.primary;
    }

    return BorderlessThumbTile(
      fallbackIcon: Icons.school_rounded,
      fallbackBgColor: thumbBg,
      fallbackIconColor: thumbIconColor,
      title: school.name,
      statusText: statusText,
      statusColor: statusColor,
      metadata: [
        BorderlessMetaItem(
          icon: Icons.location_on_rounded,
          label: school.villageLabel,
        ),
        BorderlessMetaItem(
          icon: Icons.schedule_rounded,
          label: school.lastScannedAtUtc != null
              ? formatWibTime(school.lastScannedAtUtc!)
              : 'NPSN ${school.npsn}',
        ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.textSecondary,
      ),
      showBottomDivider: showBottomDivider,
      onTap: onTap,
    );
  }
}

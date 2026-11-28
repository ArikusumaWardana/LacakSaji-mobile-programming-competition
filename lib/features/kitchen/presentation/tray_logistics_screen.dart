import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../traceability/domain/traceability_models.dart';
import '../../traceability/presentation/traceability_providers.dart';

enum _TrayLogisticsFilter {
  all('Semua'),
  needsReturnCheck('Perlu Verifikasi'),
  needsSanitation('Perlu Sanitasi'),
  verified('Terverifikasi');

  const _TrayLogisticsFilter(this.label);

  final String label;
}

/// SPPG Kitchen Reverse Logistics & Tray Sanitation verification screen.
class TrayLogisticsScreen extends ConsumerStatefulWidget {
  const TrayLogisticsScreen({super.key});

  @override
  ConsumerState<TrayLogisticsScreen> createState() =>
      _TrayLogisticsScreenState();
}

class _TrayLogisticsScreenState extends ConsumerState<TrayLogisticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _TrayLogisticsFilter _filter = _TrayLogisticsFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrayReturnLogItem> _applyFilters(List<TrayReturnLogItem> items) {
    return items.where((item) {
      if (_searchQuery.isNotEmpty) {
        final match =
            (item.schoolName ?? '').toLowerCase().contains(_searchQuery) ||
            (item.menuName ?? '').toLowerCase().contains(_searchQuery) ||
            (item.batchCode ?? '').toLowerCase().contains(_searchQuery);
        if (!match) {
          return false;
        }
      }
      return switch (_filter) {
        _TrayLogisticsFilter.all => true,
        _TrayLogisticsFilter.needsReturnCheck =>
          item.returnStatus == TrayReturnStatus.pendingReturn ||
              item.returnStatus == TrayReturnStatus.inReturnTransit,
        _TrayLogisticsFilter.needsSanitation =>
          item.sanitizationStatus != TraySanitizationStatus.sanitizedVerified,
        _TrayLogisticsFilter.verified =>
          item.sanitizationStatus == TraySanitizationStatus.sanitizedVerified,
      };
    }).toList(growable: false);
  }

  Future<void> _openVerificationSheet(TrayReturnLogItem item) async {
    final kitchen = ref.read(authControllerProvider).kitchen;
    final actorId = ref.read(authControllerProvider).profile?.id;
    if (kitchen == null) {
      return;
    }

    final result = await showModalBottomSheet<_SanitationVerificationSubmission>(
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
      builder: (_) => _TraySanitationSheet(item: item),
    );

    if (result == null || !mounted) {
      return;
    }

    final isOffline = ref.read(isOfflineProvider).value ?? false;
    final updated = await ref
        .read(traceabilityRepositoryProvider)
        .verifyKitchenTrayReturnAndSanitation(
          sppgId: kitchen.id,
          item: item,
          verifiedReturnedCount: result.verifiedReturnedCount,
          checklist: result.checklist,
          isOffline: isOffline,
          verifierUserId: actorId,
          notes: result.notes,
        );
    invalidateTraceabilityProviders(ref);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isPendingSync
              ? 'Verifikasi ompreng disimpan offline di HP (${updated.sanitizationStatus.label}).'
              : 'Verifikasi ompreng dan sanitasi berhasil disimpan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(authControllerProvider).kitchen;
    final traysAsync = ref.watch(kitchenTrayReturnsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    if (kitchen == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(message: 'Profil dapur SPPG belum dimuat.'),
          ),
        ),
      );
    }

    final allItems = traysAsync.value ?? const <TrayReturnLogItem>[];
    final totalReturned = allItems.fold<int>(
      0,
      (sum, item) => sum + item.traysReturned,
    );
    final totalMissing = allItems.fold<int>(
      0,
      (sum, item) => sum + item.missingTrays,
    );
    final sanitizedCount = allItems
        .where(
          (i) => i.sanitizationStatus == TraySanitizationStatus.sanitizedVerified,
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          const MinimalTopHeader(
            contextLabel: 'Logistik Balik',
            title: 'Logistik & Sanitasi Wadah',
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(kitchenTrayReturnsProvider);
                await ref.read(kitchenTrayReturnsProvider.future);
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
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: _TraySummaryStrip(
                            totalReturned: totalReturned,
                            totalMissing: totalMissing,
                            sanitizedCount: sanitizedCount,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: SearchAndActionBar(
                            controller: _searchController,
                            hintText: 'Cari sekolah, menu, atau kode batch...',
                            onChanged: (value) => setState(
                              () => _searchQuery = value.trim().toLowerCase(),
                            ),
                            actionIcon: Icons.refresh_rounded,
                            actionTooltip: 'Muat Ulang Data Ompreng',
                            onActionTap: () =>
                                ref.invalidate(kitchenTrayReturnsProvider),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilterChipStrip<_TrayLogisticsFilter>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: _filter,
                          onSelected: (next) => setState(() => _filter = next),
                          items: _TrayLogisticsFilter.values
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
                          child: traysAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 4,
                              loadingLabel: 'Memuat data pengembalian ompreng...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(kitchenTrayReturnsProvider),
                            ),
                            data: (items) {
                              final filtered = _applyFilters(items);
                              if (filtered.isEmpty) {
                                return LacakEmptyState(
                                  icon: Icons.cleaning_services_rounded,
                                  title: items.isEmpty
                                      ? 'Belum ada laporan balik ompreng'
                                      : 'Tidak ada data yang cocok',
                                  message: items.isEmpty
                                      ? 'Data akan muncul otomatis saat sekolah mencatat Serah Terima Ompreng Kosong setelah jam makan.'
                                      : 'Ubah kata kunci pencarian atau pilih filter lain.',
                                  actionLabel: items.isEmpty
                                      ? 'Muat Ulang'
                                      : 'Tampilkan Semua',
                                  onAction: items.isEmpty
                                      ? () => ref.invalidate(
                                            kitchenTrayReturnsProvider,
                                          )
                                      : () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _filter = _TrayLogisticsFilter.all;
                                          });
                                        },
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Daftar Pengembalian (${filtered.length})',
                                    style: AppTypography.titleSection,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  for (var i = 0; i < filtered.length; i++)
                                    _TrayReturnTile(
                                      item: filtered[i],
                                      showBottomDivider: i < filtered.length - 1,
                                      onTap: () =>
                                          _openVerificationSheet(filtered[i]),
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
        ],
      ),
    );
  }
}

class _TraySummaryStrip extends StatelessWidget {
  const _TraySummaryStrip({
    required this.totalReturned,
    required this.totalMissing,
    required this.sanitizedCount,
  });

  final int totalReturned;
  final int totalMissing;
  final int sanitizedCount;

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
            _MiniMetric(label: 'Ompreng Kembali', value: '$totalReturned'),
            _MiniMetric(
              label: 'Selisih / Hilang',
              value: '$totalMissing',
              warn: totalMissing > 0,
            ),
            _MiniMetric(label: 'Tersanitasi', value: '$sanitizedCount'),
          ];
          if (constraints.maxWidth < 290 || textScale >= 1.3) {
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

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
          style: AppTypography.tabular(
            AppTypography.displayStatus.copyWith(
              color: warn ? AppColors.warnFg : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrayReturnTile extends StatelessWidget {
  const _TrayReturnTile({
    required this.item,
    required this.showBottomDivider,
    required this.onTap,
  });

  final TrayReturnLogItem item;
  final bool showBottomDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVerified =
        item.sanitizationStatus == TraySanitizationStatus.sanitizedVerified;
    final hasMissing = item.missingTrays > 0;

    final Color statusColor = isVerified
        ? AppColors.safeFg
        : (hasMissing ? AppColors.warnFg : AppColors.primary);
    final Color thumbBg = isVerified
        ? AppColors.safeBg
        : (hasMissing ? AppColors.warnBg : AppColors.surfaceSoft);

    final schoolLabel = (item.schoolName?.isNotEmpty ?? false)
        ? item.schoolName!
        : 'Sekolah Mitra';
    final menuLabel = item.menuName ?? item.batchCode ?? 'Batch MBG';

    return BorderlessThumbTile(
      title: '$schoolLabel · $menuLabel',
      statusText:
          '${item.sanitizationStatus.label} (${item.checklist.completedCount}/3 langkah)',
      statusColor: statusColor,
      fallbackIcon: isVerified
          ? Icons.verified_rounded
          : Icons.cleaning_services_rounded,
      fallbackBgColor: thumbBg,
      fallbackIconColor: statusColor,
      showBottomDivider: showBottomDivider,
      onTap: onTap,
      metadata: [
        BorderlessMetaItem(
          icon: Icons.inventory_2_rounded,
          label: 'Kembali ${item.traysReturned}/${item.traysSent}',
        ),
        if (hasMissing)
          BorderlessMetaItem(
            icon: Icons.warning_amber_rounded,
            label: 'Selisih ${item.missingTrays}',
          ),
        if (item.isPendingSync)
          const BorderlessMetaItem(
            icon: Icons.cloud_off_rounded,
            label: 'Belum Terkirim',
          ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SanitationVerificationSubmission {
  const _SanitationVerificationSubmission({
    required this.verifiedReturnedCount,
    required this.checklist,
    required this.notes,
  });

  final int verifiedReturnedCount;
  final TraySanitationChecklist checklist;
  final String notes;
}

class _TraySanitationSheet extends StatefulWidget {
  const _TraySanitationSheet({required this.item});

  final TrayReturnLogItem item;

  @override
  State<_TraySanitationSheet> createState() => _TraySanitationSheetState();
}

class _TraySanitationSheetState extends State<_TraySanitationSheet> {
  late final TextEditingController _notesController;
  late int _verifiedReturnedCount;
  late TraySanitationChecklist _checklist;

  @override
  void initState() {
    super.initState();
    _verifiedReturnedCount = widget.item.traysReturned;
    _checklist = widget.item.checklist;
    _notesController = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final missing = (widget.item.traysSent - _verifiedReturnedCount) > 0
        ? (widget.item.traysSent - _verifiedReturnedCount)
        : 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + viewInsets.bottom,
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
                      'Verifikasi & Sanitasi Ompreng',
                      style: AppTypography.titleSection,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Tutup',
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.item.schoolName ?? 'Sekolah Mitra'} · ${widget.item.menuName ?? widget.item.batchCode ?? 'Batch MBG'}',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dikirim: ${widget.item.traysSent} · Kembali: $_verifiedReturnedCount',
                            style: AppTypography.tabular(
                              AppTypography.titleItem,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            missing > 0
                                ? 'Selisih $missing ompreng belum kembali'
                                : 'Jumlah ompreng sesuai',
                            style: AppTypography.captionMuted.copyWith(
                              color: missing > 0
                                  ? AppColors.warnFg
                                  : AppColors.safeFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kurangi 1 ompreng',
                      onPressed: _verifiedReturnedCount <= 0
                          ? null
                          : () => setState(() => _verifiedReturnedCount--),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(
                          AppSpacing.minTouchTarget,
                          AppSpacing.minTouchTarget,
                        ),
                        backgroundColor: AppColors.surfaceBase,
                      ),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: 'Tambah 1 ompreng',
                      onPressed: () =>
                          setState(() => _verifiedReturnedCount++),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(
                          AppSpacing.minTouchTarget,
                          AppSpacing.minTouchTarget,
                        ),
                        backgroundColor: AppColors.surfaceBase,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Standar Pencucian & Sanitasi Wadah',
                style: AppTypography.titleItem,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Cuci dengan sabun food-grade',
                  style: AppTypography.bodyLarge,
                ),
                value: _checklist.foodGradeSoapWash,
                onChanged: (v) => setState(
                  () => _checklist = _checklist.copyWith(
                    foodGradeSoapWash: v ?? false,
                  ),
                ),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Bilas air panas atau mengalir',
                  style: AppTypography.bodyLarge,
                ),
                value: _checklist.hotRunningRinse,
                onChanged: (v) => setState(
                  () => _checklist = _checklist.copyWith(
                    hotRunningRinse: v ?? false,
                  ),
                ),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Tiris di rak tertutup dan higienis',
                  style: AppTypography.bodyLarge,
                ),
                value: _checklist.coveredDrying,
                onChanged: (v) => setState(
                  () => _checklist = _checklist.copyWith(
                    coveredDrying: v ?? false,
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              LacakTextField(
                label: 'Catatan Kondisi Wadah (Opsional)',
                controller: _notesController,
                hintText: 'Contoh: Semua wadah bersih dan siap pakai ulang',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              LacakPrimaryButton(
                label: 'Simpan Verifikasi & Sanitasi',
                icon: Icons.verified_rounded,
                onPressed: () {
                  Navigator.of(context).pop(
                    _SanitationVerificationSubmission(
                      verifiedReturnedCount: _verifiedReturnedCount,
                      checklist: _checklist,
                      notes: _notesController.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
import '../domain/kitchen_models.dart';

enum _IngredientHistoryFilter {
  all('Semua'),
  highRisk('Risiko Tinggi'),
  expiringSoon('Akan Kedaluwarsa');

  const _IngredientHistoryFilter(this.label);

  final String label;
}

/// D06: Upstream raw ingredient supplier, batch lot, and expiry history screen.
class IngredientHistoryScreen extends ConsumerStatefulWidget {
  const IngredientHistoryScreen({super.key});

  @override
  ConsumerState<IngredientHistoryScreen> createState() =>
      _IngredientHistoryScreenState();
}

class _IngredientHistoryScreenState
    extends ConsumerState<IngredientHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _IngredientHistoryFilter _filter = _IngredientHistoryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<IngredientLogItem> _applyFilters(List<IngredientLogItem> items) {
    final nowLocal = DateTime.now();
    return items.where((item) {
      if (_searchQuery.isNotEmpty) {
        final match =
            item.ingredientName.toLowerCase().contains(_searchQuery) ||
            item.supplierName.toLowerCase().contains(_searchQuery) ||
            item.supplierBatchNo.toLowerCase().contains(_searchQuery) ||
            (item.batchCode ?? '').toLowerCase().contains(_searchQuery);
        if (!match) {
          return false;
        }
      }
      return switch (_filter) {
        _IngredientHistoryFilter.all => true,
        _IngredientHistoryFilter.highRisk => item.isHighRisk,
        _IngredientHistoryFilter.expiringSoon =>
          item.isExpiringSoonAt(nowLocal),
      };
    }).toList(growable: false);
  }

  Future<void> _openAddLogSheet() async {
    final kitchen = ref.read(authControllerProvider).kitchen;
    final actorId = ref.read(authControllerProvider).profile?.id;
    if (kitchen == null) {
      return;
    }

    final batches = await ref.read(recentKitchenBatchesForLogProvider.future);
    if (!mounted) {
      return;
    }
    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Buat minimal satu batch makanan terlebih dahulu untuk menautkan catatan bahan baku.',
          ),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_NewIngredientSubmission>(
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
      builder: (_) => _AddIngredientLogSheet(batches: batches),
    );

    if (result == null || !mounted) {
      return;
    }

    final isOffline = ref.read(isOfflineProvider).value ?? false;
    final saved = await ref
        .read(traceabilityRepositoryProvider)
        .saveIngredientLogsForBatch(
          kitchen: kitchen,
          batch: result.batch,
          drafts: [result.draft],
          isOffline: isOffline,
          createdByUserId: actorId,
        );
    invalidateTraceabilityProviders(ref);
    if (!mounted || saved.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved.first.isPendingSync
              ? 'Catatan bahan baku disimpan offline di HP.'
              : 'Catatan bahan baku berhasil disimpan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(authControllerProvider).kitchen;
    final historyAsync = ref.watch(kitchenIngredientHistoryProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    if (kitchen == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(
              message: 'Profil dapur SPPG belum dimuat.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          const MinimalTopHeader(
            contextLabel: 'Pelacakan Hulu',
            title: 'Riwayat Bahan Baku',
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(kitchenIngredientHistoryProvider);
                await ref.read(kitchenIngredientHistoryProvider.future);
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
                            hintText: 'Cari bahan, pemasok, atau kode lot...',
                            onChanged: (value) => setState(
                              () => _searchQuery = value.trim().toLowerCase(),
                            ),
                            actionIcon: Icons.add_rounded,
                            actionTooltip: 'Catat Bahan Baku',
                            onActionTap: _openAddLogSheet,
                          ),
                        ),
                        FilterChipStrip<_IngredientHistoryFilter>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: _filter,
                          onSelected: (next) => setState(() => _filter = next),
                          items: _IngredientHistoryFilter.values
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
                          child: historyAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 4,
                              loadingLabel:
                                  'Memuat riwayat pemasok bahan baku...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () => ref.invalidate(
                                kitchenIngredientHistoryProvider,
                              ),
                            ),
                            data: (items) {
                              final filtered = _applyFilters(items);
                              if (filtered.isEmpty) {
                                return LacakEmptyState(
                                  icon: Icons.inventory_2_rounded,
                                  title: items.isEmpty
                                      ? 'Belum ada catatan bahan baku'
                                      : 'Tidak ada catatan yang cocok',
                                  message: items.isEmpty
                                      ? 'Catat pemasok, nomor lot, dan tanggal kedaluwarsa bahan berisiko tinggi (ayam, ikan, tahu, tempe, susu UHT).'
                                      : 'Ubah kata kunci pencarian atau pilih filter lain.',
                                  actionLabel: items.isEmpty
                                      ? 'Catat Bahan Baku'
                                      : 'Tampilkan Semua',
                                  onAction: items.isEmpty
                                      ? _openAddLogSheet
                                      : () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _filter =
                                                _IngredientHistoryFilter.all;
                                          });
                                        },
                                );
                              }

                              final nowLocal = DateTime.now();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Daftar Pasokan Hulu (${filtered.length})',
                                    style: AppTypography.titleSection,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  for (var i = 0; i < filtered.length; i++)
                                    _IngredientHistoryTile(
                                      item: filtered[i],
                                      nowLocal: nowLocal,
                                      showBottomDivider:
                                          i < filtered.length - 1,
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

class _IngredientHistoryTile extends StatelessWidget {
  const _IngredientHistoryTile({
    required this.item,
    required this.nowLocal,
    required this.showBottomDivider,
  });

  final IngredientLogItem item;
  final DateTime nowLocal;
  final bool showBottomDivider;

  @override
  Widget build(BuildContext context) {
    final isExpired = item.isExpiredAt(nowLocal);
    final isSoon = item.isExpiringSoonAt(nowLocal);

    final Color statusColor;
    final Color thumbBg;
    final Color thumbFg;
    final String statusText;

    if (isExpired) {
      statusColor = AppColors.dangerFg;
      thumbBg = AppColors.dangerBg;
      thumbFg = AppColors.dangerFg;
      statusText = 'Kedaluwarsa (${item.formattedExpiryDate})';
    } else if (isSoon) {
      statusColor = AppColors.warnFg;
      thumbBg = AppColors.warnBg;
      thumbFg = AppColors.warnFg;
      statusText = 'Hampir Kedaluwarsa (${item.formattedExpiryDate})';
    } else {
      statusColor = AppColors.primary;
      thumbBg = AppColors.surfaceSoft;
      thumbFg = AppColors.primary;
      statusText = 'Exp ${item.formattedExpiryDate}';
    }

    return BorderlessThumbTile(
      title: '${item.ingredientName} · ${item.supplierName}',
      statusText: statusText,
      statusColor: statusColor,
      fallbackIcon: item.isHighRisk
          ? Icons.egg_alt_rounded
          : Icons.inventory_2_rounded,
      fallbackBgColor: thumbBg,
      fallbackIconColor: thumbFg,
      showBottomDivider: showBottomDivider,
      metadata: [
        BorderlessMetaItem(
          icon: Icons.qr_code_rounded,
          label: 'Lot ${item.supplierBatchNo}',
        ),
        if (item.isHighRisk)
          const BorderlessMetaItem(
            icon: Icons.warning_amber_rounded,
            label: 'Risiko Tinggi',
          ),
        if (item.batchCode != null && item.batchCode!.isNotEmpty)
          BorderlessMetaItem(
            icon: Icons.receipt_long_rounded,
            label: item.batchCode!,
          ),
        if (item.isPendingSync)
          const BorderlessMetaItem(
            icon: Icons.cloud_off_rounded,
            label: 'Belum Terkirim',
          ),
      ],
    );
  }
}

class _NewIngredientSubmission {
  const _NewIngredientSubmission({required this.batch, required this.draft});

  final FoodBatchItem batch;
  final IngredientLogDraft draft;
}

class _AddIngredientLogSheet extends StatefulWidget {
  const _AddIngredientLogSheet({required this.batches});

  final List<FoodBatchItem> batches;

  @override
  State<_AddIngredientLogSheet> createState() => _AddIngredientLogSheetState();
}

class _AddIngredientLogSheetState extends State<_AddIngredientLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ingredientController = TextEditingController();
  final _supplierController = TextEditingController();
  final _lotController = TextEditingController();
  final _notesController = TextEditingController();

  late FoodBatchItem _selectedBatch;
  HighRiskIngredientPreset _preset = HighRiskIngredientPreset.ayamIkan;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 2));

  @override
  void initState() {
    super.initState();
    _selectedBatch = widget.batches.first;
    _ingredientController.text = _preset.defaultName;
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _supplierController.dispose();
    _lotController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _NewIngredientSubmission(
        batch: _selectedBatch,
        draft: IngredientLogDraft(
          ingredientName: _ingredientController.text.trim(),
          supplierName: _supplierController.text.trim(),
          supplierBatchNo: _lotController.text.trim(),
          expiryDate: _expiryDate,
          notes: _notesController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Catat Hulu Bahan Baku',
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tautkan ke Batch Makanan',
                  style: AppTypography.labelTag.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBatch.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
                  ),
                  items: widget.batches
                      .map(
                        (batch) => DropdownMenuItem<String>(
                          value: batch.id,
                          child: Text(
                            '${batch.batchCode} · ${batch.menuName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (nextId) {
                    if (nextId == null) return;
                    final found = widget.batches.where((b) => b.id == nextId);
                    if (found.isNotEmpty) {
                      setState(() => _selectedBatch = found.first);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FilterChipStrip<HighRiskIngredientPreset>(
                  padding: EdgeInsets.zero,
                  selectedValue: _preset,
                  onSelected: (selected) {
                    setState(() {
                      _preset = selected;
                      if (selected != HighRiskIngredientPreset.lainnya) {
                        _ingredientController.text = selected.defaultName;
                      } else {
                        _ingredientController.clear();
                      }
                    });
                  },
                  items: HighRiskIngredientPreset.values
                      .map(
                        (p) => FilterChipItem(
                          value: p,
                          label: p.defaultName,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.md),
                LacakTextField(
                  label: 'Nama Bahan Baku',
                  controller: _ingredientController,
                  hintText: 'Contoh: Ayam Fillet Dada / Susu UHT',
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Masukkan nama bahan minimal 2 karakter.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                LacakTextField(
                  label: 'Nama Pemasok / Vendor',
                  controller: _supplierController,
                  hintText: 'Contoh: CV Berkah Unggas Banyumas',
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Masukkan nama pemasok.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                LacakTextField(
                  label: 'Kode Lot / Batch Pemasok',
                  controller: _lotController,
                  hintText: 'Contoh: LOT-AYM-2411A',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Masukkan kode lot / batch kemasan.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                LacakSecondaryButton(
                  label:
                      'Kedaluwarsa: ${formatDateDdMmmYyyy(_expiryDate)}',
                  icon: Icons.calendar_today_rounded,
                  onPressed: _pickExpiryDate,
                ),
                const SizedBox(height: AppSpacing.md),
                LacakTextField(
                  label: 'Catatan Tambahan (Opsional)',
                  controller: _notesController,
                  hintText: 'Contoh: Diterima pukul 04.30 WIB kondisi dingin',
                ),
                const SizedBox(height: AppSpacing.lg),
                LacakPrimaryButton(
                  label: 'Simpan Catatan Bahan',
                  icon: Icons.check_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

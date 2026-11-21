import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/media/live_camera_webp_service.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../data/hybrid_vision_service.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

const List<({int value, String label})> _kWasteQuickOptions = [
  (value: 0, label: 'Habis (0%)'),
  (value: 25, label: 'Sedikit (25%)'),
  (value: 50, label: 'Setengah (50%)'),
  (value: 75, label: 'Utuh (75%+)'),
];

/// G07: School Plate-Waste evaluation screen (1-5 ompreng photos, quick-pick waste %, submit to SPPG).
class PlateWasteScreen extends ConsumerStatefulWidget {
  const PlateWasteScreen({super.key});

  @override
  ConsumerState<PlateWasteScreen> createState() => _PlateWasteScreenState();
}

class _PlateWasteScreenState extends ConsumerState<PlateWasteScreen> {
  String? _selectedBatchId;
  final List<CapturedWebpPhoto> _photos = [];
  bool _capturing = false;
  bool _analyzing = false;
  bool _submitting = false;
  bool _aiAssisted = false;
  String? _analysisNote;
  String? _estimationSourceLabel;
  int? _estimatedCarbPct;
  int? _estimatedProteinPct;
  int? _estimatedVegPct;

  int? _carbWastePct;
  int? _proteinWastePct;
  int? _vegWastePct;
  String? _validationError;

  Future<void> _openBatchPicker({
    required List<SchoolBatchOption> batches,
    required String activeBatchId,
  }) async {
    final chosen = await showDialog<SchoolBatchOption>(
      context: context,
      builder: (_) => _BatchPickerDialog(
        batches: batches,
        selectedBatchId: activeBatchId,
        nowUtc: DateTime.now().toUtc(),
      ),
    );
    if (chosen != null && mounted && chosen.batchId != _selectedBatchId) {
      setState(() => _selectedBatchId = chosen.batchId);
    }
  }

  Future<void> _addOmprengPhoto(List<SchoolBatchOption> batches) async {
    if (_capturing || _submitting || _photos.length >= 5) {
      return;
    }
    setState(() {
      _capturing = true;
      _validationError = null;
    });
    try {
      final photo =
          await ref.read(liveCameraWebpServiceProvider).captureAndCompress();
      if (!mounted) {
        return;
      }
      if (photo == null) {
        setState(() => _capturing = false);
        return;
      }

      setState(() {
        _photos.add(photo);
        _capturing = false;
        _analyzing = true;
      });

      final allBytes = _photos.map((p) => p.bytes).toList(growable: false);
      final vision = ref.read(hybridVisionServiceProvider);
      final isOffline = ref.read(isOfflineProvider).value ?? false;

      final selectedBatch = batches.where((b) => b.batchId == _selectedBatchId);
      final menuName = selectedBatch.isNotEmpty
          ? selectedBatch.first.menuName
          : 'Menu Makan Bergizi Gratis';

      var nextCarb = _carbWastePct;
      var nextProtein = _proteinWastePct;
      var nextVeg = _vegWastePct;
      String? note;
      var sourceLabel = 'Hasil Analisis AI';

      final cloudEstimate = isOffline
          ? const CloudVisionResult(
              ok: false,
              provider: 'offline_mode',
              fallbackRequired: true,
              summaryText: 'Mode Tanpa Sinyal. Menggunakan perkiraan cepat di HP.',
            )
          : await vision.analyzeCloudPlateWaste(
              photoBytesList: allBytes,
              menuName: menuName,
              isOffline: isOffline,
            );

      if (!mounted) {
        return;
      }

      if (cloudEstimate.ok) {
        nextCarb = cloudEstimate.carbWastePct != null
            ? _snapPct(cloudEstimate.carbWastePct!)
            : nextCarb;
        nextProtein = cloudEstimate.proteinWastePct != null
            ? _snapPct(cloudEstimate.proteinWastePct!)
            : nextProtein;
        nextVeg = cloudEstimate.vegWastePct != null
            ? _snapPct(cloudEstimate.vegWastePct!)
            : nextVeg;
        note = cloudEstimate.summaryText;
        sourceLabel = 'Hasil Analisis AI';
      } else {
        final localEstimate = await vision.estimatePlateWasteOnDevice(allBytes);
        if (!mounted) {
          return;
        }
        nextCarb = localEstimate.estimatedCarbWastePct != null
            ? _snapPct(localEstimate.estimatedCarbWastePct!)
            : nextCarb;
        nextProtein = localEstimate.estimatedProteinWastePct != null
            ? _snapPct(localEstimate.estimatedProteinWastePct!)
            : nextProtein;
        nextVeg = localEstimate.estimatedVegWastePct != null
            ? _snapPct(localEstimate.estimatedVegWastePct!)
            : nextVeg;
        note = isOffline
            ? localEstimate.summaryText
            : '${cloudEstimate.summaryText} Angka sementara dihitung dari perkiraan perangkat, sesuaikan bila perlu.';
        sourceLabel = isOffline
            ? 'Perkiraan Cepat di HP'
            : 'Perkiraan Perangkat (AI Server Belum Aktif)';
      }

      if (!mounted) {
        return;
      }
      setState(() {
        if (nextCarb != null && nextProtein != null && nextVeg != null) {
          _carbWastePct = nextCarb;
          _proteinWastePct = nextProtein;
          _vegWastePct = nextVeg;
          _estimatedCarbPct = nextCarb;
          _estimatedProteinPct = nextProtein;
          _estimatedVegPct = nextVeg;
          _estimationSourceLabel = sourceLabel;
          _aiAssisted = true;
        }
        _analyzing = false;
        _analysisNote = note;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _capturing = false;
        _analyzing = false;
        _analysisNote = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  int _snapPct(int raw) {
    if (raw < 12) return 0;
    if (raw < 38) return 25;
    if (raw < 63) return 50;
    return 75;
  }

  Future<void> _submitFeedback(String batchId) async {
    if (_submitting) {
      return;
    }
    if (_carbWastePct == null ||
        _proteinWastePct == null ||
        _vegWastePct == null) {
      setState(() {
        _validationError =
            'Lengkapi pilihan sisa Nasi, Lauk, dan Sayuran (atau unggah foto ompreng untuk mengisi otomatis) sebelum mengirim.';
      });
      return;
    }
    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _validationError = null;
    });
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    try {
      final syncedNow = await ref.read(schoolRepositoryProvider).submitPlateWasteLog(
            school: school,
            batchId: batchId,
            carbWastePct: _carbWastePct!,
            proteinWastePct: _proteinWastePct!,
            vegWastePct: _vegWastePct!,
            photos: List.unmodifiable(_photos),
            aiAssisted: _aiAssisted,
            isOffline: isOffline,
          );
      invalidateSchoolProviders(ref);
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _photos.clear();
        _aiAssisted = false;
        _analysisNote = null;
        _estimationSourceLabel = null;
        _estimatedCarbPct = null;
        _estimatedProteinPct = null;
        _estimatedVegPct = null;
        _carbWastePct = null;
        _proteinWastePct = null;
        _vegWastePct = null;
        _validationError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedNow
                ? 'Evaluasi sisa makanan berhasil dikirim ke Dapur SPPG.'
                : 'Evaluasi sisa makanan disimpan di HP dan akan dikirim saat sinyal kembali.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim evaluasi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(authControllerProvider).school;
    final batchesAsync = ref.watch(selectableWasteBatchesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Sisa Makanan Siswa')),
      body: SafeArea(
        child: school == null
            ? SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPad),
                child: const LacakErrorState(
                  message: 'Profil sekolah belum dimuat.',
                ),
              )
            : batchesAsync.when(
                loading: () => SingleChildScrollView(
                  padding: EdgeInsets.all(horizontalPad),
                  child: const LacakSkeletonList(
                    itemCount: 3,
                    loadingLabel: 'Memuat daftar batch hari ini...',
                  ),
                ),
                error: (error, _) => SingleChildScrollView(
                  padding: EdgeInsets.all(horizontalPad),
                  child: LacakErrorState(
                    message: error.toString(),
                    onRetry: () =>
                        ref.invalidate(selectableWasteBatchesProvider),
                  ),
                ),
                data: (batches) {
                  if (batches.isEmpty) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        AppSpacing.lg,
                        horizontalPad,
                        AppSpacing.xxl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: const LacakEmptyState(
                            icon: Icons.restaurant_rounded,
                            title: 'Belum ada batch kiriman untuk dievaluasi',
                            message:
                                'Pindai QR makanan masuk dari Dapur SPPG terlebih dahulu agar batch muncul di sini.',
                          ),
                        ),
                      ),
                    );
                  }

                  final activeBatch = batches.firstWhere(
                    (b) => b.batchId == _selectedBatchId,
                    orElse: () => batches.first,
                  );
                  final activeBatchId = activeBatch.batchId;

                  return Column(
                    children: [
                      Expanded(
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
                                  Text(
                                    '1. Pilih Batch Makanan',
                                    style: AppTypography.titleSection,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _BatchPickerTrigger(
                                    batch: activeBatch,
                                    nowUtc: DateTime.now().toUtc(),
                                    onTap: () => _openBatchPicker(
                                      batches: batches,
                                      activeBatchId: activeBatchId,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.xs,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '2. Foto Sampel Ompreng (3-5 foto)',
                                        style: AppTypography.titleSection,
                                      ),
                                      LacakStatusTag(
                                        level: _photos.isEmpty
                                            ? LacakStatusLevel.warning
                                            : LacakStatusLevel.safe,
                                        label: '${_photos.length} / 5 foto',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Potret 3-5 ompreng bekas makan siswa secara acak setelah jam makan selesai.',
                                    style: AppTypography.bodyMedium,
                                  ),
                                  if (_photos.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      children: List.generate(
                                        _photos.length,
                                        (index) => Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 84,
                                              height: 84,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppSpacing.radiusControl,
                                                    ),
                                                border: Border.all(
                                                  color:
                                                      AppColors.borderHairline,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Image.memory(
                                                _photos[index].bytes,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: -8,
                                              right: -8,
                                              child: IconButton(
                                                tooltip: 'Hapus foto',
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                onPressed: () => setState(() {
                                                  _photos.removeAt(index);
                                                  if (_photos.isEmpty) {
                                                    _aiAssisted = false;
                                                    _analysisNote = null;
                                                    _estimationSourceLabel =
                                                        null;
                                                    _estimatedCarbPct = null;
                                                    _estimatedProteinPct = null;
                                                    _estimatedVegPct = null;
                                                  }
                                                }),
                                                icon: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: AppColors
                                                            .surfaceBase,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    size: 16,
                                                    color: AppColors.dangerFg,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.md),
                                  LacakSecondaryButton(
                                    label: _photos.length >= 5
                                        ? 'Maksimal 5 Foto Tercapai'
                                        : 'Tambah Foto Ompreng (${_photos.length}/5)',
                                    icon: Icons.photo_camera_rounded,
                                    isLoading: _capturing,
                                    onPressed: _photos.length >= 5
                                        ? null
                                        : () => _addOmprengPhoto(batches),
                                  ),
                                  if (_analyzing) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    const LinearProgressIndicator(
                                      color: AppColors.primary,
                                      backgroundColor: AppColors.surfaceSubtle,
                                      minHeight: 3,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Menunggu hasil analisis AI dari server...',
                                      style: AppTypography.bodyMedium,
                                    ),
                                  ],
                                  if (_estimatedCarbPct != null &&
                                      _estimatedProteinPct != null &&
                                      _estimatedVegPct != null) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    _EstimationResultSummaryCard(
                                      photoCount: _photos.length,
                                      sourceLabel: _estimationSourceLabel ??
                                          'Cek Cepat di HP',
                                      isUpdatingCloud: _analyzing,
                                      carbPct: _estimatedCarbPct!,
                                      proteinPct: _estimatedProteinPct!,
                                      vegPct: _estimatedVegPct!,
                                      note: _analysisNote,
                                    ),
                                  ] else if (!_analyzing &&
                                      _analysisNote != null) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.fact_check_rounded,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            _analysisNote!,
                                            style: AppTypography.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xl),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.xs,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '3. Estimasi Sisa Per Komponen',
                                        style: AppTypography.titleSection,
                                      ),
                                      if (_aiAssisted)
                                        const LacakStatusTag(
                                          level: LacakStatusLevel.safe,
                                          label: 'Terisi Otomatis',
                                          icon: Icons.fact_check_rounded,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  LacakSectionSurface.separated(
                                    children: [
                                      _WasteComponentSelector(
                                        title: 'Nasi / Karbohidrat',
                                        selectedValue: _carbWastePct,
                                        onChanged: (v) => setState(() {
                                          _carbWastePct = v;
                                          _validationError = null;
                                        }),
                                      ),
                                      _WasteComponentSelector(
                                        title: 'Lauk / Protein',
                                        selectedValue: _proteinWastePct,
                                        onChanged: (v) => setState(() {
                                          _proteinWastePct = v;
                                          _validationError = null;
                                        }),
                                      ),
                                      _WasteComponentSelector(
                                        title: 'Sayuran',
                                        selectedValue: _vegWastePct,
                                        onChanged: (v) => setState(() {
                                          _vegWastePct = v;
                                          _validationError = null;
                                        }),
                                      ),
                                    ],
                                  ),
                                  if (_validationError != null) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          size: 20,
                                          color: AppColors.dangerFg,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            _validationError!,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  color: AppColors.dangerFg,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceBase,
                          border: Border(
                            top: BorderSide(
                              color: AppColors.borderHairline,
                              width: 1,
                            ),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          AppSpacing.md,
                          horizontalPad,
                          AppSpacing.md,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: LacakPrimaryButton(
                              label: 'Kirim Evaluasi ke Dapur SPPG',
                              icon: Icons.send_rounded,
                              isLoading: _submitting,
                              onPressed: () => _submitFeedback(activeBatchId),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _WasteComponentSelector extends StatelessWidget {
  const _WasteComponentSelector({
    required this.title,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final int? selectedValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = selectedValue;
    final isHigh = value != null && value >= 50;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: AppTypography.titleItem),
              Text(
                value == null
                    ? 'Belum dipilih'
                    : (value == 75 ? '75%+' : '$value%'),
                style: AppTypography.tabular(
                  AppTypography.titleItem.copyWith(
                    color: value == null
                        ? AppColors.textMuted
                        : (isHigh ? AppColors.warnFg : AppColors.primary),
                    fontWeight:
                        value == null ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth =
                  (constraints.maxWidth - AppSpacing.sm) / 2;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _kWasteQuickOptions.map((option) {
                  final selected = selectedValue == option.value;
                  return SizedBox(
                    width: cellWidth > 100
                        ? cellWidth
                        : constraints.maxWidth,
                    child: Material(
                      color: selected
                          ? AppColors.primaryTint
                          : AppColors.surfaceBase,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusControl,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.borderHairline,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => onChanged(option.value),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusControl,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSpacing.minTouchTarget,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                            child: Center(
                              child: Text(
                                option.label,
                                textAlign: TextAlign.center,
                                style: AppTypography.tabular(
                                  AppTypography.labelTag.copyWith(
                                    color: selected
                                        ? AppColors.onPrimaryTint
                                        : AppColors.textPrimary,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EstimationResultSummaryCard extends StatelessWidget {
  const _EstimationResultSummaryCard({
    required this.photoCount,
    required this.sourceLabel,
    required this.isUpdatingCloud,
    required this.carbPct,
    required this.proteinPct,
    required this.vegPct,
    this.note,
  });

  final int photoCount;
  final String sourceLabel;
  final bool isUpdatingCloud;
  final int carbPct;
  final int proteinPct;
  final int vegPct;
  final String? note;

  String _formatPct(int value) => value >= 75 ? '75%+' : '$value%';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.safeBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        border: Border.all(color: AppColors.safeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Hasil Estimasi ($photoCount Foto)',
                style: AppTypography.titleItem.copyWith(
                  color: AppColors.safeFg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
                  border: Border.all(color: AppColors.safeBorder, width: 1),
                ),
                child: Text(
                  isUpdatingCloud ? 'Menyempurnakan...' : sourceLabel,
                  style: AppTypography.captionLegal.copyWith(
                    color: AppColors.safeFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
              border: Border.all(color: AppColors.borderHairline, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _EstimatedComponentStat(
                      label: 'Nasi',
                      valueText: _formatPct(carbPct),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _EstimatedComponentStat(
                      label: 'Lauk',
                      valueText: _formatPct(proteinPct),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _EstimatedComponentStat(
                      label: 'Sayur',
                      valueText: _formatPct(vegPct),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              note!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'Angka di bagian 3 telah diisi otomatis. Ketuk tombol persentase di bawah jika ingin menyesuaikan.',
            style: AppTypography.captionLegal.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimatedComponentStat extends StatelessWidget {
  const _EstimatedComponentStat({
    required this.label,
    required this.valueText,
  });

  final String label;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.captionLegal.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valueText,
            style: AppTypography.tabular(
              AppTypography.titleItem.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBatchTimestamp(DateTime sealedAtUtc, DateTime nowUtc) {
  if (isSameWibCalendarDay(sealedAtUtc, nowUtc)) {
    return 'Hari ini, ${formatWibTime(sealedAtUtc)}';
  }
  return formatWibDateTime(sealedAtUtc);
}

class _BatchPickerTrigger extends StatelessWidget {
  const _BatchPickerTrigger({
    required this.batch,
    required this.nowUtc,
    required this.onTap,
  });

  final SchoolBatchOption batch;
  final DateTime nowUtc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pilih batch makanan, terpilih ${batch.menuName}',
      child: Material(
        color: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          side: const BorderSide(color: AppColors.borderHairline, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.primaryButtonMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          batch.menuName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleItem.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${batch.batchCode} · ${_formatBatchTimestamp(batch.sealedAtUtc, nowUtc)}',
                          style: AppTypography.tabular(
                            AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.unfold_more_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
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

class _BatchPickerDialog extends StatefulWidget {
  const _BatchPickerDialog({
    required this.batches,
    required this.selectedBatchId,
    required this.nowUtc,
  });

  final List<SchoolBatchOption> batches;
  final String selectedBatchId;
  final DateTime nowUtc;

  @override
  State<_BatchPickerDialog> createState() => _BatchPickerDialogState();
}

class _BatchPickerDialogState extends State<_BatchPickerDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Dialog(
      backgroundColor: AppColors.bgCanvas,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
        side: const BorderSide(color: AppColors.borderHairline, width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSpacing.tabletFormMaxWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Batch Makanan',
                          style: AppTypography.titleSection,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.batches.length} batch tersedia. Gulir untuk memilih.',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
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
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSurface,
                    ),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: widget.batches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final batch = widget.batches[index];
                        final isSelected =
                            batch.batchId == widget.selectedBatchId;
                        return Material(
                          color: isSelected
                              ? AppColors.primaryTint
                              : AppColors.surfaceBase,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(batch),
                            child: Semantics(
                              button: true,
                              selected: isSelected,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: AppSpacing.selectionRowMinHeight,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              batch.menuName,
                                              style: AppTypography.titleItem
                                                  .copyWith(
                                                    color: isSelected
                                                        ? AppColors
                                                              .onPrimaryTint
                                                        : AppColors.textPrimary,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${batch.batchCode} · ${_formatBatchTimestamp(batch.sealedAtUtc, widget.nowUtc)}',
                                              style: AppTypography.tabular(
                                                AppTypography.bodyMedium
                                                    .copyWith(
                                                      color: isSelected
                                                          ? AppColors
                                                                .onPrimaryTint
                                                          : AppColors
                                                                .textSecondary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: AppSpacing.sm),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 22,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LacakSecondaryButton(
                label: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

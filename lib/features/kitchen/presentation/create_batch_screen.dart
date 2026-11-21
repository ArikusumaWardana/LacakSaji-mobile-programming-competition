import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/media/live_camera_webp_service.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/text_scale_provider.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

/// D02: Create food batch broken into a 2-step progressive wizard
/// with automatic local draft persistence in SharedPreferences.
class CreateBatchScreen extends ConsumerStatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  ConsumerState<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends ConsumerState<CreateBatchScreen> {
  static const String _draftPrefKey = 'lacak_draft_create_batch_v1';

  final _step1FormKey = GlobalKey<FormState>();
  final _menuController = TextEditingController();
  final _portionController = TextEditingController(text: '150');

  int _currentStep = 1;
  FoodRiskCategory _riskCategory = FoodRiskCategory.medium;
  CapturedWebpPhoto? _capturedPhoto;
  bool _capturingPhoto = false;
  bool _submitting = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreLocalDraft();
      }
    });
  }

  @override
  void dispose() {
    _menuController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  void _restoreLocalDraft() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs?.getString(_draftPrefKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        final menu = (map['menu_name'] as String?) ?? '';
        if (menu.isNotEmpty) {
          _menuController.text = menu;
        }
        final portions = (map['portion_count'] as String?) ?? '';
        if (portions.isNotEmpty) {
          _portionController.text = portions;
        }
        final riskDb = map['risk_category'] as String?;
        if (riskDb != null) {
          _riskCategory = FoodRiskCategory.fromDb(riskDb);
        }
        _currentStep = ((map['step'] as int?) ?? 1).clamp(1, 2);
      });
    } catch (_) {
      // Ignore malformed draft.
    }
  }

  Future<void> _saveLocalDraft({int? nextStep}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) {
      return;
    }
    final payload = jsonEncode({
      'step': nextStep ?? _currentStep,
      'menu_name': _menuController.text.trim(),
      'portion_count': _portionController.text.trim(),
      'risk_category': _riskCategory.dbValue,
    });
    await prefs.setString(_draftPrefKey, payload);
  }

  Future<void> _clearLocalDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.remove(_draftPrefKey);
  }

  void _stepPortions(int delta) {
    final current = int.tryParse(_portionController.text.trim()) ?? 100;
    final next = (current + delta).clamp(1, 5000);
    setState(() {
      _portionController.text = '$next';
    });
    _saveLocalDraft();
  }

  Future<void> _nextFromStep1() async {
    if (!(_step1FormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _saveLocalDraft(nextStep: 2);
    if (!mounted) {
      return;
    }
    setState(() => _currentStep = 2);
  }

  Future<void> _goBackStep() async {
    if (_currentStep <= 1) {
      context.pop();
      return;
    }
    await _saveLocalDraft(nextStep: 1);
    if (!mounted) {
      return;
    }
    setState(() => _currentStep = 1);
  }

  Future<void> _capturePhoto() async {
    if (_capturingPhoto || _submitting) {
      return;
    }
    setState(() {
      _capturingPhoto = true;
      _photoError = null;
    });
    try {
      final captured =
          await ref.read(liveCameraWebpServiceProvider).captureAndCompress();
      if (!mounted) {
        return;
      }
      setState(() {
        _capturingPhoto = false;
        if (captured != null) {
          _capturedPhoto = captured;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _capturingPhoto = false;
        _photoError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final photo = _capturedPhoto;
    if (photo == null) {
      setState(() {
        _photoError =
            'Foto pengemasan wajib diambil langsung dari kamera sebelum mengunci segel.';
      });
      return;
    }

    final kitchen = ref.read(authControllerProvider).kitchen;
    if (kitchen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil dapur tidak ditemukan. Silakan masuk ulang.'),
        ),
      );
      return;
    }

    final portions = int.tryParse(_portionController.text.trim()) ?? 1;
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    setState(() => _submitting = true);
    try {
      final created = await ref.read(kitchenRepositoryProvider).createSealedBatch(
            kitchen: kitchen,
            menuName: _menuController.text.trim(),
            portionCount: portions,
            riskCategory: _riskCategory,
            photo: photo,
            isOffline: isOffline,
          );
      await _clearLocalDraft();
      invalidateKitchenProviders(ref);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created.isPendingSync
                ? 'Batch ${created.batchCode} dikunci di HP (Belum Terkirim).'
                : 'Batch ${created.batchCode} berhasil dikunci dan diunggah.',
          ),
        ),
      );
      context.pushReplacement(
        AppRoutes.batchDetailPath(created.id),
        extra: created,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(authControllerProvider).kitchen;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(
        title: const Text('Buat Batch & Segel QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: _currentStep > 1 ? 'Langkah Sebelumnya' : 'Kembali',
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
          onPressed: _goBackStep,
        ),
      ),
      body: SafeArea(
        child: kitchen == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LacakErrorState(
                  message: 'Profil dapur SPPG belum termuat.',
                ),
              )
            : Column(
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
                              LacakStepProgressHeader(
                                currentStep: _currentStep,
                                totalSteps: 2,
                                stepTitle: _currentStep == 1
                                    ? 'Detail Menu & Kategori Risiko'
                                    : 'Foto Pengemasan Langsung & Jam Segel',
                                stepSubtitle: _currentStep == 1
                                    ? 'Isi nama menu harian, jumlah porsi, dan pilih kategori risiko pangan untuk penentuan batas aman suhu BMKG.'
                                    : 'Potret makanan yang siap dikirim dengan kamera langsung, lalu kunci Segel QR Keamanan.',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              LacakAnimatedStepSwitcher(
                                currentStep: _currentStep,
                                child: _currentStep == 1
                                    ? _buildStep1MenuAndRisk()
                                    : _buildStep2LiveCameraAndSeal(isOffline),
                              ),
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
                        child: LacakAnimatedStepSwitcher(
                          currentStep: _currentStep,
                          child: _currentStep == 1
                              ? LacakPrimaryButton(
                                  label: 'Simpan & Lanjut ke Foto Pengemasan',
                                  icon: Icons.photo_camera_rounded,
                                  onPressed: _nextFromStep1,
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    LacakPrimaryButton(
                                      label: 'Kunci & Buat QR Segel',
                                      icon: Icons.qr_code_2_rounded,
                                      isLoading: _submitting,
                                      onPressed: _submit,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    LacakSecondaryButton(
                                      label: 'Ubah Detail Menu (Langkah 1)',
                                      onPressed:
                                          _submitting ? null : _goBackStep,
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

  Widget _buildStep1MenuAndRisk() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LacakTextField(
            label: 'Nama Menu Harian',
            controller: _menuController,
            hintText: 'Contoh: Nasi Ayam Goreng & Sayur Bening',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if (value == null || value.trim().length < 3) {
                return 'Masukkan nama menu minimal 3 karakter.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Jumlah Porsi (Ompreng)',
            style: AppTypography.labelTag.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PortionStepperButton(
                icon: Icons.remove_rounded,
                tooltip: 'Kurangi 10 porsi',
                onPressed: () => _stepPortions(-10),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _portionController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => _saveLocalDraft(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: AppTypography.tabular(
                    AppTypography.headlinePage.copyWith(fontSize: 20),
                  ),
                  decoration: const InputDecoration(
                    hintText: '150',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    final n = int.tryParse((value ?? '').trim());
                    if (n == null || n < 1) {
                      return 'Minimal 1 porsi.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _PortionStepperButton(
                icon: Icons.add_rounded,
                tooltip: 'Tambah 10 porsi',
                onPressed: () => _stepPortions(10),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Kategori Risiko Menu',
            style: AppTypography.labelTag.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...FoodRiskCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RiskCategoryOptionTile(
                category: category,
                selected: _riskCategory == category,
                onTap: () {
                  setState(() => _riskCategory = category);
                  _saveLocalDraft();
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _riskCategory.safetyNote,
                    style: AppTypography.tabular(
                      AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2LiveCameraAndSeal(bool isOffline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu Tersimpan (Langkah 1):',
                style: AppTypography.labelTag.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _menuController.text.trim(),
                style: AppTypography.titleItem,
              ),
              Text(
                '${_portionController.text.trim()} porsi · ${_riskCategory.label}',
                style: AppTypography.tabular(AppTypography.bodyMedium),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          constraints: _capturedPhoto == null
              ? const BoxConstraints(minHeight: 168)
              : const BoxConstraints(
                  minHeight: 168,
                  maxHeight: 220,
                ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            border: Border.all(
              color: _photoError != null
                  ? AppColors.dangerBorder
                  : AppColors.borderHairline,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _capturedPhoto == null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.photo_camera_rounded,
                        size: 36,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Belum ada foto pengemasan',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleItem,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Gunakan kamera langsung (akses galeri dinonaktifkan). Ukuran foto disesuaikan otomatis agar ringan dikirim.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                )
              : Image.memory(
                  _capturedPhoto!.bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
        ),
        if (_capturedPhoto != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.safeFg,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Foto pengemasan siap (${_capturedPhoto!.formattedSizeKb})',
                  style: AppTypography.tabular(
                    AppTypography.bodyMedium.copyWith(
                      color: AppColors.safeFg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_photoError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.dangerFg,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _photoError!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.dangerFg,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        LacakSecondaryButton(
          label: _capturedPhoto == null
              ? 'Ambil Foto Pengemasan'
              : 'Ambil Ulang Foto Kamera',
          icon: Icons.photo_camera_rounded,
          isLoading: _capturingPhoto,
          onPressed: _capturePhoto,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.schedule_rounded,
              size: 20,
              color: isOffline ? AppColors.infoFg : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOffline
                        ? 'Stempel Waktu: Waktu Perangkat (Dicek Saat Ada Sinyal)'
                        : 'Stempel Waktu: Dikunci otomatis dari Waktu Resmi Server',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const LacakStatusTag(
                      level: LacakStatusLevel.offline,
                      label: 'Mode Tanpa Sinyal',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RiskCategoryOptionTile extends StatelessWidget {
  const _RiskCategoryOptionTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final FoodRiskCategory category;
  final bool selected;
  final VoidCallback onTap;

  String _windowBadgeText() {
    return switch (category) {
      FoodRiskCategory.high => 'Maks 1,5 - 2 Jam',
      FoodRiskCategory.medium => 'Maks 3 - 3,5 Jam',
      FoodRiskCategory.low => 'Maks 4 - 6 Jam',
    };
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = selected ? AppColors.onPrimaryTint : AppColors.textPrimary;
    final subColor = selected
        ? AppColors.onPrimaryTint
        : AppColors.textSecondary;

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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          category.label,
                          style: AppTypography.titleItem.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.surfaceBase
                                : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusTag,
                            ),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _windowBadgeText(),
                            style: AppTypography.tabular(
                              AppTypography.captionLegal.copyWith(
                                color: fgColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.examples,
                      style: AppTypography.bodyMedium.copyWith(
                        color: subColor,
                      ),
                    ),
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

class _PortionStepperButton extends StatelessWidget {
  const _PortionStepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.borderHairline, width: 1),
          backgroundColor: AppColors.surfaceSubtle,
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 24, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

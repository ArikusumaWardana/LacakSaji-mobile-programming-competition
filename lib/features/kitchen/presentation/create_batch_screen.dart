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
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

/// D02: Editorial batch creation detail view with FramedHeroHeader photo preview,
/// clean risk filter chips, soft-filled inputs, and StickyBottomActionBar seal trigger.
class CreateBatchScreen extends ConsumerStatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  ConsumerState<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends ConsumerState<CreateBatchScreen> {
  static const String _draftPrefKey = 'lacak_draft_create_batch_v1';

  final _formKey = GlobalKey<FormState>();
  final _menuController = TextEditingController();
  final _portionController = TextEditingController(text: '150');

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
      });
    } catch (_) {
      // Ignore malformed draft.
    }
  }

  Future<void> _saveLocalDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) {
      return;
    }
    final payload = jsonEncode({
      'step': 1,
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
    final formValid = _formKey.currentState?.validate() ?? false;
    final photo = _capturedPhoto;
    if (photo == null) {
      setState(() {
        _photoError =
            'Foto pengemasan wajib diambil langsung dari kamera sebelum mengunci segel.';
      });
      return;
    }
    if (!formValid) {
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

    if (kitchen == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(
              message: 'Profil dapur SPPG belum termuat.',
            ),
          ),
        ),
      );
    }

    final liveMenuTitle = _menuController.text.trim().isEmpty
        ? 'Buat Batch Makanan Baru'
        : _menuController.text.trim();
    final portionLabel = _portionController.text.trim().isEmpty
        ? '0'
        : _portionController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth == double.infinity
                        ? double.infinity
                        : maxWidth + horizontalPad * 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: FramedHeroHeader(
                            height: 244,
                            image: _capturedPhoto != null
                                ? MemoryImage(_capturedPhoto!.bytes)
                                : null,
                            imagePlaceholder: Container(
                              color: AppColors.primaryTint,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 44,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Belum ada foto pengemasan',
                                    style: AppTypography.labelTag.copyWith(
                                      color: AppColors.onPrimaryTint,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onBackTap: () => context.pop(),
                            actionIcon: Icons.photo_camera_rounded,
                            actionTooltip: 'Ambil Foto Pengemasan',
                            onActionTap: _capturePhoto,
                            title: liveMenuTitle,
                            subtitle: kitchen.name,
                            metrics: [
                              HeroMetricItem(
                                icon: Icons.restaurant_rounded,
                                label: '$portionLabel Porsi',
                              ),
                              HeroMetricItem(
                                icon: Icons.shield_outlined,
                                label: _riskCategory.label,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          AppSpacing.lg,
                          horizontalPad,
                          0,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LacakSecondaryButton(
                                label: _capturedPhoto == null
                                    ? 'Ambil Foto Pengemasan (Kamera)'
                                    : 'Ambil Ulang Foto Kamera',
                                icon: Icons.photo_camera_rounded,
                                isLoading: _capturingPhoto,
                                onPressed: _capturePhoto,
                              ),
                              if (_capturedPhoto != null) ...[
                                const SizedBox(height: AppSpacing.xs),
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
                                          AppTypography.captionMuted.copyWith(
                                            color: AppColors.safeFg,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_photoError != null) ...[
                                const SizedBox(height: AppSpacing.xs),
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
                                        style: AppTypography.captionMuted
                                            .copyWith(
                                          color: AppColors.dangerFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              LacakTextField(
                                label: 'Nama Menu Harian',
                                controller: _menuController,
                                hintText:
                                    'Contoh: Nasi Ayam Goreng & Sayur Bening',
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) {
                                  setState(() {});
                                  _saveLocalDraft();
                                },
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().length < 3) {
                                    return 'Masukkan nama menu minimal 3 karakter.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Jumlah Porsi (Ompreng)',
                                style: AppTypography.labelTag.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SoftStepperButton(
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
                                      onChanged: (_) {
                                        setState(() {});
                                        _saveLocalDraft();
                                      },
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: AppTypography.tabular(
                                        AppTypography.headlinePage,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: '150',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: 14,
                                        ),
                                      ),
                                      validator: (value) {
                                        final n = int.tryParse(
                                          (value ?? '').trim(),
                                        );
                                        if (n == null || n < 1) {
                                          return 'Minimal 1 porsi.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  _SoftStepperButton(
                                    icon: Icons.add_rounded,
                                    tooltip: 'Tambah 10 porsi',
                                    onPressed: () => _stepPortions(10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Kategori Risiko Menu',
                                style: AppTypography.labelTag.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FilterChipStrip<FoodRiskCategory>(
                                padding: EdgeInsets.zero,
                                selectedValue: _riskCategory,
                                onSelected: (selected) {
                                  setState(() => _riskCategory = selected);
                                  _saveLocalDraft();
                                },
                                items: FoodRiskCategory.values
                                    .map(
                                      (cat) => FilterChipItem(
                                        value: cat,
                                        label: cat.label,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusInput,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _riskCategory.examples,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              AppTypography.captionMuted
                                                  .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isOffline
                                          ? Icons.cloud_off_rounded
                                          : Icons.verified_user_rounded,
                                      size: 20,
                                      color: isOffline
                                          ? AppColors.infoFg
                                          : AppColors.safeFg,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        isOffline
                                            ? 'Mode Tanpa Sinyal: Segel Ed25519 dan stempel waktu lokal tetap dikunci aman di HP.'
                                            : 'Stempel Waktu Resmi Server & tanda tangan digital Ed25519 aktif.',
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          StickyBottomActionBar(
            summaryLabel:
                '${_riskCategory.label} · ${isOffline ? 'Mode Offline' : 'Waktu Server'}',
            summaryValue: '$portionLabel Porsi',
            ctaLabel: 'Kunci & Buat QR',
            ctaIcon: Icons.qr_code_2_rounded,
            isLoading: _submitting,
            onCtaPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _SoftStepperButton extends StatelessWidget {
  const _SoftStepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, size: 22, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

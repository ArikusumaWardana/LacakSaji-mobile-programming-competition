import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/demo_accounts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/text_scale_provider.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_logo.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';
import 'widgets/adm4_picker_sheet.dart';
import 'widgets/location_helper.dart';

/// S03a: SPPG Kitchen registration broken into a 3-step progressive wizard
/// with automatic local draft persistence in SharedPreferences.
class RegisterKitchenScreen extends ConsumerStatefulWidget {
  const RegisterKitchenScreen({super.key});

  @override
  ConsumerState<RegisterKitchenScreen> createState() =>
      _RegisterKitchenScreenState();
}

class _RegisterKitchenScreenState extends ConsumerState<RegisterKitchenScreen> {
  static const String _draftPrefKey = 'lacak_draft_register_kitchen_v1';

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  final _regNumberController = TextEditingController();
  final _pinController = TextEditingController();
  final _picNameController = TextEditingController();
  final _kitchenNameController = TextEditingController();
  final _adm4Controller = TextEditingController(
    text: kBanyumasAdm4Options.first.code,
  );
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int _currentStep = 1;
  double _lat = kBanyumasAdm4Options.first.lat;
  double _lng = kBanyumasAdm4Options.first.lng;
  bool _gpsLocked = false;
  bool _gpsLoading = false;
  bool _whitelistChecking = false;
  WhitelistCheckResult? _whitelistResult;
  String? _whitelistError;
  KitchenRegistrationResult? _completedResult;

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
    _regNumberController.dispose();
    _pinController.dispose();
    _picNameController.dispose();
    _kitchenNameController.dispose();
    _adm4Controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
        _regNumberController.text = (map['reg_number'] as String?) ?? '';
        _pinController.text = (map['pin'] as String?) ?? '';
        _picNameController.text = (map['pic_name'] as String?) ?? '';
        _kitchenNameController.text = (map['kitchen_name'] as String?) ?? '';
        final savedAdm4 = (map['adm4_code'] as String?) ?? '';
        if (savedAdm4.isNotEmpty) {
          _adm4Controller.text = savedAdm4;
        }
        _emailController.text = (map['email'] as String?) ?? '';
        _lat = (map['lat'] as num?)?.toDouble() ?? _lat;
        _lng = (map['lng'] as num?)?.toDouble() ?? _lng;
        _gpsLocked = (map['gps_locked'] as bool?) ?? false;
        _currentStep = ((map['step'] as int?) ?? 1).clamp(1, 3);
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
      'reg_number': _regNumberController.text.trim(),
      'pin': _pinController.text.trim(),
      'pic_name': _picNameController.text.trim(),
      'kitchen_name': _kitchenNameController.text.trim(),
      'adm4_code': _adm4Controller.text.trim(),
      'email': _emailController.text.trim(),
      'lat': _lat,
      'lng': _lng,
      'gps_locked': _gpsLocked,
    });
    await prefs.setString(_draftPrefKey, payload);
  }

  Future<void> _clearLocalDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.remove(_draftPrefKey);
  }

  Future<void> _openSandboxCodesDialog() async {
    final chosen = await showDialog<SandboxSppgCode>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Daftar Kode Uji Coba SPPG'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih salah satu kode aktivasi resmi BGN untuk menguji pendaftaran dapur baru.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                LacakSectionSurface.separated(
                  children: kSandboxSppgCodes
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          title: Text(
                            item.regNumber,
                            style: AppTypography.tabular(
                              AppTypography.titleItem,
                            ),
                          ),
                          subtitle: Text(
                            'PIN: ${item.pin} | ${item.officialName}',
                            style: AppTypography.tabular(
                              AppTypography.bodyMedium,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(dialogContext).pop(item),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            LacakSecondaryButton(
              label: 'Tutup',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() {
        _regNumberController.text = chosen.regNumber;
        _pinController.text = chosen.pin;
        _kitchenNameController.text = chosen.officialName;
        _adm4Controller.text = chosen.defaultAdm4;
        _whitelistResult = null;
        _whitelistError = null;
      });
      await _saveLocalDraft();
    }
  }

  Future<bool> _checkWhitelist() async {
    setState(() {
      _whitelistChecking = true;
      _whitelistError = null;
    });
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .verifySppgWhitelist(
            regNumber: _regNumberController.text,
            pin: _pinController.text,
          );
      if (!mounted) {
        return false;
      }
      setState(() {
        _whitelistChecking = false;
        if (result.ok) {
          _whitelistResult = result;
          if (_kitchenNameController.text.trim().isEmpty &&
              result.officialName != null) {
            _kitchenNameController.text = result.officialName!;
          }
        } else {
          _whitelistResult = null;
          _whitelistError = AuthErrorMapper.mapRpcReason(result.reason);
        }
      });
      await _saveLocalDraft();
      return result.ok;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _whitelistChecking = false;
        _whitelistResult = null;
        _whitelistError = AuthErrorMapper.mapException(error);
      });
      return false;
    }
  }

  Future<void> _pickAdm4() async {
    final selected = await showAdm4VillagePicker(context);
    if (selected != null && mounted) {
      setState(() {
        _adm4Controller.text = selected.code;
        if (!_gpsLocked) {
          _lat = selected.lat;
          _lng = selected.lng;
        }
      });
      await _saveLocalDraft();
    }
  }

  Future<void> _lockGps() async {
    setState(() => _gpsLoading = true);
    final result = await captureDeviceCoordinates();
    if (!mounted) {
      return;
    }
    setState(() {
      _gpsLoading = false;
      if (result.success && result.lat != null && result.lng != null) {
        _lat = result.lat!;
        _lng = result.lng!;
        _gpsLocked = true;
      }
    });
    await _saveLocalDraft();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: AppColors.surfaceBase,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(result.message)),
          ],
        ),
      ),
    );
  }

  Future<void> _nextFromStep1() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!(_step1FormKey.currentState?.validate() ?? false)) {
      return;
    }
    final valid = await _checkWhitelist();
    if (!valid || !mounted) {
      return;
    }
    await _saveLocalDraft(nextStep: 2);
    if (!mounted) {
      return;
    }
    setState(() => _currentStep = 2);
  }

  Future<void> _nextFromStep2() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!(_step2FormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _saveLocalDraft(nextStep: 3);
    if (!mounted) {
      return;
    }
    setState(() => _currentStep = 3);
  }

  Future<void> _goBackStep() async {
    if (_currentStep <= 1) {
      context.pop();
      return;
    }
    final prev = _currentStep - 1;
    await _saveLocalDraft(nextStep: prev);
    if (!mounted) {
      return;
    }
    setState(() => _currentStep = prev);
  }

  Future<void> _submit() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!(_step3FormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _saveLocalDraft(nextStep: 3);
    final result = await ref
        .read(authControllerProvider.notifier)
        .registerKitchen(
          regNumber: _regNumberController.text,
          pin: _pinController.text,
          picName: _picNameController.text,
          kitchenName: _kitchenNameController.text,
          adm4Code: _adm4Controller.text,
          lat: _lat,
          lng: _lng,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (result != null && mounted) {
      await _clearLocalDraft();
      if (!mounted) {
        return;
      }
      setState(() => _completedResult = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    if (_completedResult != null) {
      return _KitchenActivationResultView(
        result: _completedResult!,
        email: _emailController.text.trim(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(
        title: const Text('Aktivasi Dapur SPPG'),
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
                  if (authState.errorMessage != null) ...[
                    LacakStatusBanner(
                      level: LacakStatusLevel.danger,
                      title: 'Pendaftaran Dapur Gagal',
                      description: authState.errorMessage,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  LacakStepProgressHeader(
                    currentStep: _currentStep,
                    totalSteps: 3,
                    stepTitle: _stepTitle(_currentStep),
                    stepSubtitle: _stepSubtitle(_currentStep),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LacakAnimatedStepSwitcher(
                    currentStep: _currentStep,
                    child: switch (_currentStep) {
                      1 => _buildStep1Whitelist(),
                      2 => _buildStep2Identity(),
                      _ => _buildStep3Credentials(authState),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepTitle(int step) {
    return switch (step) {
      1 => 'Verifikasi Kode Resmi BGN',
      2 => 'Identitas & Lokasi Dapur',
      _ => 'Akun Masuk Aplikasi',
    };
  }

  String _stepSubtitle(int step) {
    return switch (step) {
      1 =>
        'Masukkan Nomor Registrasi dan PIN Aktivasi 6 digit dari daftar resmi Badan Gizi Nasional.',
      2 =>
        'Lengkapi nama penanggung jawab, wilayah kelurahan BMKG, dan titik koordinat dapur.',
      _ => 'Buat email dan kata sandi untuk masuk ke Beranda Dapur SPPG.',
    };
  }

  Widget _buildStep1Whitelist() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LacakTextField(
            label: 'Nomor Registrasi SPPG',
            controller: _regNumberController,
            hintText: 'Contoh: BGN-SBX-2026-101',
            textCapitalization: TextCapitalization.characters,
            useTabularFigures: true,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Nomor registrasi SPPG wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakTextField(
            label: 'PIN Aktivasi 6 Digit',
            controller: _pinController,
            hintText: 'Masukkan 6 digit PIN',
            keyboardType: TextInputType.number,
            maxLength: 6,
            useTabularFigures: true,
            onChanged: (_) => _saveLocalDraft(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if ((value ?? '').trim().length < 4) {
                return 'PIN aktivasi minimal 4 digit.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openSandboxCodesDialog,
              icon: const Icon(Icons.key_rounded, size: 18),
              label: const Text('Lihat Daftar Kode Uji Coba'),
            ),
          ),
          if (_whitelistResult != null && _whitelistResult!.ok) ...[
            const SizedBox(height: AppSpacing.sm),
            LacakStatusBanner(
              level: LacakStatusLevel.safe,
              title: _whitelistResult!.officialName ?? 'Kode Resmi Diterima',
              description: _whitelistResult!.regionName,
            ),
          ],
          if (_whitelistError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            LacakStatusBanner(
              level: LacakStatusLevel.danger,
              title: 'Kode Ditolak',
              description: _whitelistError,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          LacakPrimaryButton(
            label: 'Simpan & Lanjut ke Identitas Dapur',
            icon: Icons.check_circle_rounded,
            isLoading: _whitelistChecking,
            onPressed: _nextFromStep1,
          ),
          const SizedBox(height: AppSpacing.md),
          LacakSecondaryButton(
            label: 'Periksa Kode & PIN Saja',
            icon: Icons.verified_user_rounded,
            isLoading: _whitelistChecking,
            onPressed: _checkWhitelist,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Identity() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LacakTextField(
            label: 'Nama Petugas PIC Dapur',
            controller: _picNameController,
            hintText: 'Nama lengkap penanggung jawab',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Nama petugas PIC wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakTextField(
            label: 'Nama Dapur SPPG',
            controller: _kitchenNameController,
            hintText: 'Contoh: SPPG Banyumas Barat',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Nama dapur wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakTextField(
            label: 'Kode Wilayah Kelurahan',
            controller: _adm4Controller,
            hintText: 'Contoh: 33.02.26.1001',
            useTabularFigures: true,
            onChanged: (_) => _saveLocalDraft(),
            suffixWidget: IconButton(
              onPressed: _pickAdm4,
              tooltip: 'Pilih Kelurahan',
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              icon: const Icon(Icons.search_rounded),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Kode wilayah kelurahan wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakSecondaryButton(
            label: _gpsLocked
                ? 'Lokasi GPS Terkunci'
                : 'Kunci Lokasi GPS Dapur',
            icon: Icons.location_on_rounded,
            isLoading: _gpsLoading,
            onPressed: _lockGps,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Koordinat: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.xl),
          LacakPrimaryButton(
            label: 'Simpan & Lanjut ke Akun Masuk',
            icon: Icons.check_circle_rounded,
            onPressed: _nextFromStep2,
          ),
          const SizedBox(height: AppSpacing.md),
          LacakSecondaryButton(
            label: 'Kembali ke Langkah 1',
            onPressed: _goBackStep,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Credentials(AuthState authState) {
    return Form(
      key: _step3FormKey,
      child: Column(
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
                  'Ringkasan Data Tersimpan:',
                  style: AppTypography.labelTag.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_kitchenNameController.text.trim()} (${_regNumberController.text.trim()})',
                  style: AppTypography.tabular(AppTypography.titleItem),
                ),
                Text(
                  'PIC: ${_picNameController.text.trim()} · Wilayah: ${_adm4Controller.text.trim()}',
                  style: AppTypography.tabular(AppTypography.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LacakTextField(
            label: 'Email Dapur',
            controller: _emailController,
            hintText: 'sppg.dapur@gmail.com',
            helperText:
                'Gunakan alamat email aktif (misal Gmail) untuk konfirmasi akun.',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty || !text.contains('@')) {
                return 'Masukkan alamat email yang valid.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakTextField(
            label: 'Kata Sandi',
            controller: _passwordController,
            hintText: 'Minimal 8 karakter',
            isPassword: true,
            validator: (value) {
              if ((value ?? '').length < 8) {
                return 'Kata sandi minimal 8 karakter.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          LacakPrimaryButton(
            label: 'Aktivasi & Daftar Dapur',
            icon: Icons.check_circle_rounded,
            isLoading: authState.isBusy,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          LacakSecondaryButton(
            label: 'Kembali ke Langkah 2',
            onPressed: authState.isBusy ? null : _goBackStep,
          ),
        ],
      ),
    );
  }
}

class _KitchenActivationResultView extends ConsumerWidget {
  const _KitchenActivationResultView({
    required this.result,
    required this.email,
  });

  final KitchenRegistrationResult result;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Aktivasi Dapur Selesai')),
      body: SafeArea(
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
                    level: result.requiresEmailConfirmation
                        ? LacakStatusLevel.warning
                        : LacakStatusLevel.safe,
                    title: result.requiresEmailConfirmation
                        ? 'Konfirmasi Email Diperlukan'
                        : 'Dapur SPPG Terverifikasi',
                    description: result.requiresEmailConfirmation
                        ? 'Buka tautan verifikasi yang dikirim ke $email lalu masuk kembali untuk menyelesaikan aktivasi kode mitra.'
                        : 'Kunci pengaman digital dapur telah disimpan aman di HP ini.',
                  ),
                  if (!result.requiresEmailConfirmation &&
                      result.inviteCode.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const LacakLogoMark(size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Kode Mitra Unik SPPG',
                      style: AppTypography.labelTag.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      result.inviteCode,
                      style: AppTypography.tabular(
                        AppTypography.displayStatus.copyWith(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Bagikan kode ini ke Guru / PIC sekolah binaan untuk menautkan akun.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LacakSecondaryButton(
                      label: 'Salin Kode Mitra',
                      icon: Icons.copy_rounded,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: result.inviteCode),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kode mitra berhasil disalin.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  LacakPrimaryButton(
                    label: result.requiresEmailConfirmation
                        ? 'Kembali ke Halaman Masuk'
                        : 'Masuk ke Beranda Dapur',
                    onPressed: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .completeKitchenActivationSummary();
                      context.go(
                        result.requiresEmailConfirmation
                            ? AppRoutes.login
                            : AppRoutes.kitchenHome,
                      );
                    },
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

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
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';
import 'widgets/adm4_picker_sheet.dart';
import 'widgets/location_helper.dart';

/// S03b: School PIC registration broken into a 3-step progressive wizard
/// with automatic local draft persistence in SharedPreferences.
class RegisterSchoolScreen extends ConsumerStatefulWidget {
  const RegisterSchoolScreen({super.key});

  @override
  ConsumerState<RegisterSchoolScreen> createState() =>
      _RegisterSchoolScreenState();
}

class _RegisterSchoolScreenState extends ConsumerState<RegisterSchoolScreen> {
  static const String _draftPrefKey = 'lacak_draft_register_school_v1';

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  final _npsnController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _picNameController = TextEditingController();
  final _adm4Controller = TextEditingController(
    text: kBanyumasAdm4Options.first.code,
  );
  final _puskesmasWaController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int _currentStep = 1;
  double _lat = kBanyumasAdm4Options.first.lat;
  double _lng = kBanyumasAdm4Options.first.lng;
  bool _prechecking = false;
  SchoolPrecheckResult? _precheckResult;
  String? _precheckError;
  SchoolRegistrationResult? _completedResult;

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
    _npsnController.dispose();
    _schoolNameController.dispose();
    _picNameController.dispose();
    _adm4Controller.dispose();
    _puskesmasWaController.dispose();
    _inviteCodeController.dispose();
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
        _npsnController.text = (map['npsn'] as String?) ?? '';
        _schoolNameController.text = (map['school_name'] as String?) ?? '';
        _picNameController.text = (map['pic_name'] as String?) ?? '';
        final savedAdm4 = (map['adm4_code'] as String?) ?? '';
        if (savedAdm4.isNotEmpty) {
          _adm4Controller.text = savedAdm4;
        }
        _puskesmasWaController.text = (map['puskesmas_wa'] as String?) ?? '';
        _inviteCodeController.text = (map['invite_code'] as String?) ?? '';
        _emailController.text = (map['email'] as String?) ?? '';
        _lat = (map['lat'] as num?)?.toDouble() ?? _lat;
        _lng = (map['lng'] as num?)?.toDouble() ?? _lng;
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
      'npsn': _npsnController.text.trim(),
      'school_name': _schoolNameController.text.trim(),
      'pic_name': _picNameController.text.trim(),
      'adm4_code': _adm4Controller.text.trim(),
      'puskesmas_wa': _puskesmasWaController.text.trim(),
      'invite_code': _inviteCodeController.text.trim(),
      'email': _emailController.text.trim(),
      'lat': _lat,
      'lng': _lng,
    });
    await prefs.setString(_draftPrefKey, payload);
  }

  Future<void> _clearLocalDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.remove(_draftPrefKey);
  }

  Future<void> _pickAdm4() async {
    final selected = await showAdm4VillagePicker(context);
    if (selected != null && mounted) {
      setState(() {
        _adm4Controller.text = selected.code;
        _lat = selected.lat;
        _lng = selected.lng;
      });
      await _saveLocalDraft();
    }
  }

  Future<bool> _checkSchoolAndPartner() async {
    setState(() {
      _prechecking = true;
      _precheckError = null;
    });
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .precheckSchool(
            npsn: _npsnController.text,
            inviteCode: _inviteCodeController.text,
          );
      if (!mounted) {
        return false;
      }
      setState(() {
        _prechecking = false;
        if (result.ok) {
          _precheckResult = result;
        } else {
          _precheckResult = null;
          _precheckError = AuthErrorMapper.mapRpcReason(result.reason);
        }
      });
      await _saveLocalDraft();
      return result.ok;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _prechecking = false;
        _precheckResult = null;
        _precheckError = AuthErrorMapper.mapException(error);
      });
      return false;
    }
  }

  Future<void> _nextFromStep1() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!(_step1FormKey.currentState?.validate() ?? false)) {
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
    final valid = await _checkSchoolAndPartner();
    if (!valid || !mounted) {
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

    final normalizedWa = normalizeIndonesianWaNumber(
      _puskesmasWaController.text,
    );
    final result = await ref
        .read(authControllerProvider.notifier)
        .registerSchool(
          npsn: _npsnController.text,
          schoolName: _schoolNameController.text,
          picName: _picNameController.text,
          adm4Code: _adm4Controller.text,
          puskesmasWa: normalizedWa,
          inviteCode: _inviteCodeController.text,
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
      if (result.requiresEmailConfirmation) {
        setState(() => _completedResult = result);
      } else {
        context.go(AppRoutes.pendingVerification);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    if (_completedResult != null &&
        _completedResult!.requiresEmailConfirmation) {
      return Scaffold(
        backgroundColor: AppColors.bgCanvas,
        appBar: AppBar(title: const Text('Konfirmasi Email Sekolah')),
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
                      level: LacakStatusLevel.warning,
                      title: 'Verifikasi Email Akun Anda',
                      description:
                          'Kami mengirim tautan verifikasi ke ${_emailController.text.trim()}. Setelah email dikonfirmasi, masuk untuk melihat status persetujuan SPPG.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    LacakPrimaryButton(
                      label: 'Kembali ke Halaman Masuk',
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(
        title: const Text('Daftar Akun Sekolah'),
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
                      title: 'Pendaftaran Sekolah Gagal',
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
                      1 => _buildStep1SchoolIdentity(),
                      2 => _buildStep2PartnerLink(),
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
      1 => 'Identitas Sekolah & Puskesmas',
      2 => 'Tautan Dapur Mitra SPPG',
      _ => 'Akun Masuk Sekolah',
    };
  }

  String _stepSubtitle(int step) {
    return switch (step) {
      1 =>
        'Masukkan NPSN 8 digit, wilayah kelurahan BMKG, dan kontak darurat Puskesmas terdekat.',
      2 =>
        'Masukkan Kode Mitra SPPG yang menyuplai makanan ke sekolah Anda.',
      _ => 'Buat email dan kata sandi bagi Guru / PIC Sekolah.',
    };
  }

  Widget _buildStep1SchoolIdentity() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LacakTextField(
            label: 'NPSN (8 Digit)',
            controller: _npsnController,
            hintText: 'Contoh: 20301999',
            keyboardType: TextInputType.number,
            maxLength: 8,
            useTabularFigures: true,
            onChanged: (_) => _saveLocalDraft(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              final text = (value ?? '').trim();
              if (!RegExp(r'^[0-9]{8}$').hasMatch(text)) {
                return 'NPSN wajib terdiri dari tepat 8 digit angka.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakTextField(
            label: 'Nama Sekolah',
            controller: _schoolNameController,
            hintText: 'Contoh: SDN 3 Purwokerto',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Nama sekolah wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LacakTextField(
            label: 'Nama Guru / PIC Sekolah',
            controller: _picNameController,
            hintText: 'Nama penanggung jawab MBG di sekolah',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Nama Guru / PIC wajib diisi.';
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
          LacakTextField(
            label: 'Nomor WhatsApp Puskesmas Terdekat',
            controller: _puskesmasWaController,
            hintText: 'Contoh: 08112800001',
            helperText:
                'Digunakan untuk mengirim PDF Berita Acara darurat dengan 1 ketukan.',
            keyboardType: TextInputType.phone,
            useTabularFigures: true,
            onChanged: (_) => _saveLocalDraft(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              final digits = normalizeIndonesianWaNumber(value ?? '');
              if (digits.length < 10) {
                return 'Masukkan nomor WhatsApp aktif minimal 10 digit.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          LacakPrimaryButton(
            label: 'Simpan & Lanjut ke Tautan SPPG',
            icon: Icons.check_circle_rounded,
            onPressed: _nextFromStep1,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2PartnerLink() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LacakTextField(
            label: 'Kode Mitra SPPG',
            controller: _inviteCodeController,
            hintText: 'Contoh: SPPG-PWT-01',
            textCapitalization: TextCapitalization.characters,
            useTabularFigures: true,
            onChanged: (_) => _saveLocalDraft(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Kode Mitra SPPG wajib diisi.';
              }
              return null;
            },
          ),
          if (_precheckResult != null && _precheckResult!.ok) ...[
            const SizedBox(height: AppSpacing.md),
            LacakStatusBanner(
              level: LacakStatusLevel.safe,
              title: 'Dapur Mitra: ${_precheckResult!.sppgName}',
              description:
                  'NPSN tersedia dan kode mitra ditemukan. Setelah mendaftar, status awal menunggu persetujuan dapur.',
            ),
          ],
          if (_precheckError != null) ...[
            const SizedBox(height: AppSpacing.md),
            LacakStatusBanner(
              level: LacakStatusLevel.danger,
              title: 'Validasi Belum Lolos',
              description: _precheckError,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          LacakPrimaryButton(
            label: 'Verifikasi & Lanjut ke Akun Masuk',
            icon: Icons.fact_check_rounded,
            isLoading: _prechecking,
            onPressed: _nextFromStep2,
          ),
          const SizedBox(height: AppSpacing.md),
          LacakSecondaryButton(
            label: 'Kembali ke Langkah 1',
            onPressed: _prechecking ? null : _goBackStep,
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
                  '${_schoolNameController.text.trim()} (NPSN ${_npsnController.text.trim()})',
                  style: AppTypography.tabular(AppTypography.titleItem),
                ),
                Text(
                  'Mitra: ${_precheckResult?.sppgName ?? _inviteCodeController.text.trim()} · PIC: ${_picNameController.text.trim()}',
                  style: AppTypography.tabular(AppTypography.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LacakTextField(
            label: 'Email PIC Sekolah',
            controller: _emailController,
            hintText: 'pic.sekolah@gmail.com',
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
            label: 'Daftar & Ajukan Tautan',
            icon: Icons.how_to_reg_rounded,
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

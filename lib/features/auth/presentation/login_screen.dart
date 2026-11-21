import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/demo_accounts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_logo.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import 'auth_controller.dart';

/// S02: Centered focal login screen modeled after the user's reference layout
/// (top bar with help button, centered hero emblem on subtle halo, centered headline & subtitle,
/// open-canvas email/password inputs with live valid-check indicator, primary CTA,
/// side-by-side quick demo buttons, and underlined registration link) using DESIGN.md 90-8-2 tokens.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleEmailChanged() {
    final text = _emailController.text.trim();
    final valid = text.contains('@') && text.contains('.') && text.length >= 5;
    if (valid != _isEmailValid && mounted) {
      setState(() => _isEmailValid = valid);
    }
  }

  Future<void> _submitLogin() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _openDemoSheet({bool? filterKitchen}) async {
    ref.read(authControllerProvider.notifier).clearError();
    final selected = await showModalBottomSheet<DemoAccountPreset>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      backgroundColor: AppColors.bgCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSurface),
        ),
      ),
      builder: (sheetContext) => _QuickDemoSheet(filterKitchen: filterKitchen),
    );
    if (selected != null && mounted) {
      await ref.read(authControllerProvider.notifier).signInDemo(selected);
    }
  }

  Future<void> _showLoginGuideDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Panduan Masuk LacakSaji'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1. Petugas Dapur SPPG: Masuk dengan akun dapur yang telah diaktivasi menggunakan Kode & PIN resmi BGN.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '2. Guru / PIC Sekolah: Masuk dengan akun sekolah berbasis NPSN yang telah ditautkan ke Kode Mitra SPPG.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '3. Uji Coba Cepat: Gunakan tombol Masuk Cepat (Akun Demo) untuk mencoba seluruh fitur Dapur, Sekolah, atau Pengawas secara langsung.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            LacakPrimaryButton(
              label: 'Mengerti',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            AppSpacing.md,
            horizontalPad,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Minimal top header bar (centered "LacakSaji" title + help button on the right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(
                          width: AppSpacing.minTouchTarget,
                          height: AppSpacing.minTouchTarget,
                        ),
                        Expanded(
                          child: Text(
                            'LacakSaji',
                            textAlign: TextAlign.center,
                            style: AppTypography.titleItem.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Material(
                          color: AppColors.surfaceBase,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSurface,
                            ),
                            side: const BorderSide(
                              color: AppColors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _showLoginGuideDialog,
                            tooltip: 'Panduan Masuk',
                            constraints: const BoxConstraints(
                              minWidth: AppSpacing.minTouchTarget,
                              minHeight: AppSpacing.minTouchTarget,
                            ),
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              size: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 2. Centered focal hero emblem with layered tonal pine halo
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryTint.withValues(alpha: 0.55),
                          border: Border.all(
                            color: AppColors.borderHairline,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryTint,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const LacakLogoMark(size: 56),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 3. Centered bold welcome title & subtitle
                    Text(
                      'Masuk LacakSaji',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayStatus.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Masuk untuk memantau segel waktu-suhu dan kelayakan pangan Makan Bergizi Gratis.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (authState.errorMessage != null) ...[
                      LacakStatusBanner(
                        level: LacakStatusLevel.danger,
                        title: 'Gagal Masuk',
                        description: authState.errorMessage,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // 4. Clean open-canvas inputs with email check indicator and password visibility toggle
                    LacakTextField(
                      label: 'Email',
                      controller: _emailController,
                      hintText: 'contoh@sekolah.sch.id',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_rounded,
                      suffixWidget: _isEmailValid
                          ? const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 22,
                              color: AppColors.primary,
                            )
                          : null,
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
                      hintText: 'Masukkan kata sandi',
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_rounded,
                      onFieldSubmitted: (_) => _submitLogin(),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Kata sandi wajib diisi.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Right-aligned helper link (mirroring "Forgot password?" placement in the reference)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: authState.isBusy ? null : _openDemoSheet,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            48,
                            AppSpacing.minTouchTarget,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: Text(
                          'Ingin mencoba tanpa daftar? Pilih Akun Demo',
                          style: AppTypography.labelTag.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // 5. Full-width solid pine Primary CTA button
                    LacakPrimaryButton(
                      label: 'Masuk',
                      icon: Icons.login_rounded,
                      isLoading: authState.isBusy,
                      onPressed: _submitLogin,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 6. Divider ("atau") + Side-by-side quick demo buttons + Main demo trigger
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'atau',
                            style: AppTypography.labelTag.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScaler = MediaQuery.textScalerOf(context);
                        final stack = constraints.maxWidth < 330 ||
                            textScaler.scale(16) > 19.0;
                        final kitchenPill = _QuickRoleButton(
                          label: 'Demo Dapur',
                          icon: Icons.soup_kitchen_rounded,
                          onTap: authState.isBusy
                              ? null
                              : () => _openDemoSheet(filterKitchen: true),
                        );
                        final schoolPill = _QuickRoleButton(
                          label: 'Demo Sekolah',
                          icon: Icons.school_rounded,
                          onTap: authState.isBusy
                              ? null
                              : () => _openDemoSheet(filterKitchen: false),
                        );
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              kitchenPill,
                              const SizedBox(height: AppSpacing.sm),
                              schoolPill,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: kitchenPill),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: schoolPill),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LacakSecondaryButton(
                      label: 'Masuk Cepat (Akun Demo)',
                      icon: Icons.switch_account_rounded,
                      isLoading: authState.isBusy,
                      onPressed: () => _openDemoSheet(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 7. Bottom registration link with bold underlined action text
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(
                          'Belum punya akun?',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: authState.isBusy
                              ? null
                              : () {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .clearError();
                                  context.push(AppRoutes.register);
                                },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              48,
                              AppSpacing.minTouchTarget,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            foregroundColor: AppColors.primary,
                          ),
                          child: Text(
                            'Daftar di Sini',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickRoleButton extends StatelessWidget {
  const _QuickRoleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
            minHeight: AppSpacing.secondaryButtonMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelTag.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickDemoSheet extends StatelessWidget {
  const _QuickDemoSheet({this.filterKitchen});

  final bool? filterKitchen;

  @override
  Widget build(BuildContext context) {
    final accounts = filterKitchen == null
        ? kDemoAccounts
        : kDemoAccounts
              .where((item) => item.isKitchen == filterKitchen)
              .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih Akun Demo Cepat',
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
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Masuk langsung menggunakan akun demo aktif untuk mencoba setiap peran pengguna.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: LacakSectionSurface.separated(
                    children: accounts
                        .map(
                          (preset) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            leading: Icon(
                              preset.isSupervisor
                                  ? Icons.visibility_rounded
                                  : preset.isKitchen
                                      ? Icons.soup_kitchen_rounded
                                      : Icons.school_rounded,
                              size: 24,
                              color: AppColors.textPrimary,
                            ),
                            title: Text(
                              preset.title,
                              style: AppTypography.titleItem,
                            ),
                            subtitle: Text(
                              preset.subtitle,
                              style: AppTypography.bodyMedium,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onTap: () => Navigator.of(context).pop(preset),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

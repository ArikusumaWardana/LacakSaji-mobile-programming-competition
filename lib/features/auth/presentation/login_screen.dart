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
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

/// S02: Editorial open-canvas login screen with soft-filled inputs and separated Quick Demo access.
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
          top: Radius.circular(AppSpacing.radiusHero),
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
                  '2. Kurir / Pengantar: Pindai muat dari dapur SPPG dan serah terima tiba di gerbang sekolah.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '3. Guru / PIC Sekolah: Masuk dengan akun sekolah berbasis NPSN yang telah ditautkan ke Kode Mitra SPPG.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '4. Uji Coba Cepat: Gunakan tombol Masuk Cepat di bagian bawah untuk mencoba peran Dapur, Kurir, Sekolah, atau Pengawas BGN.',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const LacakLogoMark(size: 32),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'LacakSaji',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleSection.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusInput,
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
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      'Masuk Akun',
                      style: AppTypography.displayStatus,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pantau segel waktu-suhu dan kelayakan pangan Makan Bergizi Gratis.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (authState.errorMessage != null) ...[
                      LacakStatusBanner(
                        level: LacakStatusLevel.danger,
                        title: 'Gagal Masuk',
                        description: authState.errorMessage,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    LacakTextField(
                      label: 'Email',
                      controller: _emailController,
                      hintText: 'contoh@sekolah.sch.id',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_rounded,
                      suffixWidget: _isEmailValid
                          ? const Icon(
                              Icons.check_circle_rounded,
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
                    const SizedBox(height: AppSpacing.lg),
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
                    const SizedBox(height: AppSpacing.xxl),
                    LacakPrimaryButton(
                      label: 'Masuk',
                      icon: Icons.login_rounded,
                      isLoading: authState.busyAction == AuthBusyAction.signIn,
                      onPressed: authState.isBusy ? null : _submitLogin,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(
                          'Belum punya akun?',
                          style: AppTypography.bodyMedium,
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
                              AppSpacing.minTouchTarget,
                              AppSpacing.minTouchTarget,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            foregroundColor: AppColors.primary,
                          ),
                          child: Text(
                            'Daftar di Sini',
                            style: AppTypography.titleItem.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              'Uji Coba Cepat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.captionMuted,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LacakSecondaryButton(
                      label: 'Masuk Cepat - Akun Demo',
                      icon: Icons.switch_account_rounded,
                      isLoading:
                          authState.busyAction == AuthBusyAction.signInDemo,
                      onPressed: authState.isBusy
                          ? null
                          : () => _openDemoSheet(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LacakSecondaryButton(
                      label: 'Masuk Cepat - Kurir Demo',
                      icon: Icons.local_shipping_rounded,
                      isLoading:
                          authState.busyAction == AuthBusyAction.signInDemo,
                      onPressed: authState.isBusy
                          ? null
                          : () {
                              final courierPreset = kDemoAccounts.firstWhere(
                                (item) => item.isCourier,
                              );
                              ref
                                  .read(authControllerProvider.notifier)
                                  .signInDemo(courierPreset);
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScaler = MediaQuery.textScalerOf(context);
                        final stack = constraints.maxWidth < 320 ||
                            textScaler.scale(14) > 17.5;
                        final kitchenBtn = _SoftRolePillButton(
                          label: 'Demo Dapur',
                          icon: Icons.soup_kitchen_rounded,
                          onTap: authState.isBusy
                              ? null
                              : () => _openDemoSheet(filterKitchen: true),
                        );
                        final schoolBtn = _SoftRolePillButton(
                          label: 'Demo Sekolah',
                          icon: Icons.school_rounded,
                          onTap: authState.isBusy
                              ? null
                              : () => _openDemoSheet(filterKitchen: false),
                        );
                        final supervisorBtn = _SoftRolePillButton(
                          label: 'Demo Pengawas',
                          icon: Icons.visibility_rounded,
                          onTap: authState.isBusy
                              ? null
                              : () {
                                  final supervisorPreset =
                                      kDemoAccounts.firstWhere(
                                        (item) => item.isSupervisor,
                                      );
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .signInDemo(supervisorPreset);
                                },
                        );
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              kitchenBtn,
                              const SizedBox(height: AppSpacing.sm),
                              schoolBtn,
                              const SizedBox(height: AppSpacing.sm),
                              supervisorBtn,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: kitchenBtn),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: schoolBtn),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            supervisorBtn,
                          ],
                        );
                      },
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

class _SoftRolePillButton extends StatelessWidget {
  const _SoftRolePillButton({
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
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        : filterKitchen == true
            ? kDemoAccounts
                .where((item) => item.isKitchen)
                .toList(growable: false)
            : kDemoAccounts
                .where(
                  (item) =>
                      !item.isKitchen && !item.isSupervisor && !item.isCourier,
                )
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
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final preset = accounts[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusThumb,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          preset.isSupervisor
                              ? Icons.visibility_rounded
                              : preset.isCourier
                                  ? Icons.local_shipping_rounded
                                  : preset.isKitchen
                                      ? Icons.soup_kitchen_rounded
                                      : Icons.school_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

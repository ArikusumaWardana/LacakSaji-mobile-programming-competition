import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';

/// S03: Editorial role selection screen directing new users to Kitchen (S03a) or School (S03b).
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'kitchen';

  void _continueRegistration() {
    if (_selectedRole == 'kitchen') {
      context.push(AppRoutes.registerKitchen);
    } else {
      context.push(AppRoutes.registerSchool);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: AppColors.surfaceSoft,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => context.pop(),
                          tooltip: 'Kembali',
                          constraints: const BoxConstraints(
                            minWidth: AppSpacing.minTouchTarget,
                            minHeight: AppSpacing.minTouchTarget,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 19,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Pendaftaran Akun Baru',
                          style: AppTypography.captionMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Pilih Peran Anda',
                    style: AppTypography.displayStatus,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Setiap akun hanya memiliki satu peran operasional.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _SoftRoleSelectionTile(
                    title: 'Petugas Dapur (SPPG)',
                    subtitle: 'Pembuat dan pengirim makanan harian.',
                    icon: Icons.soup_kitchen_rounded,
                    selected: _selectedRole == 'kitchen',
                    onTap: () => setState(() => _selectedRole = 'kitchen'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SoftRoleSelectionTile(
                    title: 'Guru / PIC Sekolah',
                    subtitle: 'Penerima dan pemeriksa makanan di sekolah.',
                    icon: Icons.school_rounded,
                    selected: _selectedRole == 'school',
                    onTap: () => setState(() => _selectedRole = 'school'),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  LacakPrimaryButton(
                    label: 'Lanjutkan Pendaftaran',
                    onPressed: _continueRegistration,
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

class _SoftRoleSelectionTile extends StatelessWidget {
  const _SoftRoleSelectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.primaryTint : AppColors.surfaceSoft;
    final titleColor =
        selected ? AppColors.onPrimaryTint : AppColors.textPrimary;
    final subColor =
        selected ? AppColors.onPrimaryTint : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 1.8)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.surfaceBase
                          : AppColors.surfaceBase.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusThumb,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleItem.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodyMedium.copyWith(
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected ? AppColors.primary : AppColors.textMuted,
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

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';

/// S03: Role selection screen directing new users to Kitchen (S03a) or School (S03b) flow.
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
      appBar: AppBar(title: const Text('Daftar Akun Baru')),
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
                  Text(
                    'Pilih Peran Anda',
                    style: AppTypography.headlinePage,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Setiap akun hanya memiliki satu peran operasional.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LacakSelectionRow(
                    title: 'Petugas Dapur (SPPG)',
                    subtitle: 'Pembuat dan pengirim makanan harian.',
                    leadingIcon: Icons.soup_kitchen_rounded,
                    minHeight: 84,
                    selected: _selectedRole == 'kitchen',
                    onTap: () => setState(() => _selectedRole = 'kitchen'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LacakSelectionRow(
                    title: 'Guru / PIC Sekolah',
                    subtitle: 'Penerima dan pemeriksa makanan di sekolah.',
                    leadingIcon: Icons.school_rounded,
                    minHeight: 84,
                    selected: _selectedRole == 'school',
                    onTap: () => setState(() => _selectedRole = 'school'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
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

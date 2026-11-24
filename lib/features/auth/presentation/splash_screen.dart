import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_logo.dart';
import 'auth_controller.dart';

/// S01: Minimal startup splash checking Supabase session and Drift local cache.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authControllerProvider.notifier).bootstrap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LacakLogoMark(size: 68),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'LacakSaji',
                    style: AppTypography.displayStatus,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Menyiapkan data keamanan pangan...',
                    textAlign: TextAlign.center,
                    style: AppTypography.captionMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
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

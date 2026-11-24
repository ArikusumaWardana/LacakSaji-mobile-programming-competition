import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G05: Editorial Bank Sampel 2x24 Jam (Step 3 onboarding + 48h archive & reminder vault).
class SampleVaultScreen extends ConsumerStatefulWidget {
  const SampleVaultScreen({super.key, this.onboardingArgs});

  final SampleVaultOnboardingArgs? onboardingArgs;

  @override
  ConsumerState<SampleVaultScreen> createState() => _SampleVaultScreenState();
}

class _SampleVaultScreenState extends ConsumerState<SampleVaultScreen> {
  bool _savingOnboarding = false;
  bool _showActiveTab = true;
  String? _disposingId;

  Future<void> _completeOnboarding(SampleVaultOnboardingArgs args) async {
    if (_savingOnboarding) {
      return;
    }
    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() => _savingOnboarding = true);
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    try {
      final created = await ref.read(schoolRepositoryProvider).createSampleVault(
            school: school,
            inspectionId: args.inspectionId,
            menuName: args.menuName,
            labelCode: args.suggestedLabelCode,
            isOffline: isOffline,
          );
      invalidateSchoolProviders(ref);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sampel ${created.labelCode} tersimpan dan pengingat 48 jam dijadwalkan.',
          ),
        ),
      );
      context.go(AppRoutes.schoolHome);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _savingOnboarding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan Bank Sampel: $error')),
      );
    }
  }

  Future<void> _disposeSample(SampleVaultItem item) async {
    if (_disposingId != null) {
      return;
    }
    final remaining = item.remainingFrom(DateTime.now().toUtc());
    final message = remaining > Duration.zero
        ? 'Sampel ${item.labelCode} (${item.menuName}) masih memiliki sisa waktu retensi ${remaining.inHours} jam ${remaining.inMinutes % 60} menit. Pastikan sampel memang sudah aman untuk dimusnahkan.'
        : 'Masa simpan 48 jam (2x24 jam) sampel ${item.labelCode} (${item.menuName}) telah selesai. Tandai sebagai sudah dimusnahkan?';

    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: 'Tandai Sampel Sudah Dimusnahkan?',
      message: message,
      confirmLabel: 'Ya, Tandai Dimusnahkan',
      isDanger: false,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _disposingId = item.id);
    final isOffline = ref.read(isOfflineProvider).value ?? false;
    try {
      await ref.read(schoolRepositoryProvider).markSampleDisposed(
            sampleId: item.id,
            isOffline: isOffline,
          );
      invalidateSchoolProviders(ref);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sampel ${item.labelCode} dipindahkan ke riwayat selesai.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui status sampel: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _disposingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.onboardingArgs;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = width >= 900 ? 840.0 : AppSpacing.maxContentWidth(width);

    if (args != null) {
      return _buildOnboardingScaffold(
        context: context,
        args: args,
        horizontalPad: horizontalPad,
        maxWidth: maxWidth,
      );
    }

    final school = ref.watch(authControllerProvider).school;
    final activeAsync = ref.watch(activeSampleVaultsProvider);
    final historyAsync = ref.watch(historySampleVaultsProvider);

    if (school == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(message: 'Profil sekolah belum dimuat.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          const MinimalTopHeader(
            contextLabel: 'Retensi 2x24 Jam',
            title: 'Bank Sampel',
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref
                  .read(schoolRepositoryProvider)
                  .refreshSampleVaultsFromServer(school.id),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            AppSpacing.sm,
                            horizontalPad,
                            AppSpacing.md,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSurface,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.kitchen_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ketentuan Bank Sampel Perbagi No. 4/2026',
                                        style: AppTypography.titleItem,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Simpan 1 porsi utuh pada suhu < 5 C selama 48 jam. Pengingat berbunyi otomatis saat retensi berakhir.',
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        FilterChipStrip<bool>(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          selectedValue: _showActiveTab,
                          onSelected: (selected) {
                            setState(() => _showActiveTab = selected);
                          },
                          items: const [
                            FilterChipItem(
                              value: true,
                              label: 'Aktif di Kulkas',
                            ),
                            FilterChipItem(
                              value: false,
                              label: 'Riwayat Selesai',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPad,
                          ),
                          child: (_showActiveTab ? activeAsync : historyAsync)
                              .when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 3,
                              loadingLabel: 'Memuat data Bank Sampel...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                            ),
                            data: (items) {
                              if (items.isEmpty) {
                                return LacakEmptyState(
                                  icon: Icons.kitchen_rounded,
                                  title: _showActiveTab
                                      ? 'Belum ada sampel aktif di kulkas'
                                      : 'Belum ada riwayat sampel selesai',
                                  message: _showActiveTab
                                      ? 'Pindai QR makanan masuk di Beranda Sekolah untuk mencatat sampel 48 jam.'
                                      : 'Sampel yang telah selesai disimpan 48 jam atau diserahkan ke lab akan tercatat di sini.',
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < items.length; i++)
                                    _SampleVaultRow(
                                      item: items[i],
                                      isActiveTab: _showActiveTab,
                                      isDisposing: _disposingId == items[i].id,
                                      showDivider: i < items.length - 1,
                                      onDispose: () => _disposeSample(items[i]),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingScaffold({
    required BuildContext context,
    required SampleVaultOnboardingArgs args,
    required double horizontalPad,
    required double maxWidth,
  }) {
    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.md,
                horizontalPad,
                AppSpacing.xxl,
              ),
              child: SafeArea(
                bottom: false,
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
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Langkah 3 dari 3',
                                    style: AppTypography.captionMuted,
                                  ),
                                  Text(
                                    'Simpan Bank Sampel',
                                    style: AppTypography.headlinePage,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${args.menuName} · ${args.batchCode}',
                          style: AppTypography.tabular(AppTypography.bodyMedium),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusHero,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'KODE LABEL BANK SAMPEL',
                                style: AppTypography.captionMuted.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                args.suggestedLabelCode,
                                textAlign: TextAlign.center,
                                style: AppTypography.tabular(
                                  AppTypography.displayStatus,
                                ).copyWith(letterSpacing: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(height: 1),
                        const _InstructionStepRow(
                          stepNumber: '1',
                          text:
                              'Sisihkan 1 porsi makanan utuh ke dalam wadah bersih bertutup rapat sebelum dibagikan ke siswa.',
                        ),
                        const Divider(height: 1),
                        const _InstructionStepRow(
                          stepNumber: '2',
                          text:
                              'Tuliskan kode label di atas secara jelas menggunakan spidol permanen atau kertas label pada tutup wadah.',
                        ),
                        const Divider(height: 1),
                        const _InstructionStepRow(
                          stepNumber: '3',
                          text:
                              'Simpan sampel di lemari pendingin (< 5 C) selama 2x24 jam (48 jam) sesuai Perbagi No. 4 Tahun 2026.',
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          StickyBottomActionBar(
            summaryLabel: 'Retensi Wajib',
            summaryValue: '48 Jam (< 5 C)',
            ctaLabel: 'Simpan Sampel',
            ctaIcon: Icons.check_circle_rounded,
            isLoading: _savingOnboarding,
            onCtaPressed: () => _completeOnboarding(args),
          ),
        ],
      ),
    );
  }
}

class _InstructionStepRow extends StatelessWidget {
  const _InstructionStepRow({required this.stepNumber, required this.text});

  final String stepNumber;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$stepNumber.',
            style: AppTypography.tabular(
              AppTypography.titleItem.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleVaultRow extends StatelessWidget {
  const _SampleVaultRow({
    required this.item,
    required this.isActiveTab,
    required this.isDisposing,
    required this.showDivider,
    required this.onDispose,
  });

  final SampleVaultItem item;
  final bool isActiveTab;
  final bool isDisposing;
  final bool showDivider;
  final VoidCallback onDispose;

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final remaining = item.remainingFrom(nowUtc);
    final readyToDispose = item.isReadyToDispose(nowUtc);

    final String statusText;
    final Color statusColor;
    final Color thumbBg;
    final Color thumbFg;

    if (!isActiveTab) {
      statusText = item.status == 'lab_submitted'
          ? 'Diserahkan Lab'
          : 'Sudah Dimusnahkan';
      statusColor = AppColors.safeFg;
      thumbBg = AppColors.surfaceSoft;
      thumbFg = AppColors.primary;
    } else if (readyToDispose) {
      statusText = '48 Jam Selesai - Siap Dimusnahkan';
      statusColor = AppColors.warnFg;
      thumbBg = AppColors.warnBg;
      thumbFg = AppColors.warnFg;
    } else {
      statusText =
          'Sisa ${remaining.inHours} jam ${remaining.inMinutes % 60} menit (< 5 C)';
      statusColor = AppColors.safeFg;
      thumbBg = AppColors.safeBg;
      thumbFg = AppColors.safeFg;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BorderlessThumbTile(
                padding: EdgeInsets.zero,
                fallbackIcon: Icons.kitchen_rounded,
                fallbackBgColor: thumbBg,
                fallbackIconColor: thumbFg,
                title: item.labelCode,
                statusText: statusText,
                statusColor: statusColor,
                metadata: [
                  BorderlessMetaItem(
                    icon: Icons.restaurant_menu_rounded,
                    label: item.menuName,
                  ),
                  BorderlessMetaItem(
                    icon: Icons.schedule_rounded,
                    label: 'Masuk ${formatWibDateTime(item.storedAtUtc)}',
                  ),
                ],
              ),
              if (isActiveTab) ...[
                const SizedBox(height: AppSpacing.md),
                LacakSecondaryButton(
                  label: 'Tandai Sudah Dimusnahkan',
                  icon: Icons.check_circle_rounded,
                  isLoading: isDisposing,
                  onPressed: onDispose,
                ),
              ],
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

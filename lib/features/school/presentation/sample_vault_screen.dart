import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

/// G05: Bank Sampel 2x24 Jam (Step 3 onboarding label generation + 48h archive & reminder vault).
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
    final maxWidth = AppSpacing.maxContentWidth(width);

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

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Bank Sampel 48 Jam')),
      body: SafeArea(
        child: school == null
            ? Padding(
                padding: EdgeInsets.all(horizontalPad),
                child: const LacakErrorState(
                  message: 'Profil sekolah belum dimuat.',
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref
                    .read(schoolRepositoryProvider)
                    .refreshSampleVaultsFromServer(school.id),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                            level: LacakStatusLevel.safe,
                            icon: Icons.kitchen_rounded,
                            title: 'Ketentuan Bank Sampel Perbagi No. 4/2026',
                            description:
                                'Simpan 1 porsi sampel utuh pada suhu < 5 C selama 2x24 jam (48 jam). Pengingat lokal berbunyi otomatis saat retensi berakhir.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          LacakSegmentedControl<bool>(
                            options: const [
                              LacakSegmentOption(
                                value: true,
                                label: 'Aktif di Kulkas',
                              ),
                              LacakSegmentOption(
                                value: false,
                                label: 'Riwayat Selesai',
                              ),
                            ],
                            selectedValue: _showActiveTab,
                            onChanged: (selected) {
                              setState(() => _showActiveTab = selected);
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          (_showActiveTab ? activeAsync : historyAsync).when(
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
                              return LacakSectionSurface.separated(
                                children: items
                                    .map(
                                      (item) => _SampleVaultTile(
                                        item: item,
                                        isActiveTab: _showActiveTab,
                                        isDisposing: _disposingId == item.id,
                                        onDispose: () => _disposeSample(item),
                                      ),
                                    )
                                    .toList(growable: false),
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

  Widget _buildOnboardingScaffold({
    required BuildContext context,
    required SampleVaultOnboardingArgs args,
    required double horizontalPad,
    required double maxWidth,
  }) {
    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Simpan Bank Sampel')),
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
                    'Langkah 3 dari 3: Simpan 1 Porsi Sampel',
                    style: AppTypography.titleSection,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${args.menuName} · ${args.batchCode}',
                    style: AppTypography.tabular(AppTypography.bodyMedium),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSurface,
                      ),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'KODE LABEL BANK SAMPEL',
                          style: AppTypography.labelTag.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          args.suggestedLabelCode,
                          textAlign: TextAlign.center,
                          style: AppTypography.tabular(
                            AppTypography.displayStatus,
                          ).copyWith(letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LacakSectionSurface.separated(
                    children: const [
                      _InstructionStepRow(
                        stepNumber: '1',
                        text:
                            'Sisihkan 1 porsi makanan utuh ke dalam wadah bersih bertutup rapat sebelum dibagikan ke siswa.',
                      ),
                      _InstructionStepRow(
                        stepNumber: '2',
                        text:
                            'Tuliskan kode label di atas secara jelas menggunakan spidol permanen atau kertas label pada tutup wadah.',
                      ),
                      _InstructionStepRow(
                        stepNumber: '3',
                        text:
                            'Simpan sampel di lemari pendingin (< 5 C) selama 2x24 jam (48 jam) sesuai Perbagi No. 4 Tahun 2026.',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LacakPrimaryButton(
                    label: 'Sampel Sudah di Kulkas, Selesai',
                    icon: Icons.check_circle_rounded,
                    isLoading: _savingOnboarding,
                    onPressed: () => _completeOnboarding(args),
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

class _InstructionStepRow extends StatelessWidget {
  const _InstructionStepRow({required this.stepNumber, required this.text});

  final String stepNumber;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$stepNumber.',
            style: AppTypography.tabular(
              AppTypography.titleItem.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: AppTypography.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _SampleVaultTile extends StatelessWidget {
  const _SampleVaultTile({
    required this.item,
    required this.isActiveTab,
    required this.isDisposing,
    required this.onDispose,
  });

  final SampleVaultItem item;
  final bool isActiveTab;
  final bool isDisposing;
  final VoidCallback onDispose;

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final remaining = item.remainingFrom(nowUtc);
    final readyToDispose = item.isReadyToDispose(nowUtc);

    final LacakStatusTag statusTag;
    if (!isActiveTab) {
      statusTag = LacakStatusTag(
        level: LacakStatusLevel.safe,
        label: item.status == 'lab_submitted' ? 'Diserahkan Lab' : 'Dimusnahkan',
      );
    } else if (readyToDispose) {
      statusTag = const LacakStatusTag(
        level: LacakStatusLevel.warning,
        label: '48 Jam Selesai',
      );
    } else {
      statusTag = const LacakStatusTag(
        level: LacakStatusLevel.safe,
        label: 'Aktif < 5 C',
        icon: Icons.kitchen_rounded,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.labelCode,
                style: AppTypography.tabular(AppTypography.titleSection),
              ),
              statusTag,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(item.menuName, style: AppTypography.titleItem),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Masuk kulkas: ${formatWibDateTime(item.storedAtUtc)}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
          if (isActiveTab) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              readyToDispose
                  ? 'Masa retensi 48 jam telah berakhir. Sampel aman dimusnahkan.'
                  : 'Sisa waktu retensi: ${remaining.inHours} jam ${remaining.inMinutes % 60} menit',
              style: AppTypography.tabular(
                AppTypography.bodyMedium.copyWith(
                  color: readyToDispose
                      ? AppColors.warnFg
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

/// S04: Borderless editorial waiting approval / rejected verification screen for newly linked schools.
class PendingVerificationScreen extends ConsumerWidget {
  const PendingVerificationScreen({super.key});

  Future<void> _openChangePartnerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePartnerCodeDialog(),
    );

    if (updated != null && context.mounted) {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .updateSchoolPartnerCode(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Kode mitra SPPG diperbarui dan status menunggu persetujuan ulang.'
                  : (ref.read(authControllerProvider).errorMessage ??
                      'Kode mitra gagal diperbarui.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAutoLinkInfoDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pindai QR Kotak Makanan'),
        content: Text(
          'Pemindaian QR kotak makanan untuk tautan otomatis akan aktif pada modul inspeksi sekolah. Sementara ini Anda dapat meminta persetujuan langsung kepada petugas dapur SPPG atau mengubah kode mitra.',
          style: AppTypography.bodyLarge,
        ),
        actions: [
          LacakPrimaryButton(
            label: 'Mengerti',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final school = authState.school;
    final isRejected =
        school?.verificationStatus == SchoolVerificationStatus.rejected;
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Verifikasi Akun Sekolah',
                              style: AppTypography.captionMuted,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Status Verifikasi',
                              style: AppTypography.headlinePage,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: authState.isBusy
                            ? null
                            : () async {
                                final confirm = await showLacakConfirmDialog(
                                  context: context,
                                  title: 'Keluar dari Akun?',
                                  message:
                                      'Anda akan keluar dari akun sekolah ini dan kembali ke layar masuk.',
                                  confirmLabel: 'Ya, Keluar',
                                  isDanger: true,
                                );
                                if (confirm && context.mounted) {
                                  await ref
                                      .read(authControllerProvider.notifier)
                                      .signOut();
                                }
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            AppSpacing.minTouchTarget,
                            AppSpacing.minTouchTarget,
                          ),
                          foregroundColor: AppColors.dangerFg,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Keluar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LacakStatusBanner(
                    level: isRejected
                        ? LacakStatusLevel.danger
                        : LacakStatusLevel.warning,
                    title: isRejected
                        ? 'Tautan Ditolak oleh Dapur SPPG'
                        : 'Menunggu Persetujuan Dapur SPPG',
                    description: isRejected
                        ? 'Petugas dapur tujuan menolak tautan sekolah ini. Periksa kembali kode mitra SPPG Anda atau hubungi pihak dapur.'
                        : 'Akun sekolah Anda sudah tercatat. Hubungi petugas SPPG tujuan untuk menyetujui tautan sekolah sebelum mulai memindai makanan.',
                  ),
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    LacakStatusBanner(
                      level: LacakStatusLevel.danger,
                      title: 'Gagal Memperbarui Status',
                      description: authState.errorMessage,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _BorderlessDetailRow(
                    label: 'Nama Sekolah',
                    value: school?.name ?? authState.profile?.fullName ?? '-',
                  ),
                  const Divider(height: 1),
                  _BorderlessDetailRow(
                    label: 'NPSN',
                    value: school?.npsn ?? '-',
                    tabular: true,
                  ),
                  const Divider(height: 1),
                  _BorderlessDetailRow(
                    label: 'SPPG Tujuan',
                    value: school?.partnerKitchenName != null
                        ? '${school!.partnerKitchenName} (${school.partnerInviteCode ?? '-'})'
                        : 'Belum tertaut ke dapur SPPG',
                  ),
                  const Divider(height: 1),
                  _BorderlessDetailRow(
                    label: 'Status',
                    value: school?.verificationStatus.label ??
                        'Menunggu Persetujuan SPPG',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  LacakPrimaryButton(
                    label: 'Periksa Status Sekarang',
                    icon: Icons.refresh_rounded,
                    isLoading:
                        authState.busyAction == AuthBusyAction.refreshStatus,
                    onPressed: authState.isBusy
                        ? null
                        : () async {
                            final ok = await ref
                                .read(authControllerProvider.notifier)
                                .refreshStatus();
                            if (ok && context.mounted) {
                              final nextStatus = ref
                                  .read(authControllerProvider)
                                  .school
                                  ?.verificationStatus;
                              if (nextStatus !=
                                  SchoolVerificationStatus.approved) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Status masih menunggu persetujuan dapur SPPG.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LacakSecondaryButton(
                    label: 'Ubah Kode Mitra SPPG',
                    icon: Icons.edit_rounded,
                    isLoading: authState.busyAction ==
                        AuthBusyAction.updatePartnerCode,
                    onPressed: authState.isBusy
                        ? null
                        : () => _openChangePartnerDialog(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LacakSecondaryButton(
                    label: 'Pindai QR Kotak Makanan (Tautkan Otomatis)',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: authState.isBusy
                        ? null
                        : () => _showAutoLinkInfoDialog(context),
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

class _BorderlessDetailRow extends StatelessWidget {
  const _BorderlessDetailRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final valueStyle = tabular
        ? AppTypography.tabular(AppTypography.titleItem)
        : AppTypography.titleItem;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 310 || textScale >= 1.25) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.captionMuted),
                const SizedBox(height: 2),
                Text(value, style: valueStyle),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(label, style: AppTypography.bodyMedium),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: valueStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChangePartnerCodeDialog extends StatefulWidget {
  const _ChangePartnerCodeDialog();

  @override
  State<_ChangePartnerCodeDialog> createState() =>
      _ChangePartnerCodeDialogState();
}

class _ChangePartnerCodeDialogState extends State<_ChangePartnerCodeDialog> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Kode Mitra SPPG'),
      content: LacakTextField(
        label: 'Kode Mitra SPPG Baru',
        controller: _codeController,
        hintText: 'Contoh: SPPG-PWT-01',
        textCapitalization: TextCapitalization.characters,
        useTabularFigures: true,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LacakPrimaryButton(
              label: 'Simpan Kode Mitra',
              onPressed: () {
                final code = _codeController.text.trim();
                if (code.isNotEmpty) {
                  Navigator.of(context).pop(code);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            LacakSecondaryButton(
              label: 'Batal',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

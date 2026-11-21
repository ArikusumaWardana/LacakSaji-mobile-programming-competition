import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

/// D04: SPPG Partner School Management (invite code, pending approval, active schools).
class KitchenSchoolsScreen extends ConsumerStatefulWidget {
  const KitchenSchoolsScreen({super.key});

  @override
  ConsumerState<KitchenSchoolsScreen> createState() =>
      _KitchenSchoolsScreenState();
}

class _KitchenSchoolsScreenState extends ConsumerState<KitchenSchoolsScreen> {
  String? _processingSchoolId;

  Future<void> _copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode Mitra $inviteCode disalin ke papan klip.'),
      ),
    );
  }

  Future<void> _showProfileQrDialog(KitchenProfile kitchen) async {
    final qrData = SppgProfileQrPayload(
      sppgId: kitchen.id,
      inviteCode: kitchen.inviteCode,
      name: kitchen.name,
      publicKey: kitchen.publicKey,
    ).toMinifiedJson();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final qrSize = AppSpacing.adaptiveQrSize(screenWidth).clamp(160.0, 220.0);

        return Dialog(
          backgroundColor: AppColors.surfaceBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
            side: const BorderSide(color: AppColors.borderHairline, width: 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'QR Profil Mitra SPPG',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSection,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusControl,
                        ),
                        border: Border.all(
                          color: AppColors.borderHairline,
                          width: 1,
                        ),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        size: qrSize,
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.surfaceBase,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.textPrimary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    kitchen.name,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleItem,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    kitchen.inviteCode,
                    textAlign: TextAlign.center,
                    style: AppTypography.tabular(AppTypography.titleSection),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tunjukkan QR ini ke Guru / PIC sekolah saat pendaftaran agar kode mitra terisi otomatis.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LacakPrimaryButton(
                    label: 'Tutup',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDecision({
    required KitchenProfile kitchen,
    required PartnerSchoolItem school,
    required SchoolVerificationStatus decision,
  }) async {
    if (_processingSchoolId != null) {
      return;
    }

    if (decision == SchoolVerificationStatus.rejected) {
      final confirmed = await showLacakConfirmDialog(
        context: context,
        title: 'Tolak Permintaan Sekolah?',
        message:
            'Sekolah ${school.name} (NPSN ${school.npsn}) tidak akan dapat memindai QR batch dari ${kitchen.name}. Anda tetap dapat menyetujuinya nanti bila diperlukan.',
        confirmLabel: 'Ya, Tolak Sekolah',
        isDanger: true,
        confirmIcon: Icons.dangerous_rounded,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _processingSchoolId = school.id);
    try {
      await ref.read(kitchenRepositoryProvider).reviewSchool(
            sppgId: kitchen.id,
            schoolId: school.id,
            decision: decision,
          );
      invalidateKitchenProviders(ref);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == SchoolVerificationStatus.approved
                ? '${school.name} disetujui sebagai sekolah binaan aktif.'
                : 'Permintaan ${school.name} telah ditolak.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _processingSchoolId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(authControllerProvider).kitchen;
    final schoolsAsync = ref.watch(kitchenSchoolsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Sekolah Binaan')),
      body: SafeArea(
        child: kitchen == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LacakErrorState(
                  message: 'Profil dapur SPPG belum tersedia.',
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(kitchenSchoolsProvider);
                  await ref.read(kitchenSchoolsProvider.future);
                },
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
                          // Open focal header on canvas (inspired by reference 2 focal balance header, no box wrapper)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Kode Mitra SPPG',
                                style: AppTypography.labelTag.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const LacakStatusTag(
                                level: LacakStatusLevel.safe,
                                label: 'AKTIF',
                                icon: Icons.qr_code_2_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            kitchen.inviteCode,
                            style: AppTypography.tabular(
                              AppTypography.displayStatus.copyWith(
                                fontSize: 28,
                              ),
                            ).copyWith(letterSpacing: 1.0),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Berikan kode ini atau tampilkan QR Profil kepada Guru / PIC sekolah binaan untuk menautkan akun.',
                            style: AppTypography.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final textScaler =
                                  MediaQuery.textScalerOf(context);
                              final stack = constraints.maxWidth < 340 ||
                                  textScaler.scale(16) > 18.5;
                              final copyBtn = LacakPrimaryButton(
                                label: 'Salin Kode',
                                icon: Icons.copy_rounded,
                                minHeight:
                                    AppSpacing.secondaryButtonMinHeight,
                                onPressed: () =>
                                    _copyInviteCode(kitchen.inviteCode),
                              );
                              final qrBtn = LacakSecondaryButton(
                                label: 'Tampilkan QR Profil',
                                icon: Icons.qr_code_2_rounded,
                                onPressed: () =>
                                    _showProfileQrDialog(kitchen),
                              );
                              if (stack) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    copyBtn,
                                    const SizedBox(height: AppSpacing.md),
                                    qrBtn,
                                  ],
                                );
                              }
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: copyBtn),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(child: qrBtn),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.lg),
                          schoolsAsync.when(
                            loading: () => const LacakSkeletonList(
                              itemCount: 3,
                              loadingLabel: 'Memuat daftar sekolah binaan...',
                            ),
                            error: (error, _) => LacakErrorState(
                              message: error.toString(),
                              onRetry: () =>
                                  ref.invalidate(kitchenSchoolsProvider),
                            ),
                            data: (schools) => _SchoolsListBody(
                              kitchen: kitchen,
                              schools: schools,
                              processingSchoolId: _processingSchoolId,
                              onReview: (school, decision) => _handleDecision(
                                kitchen: kitchen,
                                school: school,
                                decision: decision,
                              ),
                            ),
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

class _SchoolsListBody extends StatelessWidget {
  const _SchoolsListBody({
    required this.kitchen,
    required this.schools,
    required this.processingSchoolId,
    required this.onReview,
  });

  final KitchenProfile kitchen;
  final List<PartnerSchoolItem> schools;
  final String? processingSchoolId;
  final void Function(PartnerSchoolItem school, SchoolVerificationStatus decision)
      onReview;

  @override
  Widget build(BuildContext context) {
    final pendingSchools = schools
        .where(
          (s) => s.verificationStatus == SchoolVerificationStatus.pending,
        )
        .toList(growable: false);
    final approvedSchools = schools
        .where(
          (s) => s.verificationStatus == SchoolVerificationStatus.approved,
        )
        .toList(growable: false);
    final rejectedSchools = schools
        .where(
          (s) => s.verificationStatus == SchoolVerificationStatus.rejected,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Menunggu Persetujuan (${pendingSchools.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (pendingSchools.isEmpty)
          const LacakEmptyState(
            icon: Icons.mark_email_read_rounded,
            title: 'Tidak ada permintaan bergabung baru',
            message:
                'Permintaan dari sekolah baru yang memasukkan Kode Mitra Anda akan tampil di sini.',
          )
        else
          LacakSectionSurface.separated(
            children: pendingSchools
                .map(
                  (school) => _PendingSchoolTile(
                    school: school,
                    isBusy: processingSchoolId == school.id,
                    onApprove: () =>
                        onReview(school, SchoolVerificationStatus.approved),
                    onReject: () =>
                        onReview(school, SchoolVerificationStatus.rejected),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Sekolah Binaan Aktif (${approvedSchools.length})',
          style: AppTypography.tabular(AppTypography.titleSection),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (approvedSchools.isEmpty)
          const LacakEmptyState(
            icon: Icons.school_rounded,
            title: 'Belum ada sekolah binaan aktif',
            message:
                'Setujui permintaan sekolah di atas untuk mengaktifkan pengiriman dan penerimaan batch.',
          )
        else
          LacakSectionSurface.separated(
            children: approvedSchools
                .map((school) => _ApprovedSchoolTile(school: school))
                .toList(growable: false),
          ),
        if (rejectedSchools.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Ditolak (${rejectedSchools.length})',
            style: AppTypography.tabular(AppTypography.titleSection),
          ),
          const SizedBox(height: AppSpacing.sm),
          LacakSectionSurface.separated(
            children: rejectedSchools
                .map(
                  (school) => Padding(
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
                            Text(school.name, style: AppTypography.titleItem),
                            const LacakStatusTag(
                              level: LacakStatusLevel.danger,
                              label: 'Ditolak',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'NPSN ${school.npsn} · ${school.villageLabel}',
                          style: AppTypography.tabular(
                            AppTypography.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LacakSecondaryButton(
                          label: 'Setujui Kembali',
                          icon: Icons.check_circle_rounded,
                          isLoading: processingSchoolId == school.id,
                          onPressed: () => onReview(
                            school,
                            SchoolVerificationStatus.approved,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _PendingSchoolTile extends StatelessWidget {
  const _PendingSchoolTile({
    required this.school,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final PartnerSchoolItem school;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
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
              Text(school.name, style: AppTypography.titleItem),
              const LacakStatusTag(
                level: LacakStatusLevel.warning,
                label: 'Menunggu',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'NPSN ${school.npsn} · ${school.villageLabel}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'WA Puskesmas terdekat: ${school.puskesmasWa}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 340;
              final approveBtn = LacakPrimaryButton(
                label: 'Setujui',
                icon: Icons.check_circle_rounded,
                minHeight: AppSpacing.secondaryButtonMinHeight,
                isLoading: isBusy,
                onPressed: onApprove,
              );
              final rejectBtn = OutlinedButton.icon(
                onPressed: isBusy ? null : onReject,
                icon: const Icon(
                  Icons.dangerous_rounded,
                  size: 20,
                  color: AppColors.dangerFg,
                ),
                label: const Text('Tolak'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    AppSpacing.secondaryButtonMinHeight,
                  ),
                  foregroundColor: AppColors.dangerFg,
                  side: const BorderSide(
                    color: AppColors.dangerBorder,
                    width: 1.5,
                  ),
                ),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    approveBtn,
                    const SizedBox(height: AppSpacing.md),
                    rejectBtn,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: approveBtn),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: rejectBtn),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApprovedSchoolTile extends StatelessWidget {
  const _ApprovedSchoolTile({required this.school});

  final PartnerSchoolItem school;

  Widget _buildDailyTag() {
    switch (school.dailyStatus) {
      case SchoolDailyStatus.received:
        return const LacakStatusTag(
          level: LacakStatusLevel.safe,
          label: 'Sudah Terima',
        );
      case SchoolDailyStatus.anomaly:
        return const LacakStatusTag(
          level: LacakStatusLevel.danger,
          label: 'Anomali',
        );
      case SchoolDailyStatus.notScanned:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusTag),
            border: Border.all(color: AppColors.borderHairline, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Belum Scan',
                style: AppTypography.labelTag.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(school.name, style: AppTypography.titleItem),
              _buildDailyTag(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'NPSN ${school.npsn} · ${school.villageLabel}',
            style: AppTypography.tabular(AppTypography.bodyMedium),
          ),
          if (school.lastScannedAtUtc != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Scan hari ini: ${formatWibTime(school.lastScannedAtUtc!)}',
              style: AppTypography.tabular(AppTypography.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

enum _SchoolFilterTab {
  pending,
  verified,
  rejected,
}

/// D04: Editorial SPPG Partner School Management with invite code bar,
/// filter chip tabs, and borderless school rows.
class KitchenSchoolsScreen extends ConsumerStatefulWidget {
  const KitchenSchoolsScreen({super.key});

  @override
  ConsumerState<KitchenSchoolsScreen> createState() =>
      _KitchenSchoolsScreenState();
}

class _KitchenSchoolsScreenState extends ConsumerState<KitchenSchoolsScreen> {
  String? _processingSchoolId;
  _SchoolFilterTab? _selectedTab;

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
            borderRadius: BorderRadius.circular(AppSpacing.radiusHero),
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
                          AppSpacing.radiusSurface,
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
    final maxWidth = width >= 900 ? 840.0 : AppSpacing.maxContentWidth(width);

    if (kitchen == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(
              message: 'Profil dapur SPPG belum tersedia.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          const MinimalTopHeader(
            contextLabel: 'Manajemen Mitra',
            title: 'Sekolah Binaan',
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(kitchenSchoolsProvider);
                await ref.read(kitchenSchoolsProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  AppSpacing.sm,
                  horizontalPad,
                  AppSpacing.xxxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InviteCodePanel(
                          inviteCode: kitchen.inviteCode,
                          onCopy: () => _copyInviteCode(kitchen.inviteCode),
                          onShowQr: () => _showProfileQrDialog(kitchen),
                        ),
                        const SizedBox(height: AppSpacing.xl),
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
                          data: (schools) {
                            final pending = schools
                                .where(
                                  (s) =>
                                      s.verificationStatus ==
                                      SchoolVerificationStatus.pending,
                                )
                                .toList(growable: false);
                            final verified = schools
                                .where(
                                  (s) =>
                                      s.verificationStatus ==
                                      SchoolVerificationStatus.approved,
                                )
                                .toList(growable: false);
                            final rejected = schools
                                .where(
                                  (s) =>
                                      s.verificationStatus ==
                                      SchoolVerificationStatus.rejected,
                                )
                                .toList(growable: false);

                            final activeTab = _selectedTab ??
                                (pending.isNotEmpty
                                    ? _SchoolFilterTab.pending
                                    : _SchoolFilterTab.verified);

                            final chipItems = <FilterChipItem<_SchoolFilterTab>>[
                              FilterChipItem(
                                value: _SchoolFilterTab.pending,
                                label:
                                    'Menunggu Persetujuan (${pending.length})',
                              ),
                              FilterChipItem(
                                value: _SchoolFilterTab.verified,
                                label: 'Terverifikasi (${verified.length})',
                              ),
                              if (rejected.isNotEmpty)
                                FilterChipItem(
                                  value: _SchoolFilterTab.rejected,
                                  label: 'Ditolak (${rejected.length})',
                                ),
                            ];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilterChipStrip<_SchoolFilterTab>(
                                  padding: EdgeInsets.zero,
                                  selectedValue: activeTab,
                                  onSelected: (next) =>
                                      setState(() => _selectedTab = next),
                                  items: chipItems,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                switch (activeTab) {
                                  _SchoolFilterTab.pending =>
                                    _PendingSchoolsList(
                                      schools: pending,
                                      processingSchoolId: _processingSchoolId,
                                      onApprove: (school) => _handleDecision(
                                        kitchen: kitchen,
                                        school: school,
                                        decision:
                                            SchoolVerificationStatus.approved,
                                      ),
                                      onReject: (school) => _handleDecision(
                                        kitchen: kitchen,
                                        school: school,
                                        decision:
                                            SchoolVerificationStatus.rejected,
                                      ),
                                    ),
                                  _SchoolFilterTab.verified =>
                                    _VerifiedSchoolsList(schools: verified),
                                  _SchoolFilterTab.rejected =>
                                    _RejectedSchoolsList(
                                      schools: rejected,
                                      processingSchoolId: _processingSchoolId,
                                      onReapprove: (school) => _handleDecision(
                                        kitchen: kitchen,
                                        school: school,
                                        decision:
                                            SchoolVerificationStatus.approved,
                                      ),
                                    ),
                                },
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
        ],
      ),
    );
  }
}

class _InviteCodePanel extends StatelessWidget {
  const _InviteCodePanel({
    required this.inviteCode,
    required this.onCopy,
    required this.onShowQr,
  });

  final String inviteCode;
  final VoidCallback onCopy;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Kode Mitra SPPG', style: AppTypography.captionMuted),
              const LacakStatusTag(
                level: LacakStatusLevel.safe,
                label: 'AKTIF',
                icon: Icons.qr_code_2_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            inviteCode,
            style: AppTypography.tabular(
              AppTypography.displayStatus.copyWith(fontSize: 26),
            ).copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            'Bagikan kode ini atau tampilkan QR Profil kepada Guru / PIC sekolah binaan.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 310 || textScale >= 1.25;
              final copyBtn = LacakPrimaryButton(
                label: 'Salin Kode',
                icon: Icons.copy_rounded,
                minHeight: AppSpacing.minTouchTarget,
                onPressed: onCopy,
              );
              final qrBtn = LacakSecondaryButton(
                label: 'QR Profil',
                icon: Icons.qr_code_2_rounded,
                onPressed: onShowQr,
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copyBtn,
                    const SizedBox(height: AppSpacing.sm),
                    qrBtn,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: copyBtn),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: qrBtn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingSchoolsList extends StatelessWidget {
  const _PendingSchoolsList({
    required this.schools,
    required this.processingSchoolId,
    required this.onApprove,
    required this.onReject,
  });

  final List<PartnerSchoolItem> schools;
  final String? processingSchoolId;
  final ValueChanged<PartnerSchoolItem> onApprove;
  final ValueChanged<PartnerSchoolItem> onReject;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const LacakEmptyState(
        icon: Icons.mark_email_read_rounded,
        title: 'Tidak ada permintaan menunggu',
        message:
            'Permintaan dari sekolah baru yang memasukkan Kode Mitra Anda akan tampil di sini.',
      );
    }

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < schools.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BorderlessThumbTile(
                  padding: EdgeInsets.zero,
                  fallbackIcon: Icons.school_rounded,
                  fallbackBgColor: AppColors.warnBg,
                  fallbackIconColor: AppColors.warnFg,
                  title: schools[i].name,
                  statusText: 'Menunggu Persetujuan',
                  statusColor: AppColors.warnFg,
                  metadata: [
                    BorderlessMetaItem(
                      icon: Icons.badge_outlined,
                      label: 'NPSN ${schools[i].npsn}',
                    ),
                    BorderlessMetaItem(
                      icon: Icons.location_on_rounded,
                      label: schools[i].villageLabel,
                    ),
                    BorderlessMetaItem(
                      icon: Icons.local_hospital_rounded,
                      label: 'WA ${schools[i].puskesmasWa}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isBusy = processingSchoolId == schools[i].id;
                    final stack =
                        constraints.maxWidth < 310 || textScale >= 1.25;
                    final approveBtn = LacakPrimaryButton(
                      label: 'Setujui',
                      icon: Icons.check_circle_rounded,
                      minHeight: AppSpacing.minTouchTarget,
                      isLoading: isBusy,
                      onPressed: () => onApprove(schools[i]),
                    );
                    final rejectBtn = OutlinedButton.icon(
                      onPressed: isBusy ? null : () => onReject(schools[i]),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.dangerFg,
                      ),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppSpacing.minTouchTarget,
                        ),
                        foregroundColor: AppColors.dangerFg,
                        side: const BorderSide(
                          color: AppColors.dangerBorder,
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusChip,
                          ),
                        ),
                      ),
                    );
                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          approveBtn,
                          const SizedBox(height: AppSpacing.sm),
                          rejectBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: approveBtn),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: rejectBtn),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (i < schools.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _VerifiedSchoolsList extends StatelessWidget {
  const _VerifiedSchoolsList({required this.schools});

  final List<PartnerSchoolItem> schools;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const LacakEmptyState(
        icon: Icons.school_rounded,
        title: 'Belum ada sekolah terverifikasi',
        message:
            'Setujui permintaan sekolah di tab Menunggu Persetujuan untuk mengaktifkan distribusi.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < schools.length; i++)
          _buildVerifiedTile(
            school: schools[i],
            showDivider: i < schools.length - 1,
          ),
      ],
    );
  }

  Widget _buildVerifiedTile({
    required PartnerSchoolItem school,
    required bool showDivider,
  }) {
    final String statusText;
    final Color statusColor;
    final Color thumbBg;
    final Color thumbFg;

    switch (school.dailyStatus) {
      case SchoolDailyStatus.received:
        statusText = 'Sudah Terima';
        statusColor = AppColors.safeFg;
        thumbBg = AppColors.safeBg;
        thumbFg = AppColors.safeFg;
      case SchoolDailyStatus.anomaly:
        statusText = 'Anomali Dilaporkan';
        statusColor = AppColors.dangerFg;
        thumbBg = AppColors.dangerBg;
        thumbFg = AppColors.dangerFg;
      case SchoolDailyStatus.notScanned:
        statusText = 'Belum Scan Hari Ini';
        statusColor = AppColors.primary;
        thumbBg = AppColors.surfaceSoft;
        thumbFg = AppColors.primary;
    }

    return BorderlessThumbTile(
      fallbackIcon: Icons.school_rounded,
      fallbackBgColor: thumbBg,
      fallbackIconColor: thumbFg,
      title: school.name,
      statusText: statusText,
      statusColor: statusColor,
      metadata: [
        BorderlessMetaItem(
          icon: Icons.location_on_rounded,
          label: '${school.villageLabel} · NPSN ${school.npsn}',
        ),
        BorderlessMetaItem(
          icon: Icons.schedule_rounded,
          label: school.lastScannedAtUtc != null
              ? 'Scan ${formatWibTime(school.lastScannedAtUtc!)}'
              : 'Belum ada pindaian',
        ),
      ],
      showBottomDivider: showDivider,
    );
  }
}

class _RejectedSchoolsList extends StatelessWidget {
  const _RejectedSchoolsList({
    required this.schools,
    required this.processingSchoolId,
    required this.onReapprove,
  });

  final List<PartnerSchoolItem> schools;
  final String? processingSchoolId;
  final ValueChanged<PartnerSchoolItem> onReapprove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < schools.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BorderlessThumbTile(
                  padding: EdgeInsets.zero,
                  fallbackIcon: Icons.school_rounded,
                  fallbackBgColor: AppColors.dangerBg,
                  fallbackIconColor: AppColors.dangerFg,
                  title: schools[i].name,
                  statusText: 'Ditolak',
                  statusColor: AppColors.dangerFg,
                  metadata: [
                    BorderlessMetaItem(
                      icon: Icons.badge_outlined,
                      label: 'NPSN ${schools[i].npsn}',
                    ),
                    BorderlessMetaItem(
                      icon: Icons.location_on_rounded,
                      label: schools[i].villageLabel,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LacakSecondaryButton(
                  label: 'Setujui Kembali',
                  icon: Icons.check_circle_rounded,
                  isLoading: processingSchoolId == schools[i].id,
                  onPressed: () => onReapprove(schools[i]),
                ),
              ],
            ),
          ),
          if (i < schools.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

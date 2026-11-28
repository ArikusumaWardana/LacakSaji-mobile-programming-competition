import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/borderless_thumb_tile.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../../core/widgets/sticky_bottom_action_bar.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/team_security_models.dart';
import 'team_security_providers.dart';

/// C02: Editorial Multi-PIC team and Ed25519 key rotation/revocation screen.
class TeamSecurityScreen extends ConsumerStatefulWidget {
  const TeamSecurityScreen({super.key});

  @override
  ConsumerState<TeamSecurityScreen> createState() => _TeamSecurityScreenState();
}

class _TeamSecurityScreenState extends ConsumerState<TeamSecurityScreen> {
  bool _actionBusy = false;

  Future<void> _openAddMemberSheet(TeamSecurityOverview overview) async {
    if (_actionBusy) {
      return;
    }
    final request = await showModalBottomSheet<_AddMemberFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCanvas,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusHero),
        ),
      ),
      builder: (_) => _AddMemberSheet(
        institutionType: overview.institutionType,
      ),
    );
    if (request == null || !mounted) {
      return;
    }

    setState(() => _actionBusy = true);
    try {
      final authState = ref.read(authControllerProvider);
      final isOffline = ref.read(isOfflineProvider).value ?? false;
      final added = await ref
          .read(teamSecurityRepositoryProvider)
          .addMember(
            authState: authState,
            memberName: request.name,
            memberEmail: request.email,
            role: request.role,
            isOffline: isOffline,
          );
      ref.invalidate(teamSecurityOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added.isPendingSync
                ? '${added.memberName} disimpan di HP (Menunggu Sinyal).'
                : '${added.memberName} berhasil ditambahkan sebagai ${added.role.label}.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belum dapat menambah anggota: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _toggleMemberActive(InstitutionMemberItem member) async {
    if (_actionBusy || member.isOwner) {
      return;
    }
    final nextActive = !member.isActive;
    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: nextActive ? 'Aktifkan Anggota Tim?' : 'Nonaktifkan Anggota Tim?',
      message: nextActive
          ? '${member.memberName} akan kembali mendapat akses peran ${member.role.label}.'
          : '${member.memberName} tidak akan dapat mengakses data institusi sampai diaktifkan kembali.',
      confirmLabel: nextActive ? 'Ya, Aktifkan' : 'Ya, Nonaktifkan',
      isDanger: !nextActive,
      confirmIcon: nextActive
          ? Icons.check_circle_rounded
          : Icons.person_off_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _actionBusy = true);
    try {
      final authState = ref.read(authControllerProvider);
      final isOffline = ref.read(isOfflineProvider).value ?? false;
      await ref
          .read(teamSecurityRepositoryProvider)
          .setMemberActive(
            authState: authState,
            member: member,
            isActive: nextActive,
            isOffline: isOffline,
          );
      ref.invalidate(teamSecurityOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive
                ? '${member.memberName} telah diaktifkan kembali.'
                : '${member.memberName} telah dinonaktifkan.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status anggota: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _openRotateKeyFlow(KitchenProfile kitchen) async {
    if (_actionBusy) {
      return;
    }
    final form = await showModalBottomSheet<_RotateKeyFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCanvas,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusHero),
        ),
      ),
      builder: (_) => const _RotateKeySheet(),
    );
    if (form == null || !mounted) {
      return;
    }

    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: form.revokePrevious
          ? 'Rotasi & Cabut Kunci Lama?'
          : 'Rotasi Kunci Perangkat Baru?',
      message: form.revokePrevious
          ? 'Kunci lama langsung dicabut. QR baru yang dicetak dengan kunci lama akan ditolak sekolah.'
          : 'Kunci baru langsung aktif. QR yang sudah dicetak memakai kunci lama tetap sah saat dipindai sekolah.',
      confirmLabel: form.revokePrevious
          ? 'Ya, Rotasi & Cabut'
          : 'Ya, Terbitkan Kunci Baru',
      isDanger: form.revokePrevious,
      confirmIcon: Icons.vpn_key_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _actionBusy = true);
    try {
      final isOffline = ref.read(isOfflineProvider).value ?? false;
      final created = await ref
          .read(teamSecurityRepositoryProvider)
          .rotateKitchenSigningKey(
            kitchen: kitchen,
            revokePrevious: form.revokePrevious,
            deviceLabel: form.deviceLabel,
            isOffline: isOffline,
          );
      ref.invalidate(teamSecurityOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kunci ${created.keyId} kini aktif untuk penandatanganan QR batch baru.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal merotasi kunci: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _confirmRevokeKey(
    KitchenProfile kitchen,
    SigningKeyItem keyItem,
  ) async {
    if (_actionBusy || keyItem.status == SigningKeyStatus.revoked) {
      return;
    }
    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: 'Cabut Kunci ${keyItem.keyId}?',
      message:
          'Gunakan opsi ini bila perangkat pencetak QR hilang atau disalahgunakan. Batch baru dari kunci ini akan ditolak oleh sekolah.',
      confirmLabel: 'Ya, Cabut Kunci',
      isDanger: true,
      confirmIcon: Icons.gpp_bad_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _actionBusy = true);
    try {
      final isOffline = ref.read(isOfflineProvider).value ?? false;
      await ref
          .read(teamSecurityRepositoryProvider)
          .revokeKitchenSigningKey(
            kitchen: kitchen,
            keyId: keyItem.keyId,
            isOffline: isOffline,
          );
      ref.invalidate(teamSecurityOverviewProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunci ${keyItem.keyId} berstatus DICABUT.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencabut kunci: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final overviewAsync = ref.watch(teamSecurityOverviewProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);
    final isTablet = width >= AppSpacing.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.md,
                horizontalPad,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Material(
                    color: AppColors.surfaceSoft,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Keamanan & Tim Institusi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kelola Tim & Keamanan Kunci',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlinePage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: overviewAsync.when(
              loading: () => Padding(
                padding: EdgeInsets.all(horizontalPad),
                child: const LacakSkeletonList(
                  itemCount: 4,
                  loadingLabel: 'Memuat daftar tim dan kunci keamanan...',
                ),
              ),
              error: (error, _) => SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPad),
                child: LacakErrorState(
                  title: 'Data tim belum dapat dimuat',
                  message:
                      'Periksa koneksi atau coba muat ulang data tim dan kunci perangkat. ($error)',
                  onRetry: () => ref.invalidate(teamSecurityOverviewProvider),
                ),
              ),
              data: (overview) {
                final teamSection = _TeamMembersSection(
                  overview: overview,
                  busy: _actionBusy,
                  onToggleActive: _toggleMemberActive,
                );
                final keysSection = _SigningKeysSection(
                  overview: overview,
                  kitchen: authState.kitchen,
                  busy: _actionBusy,
                  onRotateKey: authState.kitchen == null
                      ? null
                      : () => _openRotateKeyFlow(authState.kitchen!),
                  onRevokeKey: authState.kitchen == null
                      ? null
                      : (keyItem) =>
                            _confirmRevokeKey(authState.kitchen!, keyItem),
                );

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(teamSecurityOverviewProvider);
                    await ref.read(teamSecurityOverviewProvider.future);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      AppSpacing.md,
                      horizontalPad,
                      AppSpacing.xxxl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              overview.institutionName,
                              style: AppTypography.titleSection.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Tambah staf pengganti (Multi-PIC) agar pemeriksaan harian tetap berjalan saat admin utama berhalangan.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            if (isTablet)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: teamSection),
                                  const SizedBox(width: AppSpacing.xxl),
                                  Expanded(child: keysSection),
                                ],
                              )
                            else ...[
                              teamSection,
                              const SizedBox(height: AppSpacing.xxl),
                              const Divider(height: 1),
                              const SizedBox(height: AppSpacing.xl),
                              keysSection,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (overviewAsync.hasValue)
            StickyBottomActionBar(
              summaryLabel: 'Anggota Aktif',
              summaryValue:
                  '${overviewAsync.value!.activeMemberCount} dari ${overviewAsync.value!.members.length} PIC',
              ctaLabel: 'Tambah Staf',
              ctaIcon: Icons.group_rounded,
              isLoading: _actionBusy,
              onCtaPressed: () => _openAddMemberSheet(overviewAsync.value!),
            ),
        ],
      ),
    );
  }
}

class _TeamMembersSection extends StatelessWidget {
  const _TeamMembersSection({
    required this.overview,
    required this.busy,
    required this.onToggleActive,
  });

  final TeamSecurityOverview overview;
  final bool busy;
  final ValueChanged<InstitutionMemberItem> onToggleActive;

  IconData _roleIcon(InstitutionMemberRole role) {
    return switch (role) {
      InstitutionMemberRole.admin => Icons.verified_user_rounded,
      InstitutionMemberRole.courier => Icons.local_shipping_rounded,
      InstitutionMemberRole.staff => Icons.group_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Anggota Tim Pelaksana (Multi-PIC)',
          style: AppTypography.titleSection,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (overview.members.isEmpty)
          const LacakEmptyState(
            icon: Icons.group_rounded,
            title: 'Belum ada staf tambahan',
            message: 'Ketuk Tambah Staf di bawah untuk mendaftarkan staf PIC.',
          )
        else
          for (var i = 0; i < overview.members.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderHairline,
              ),
            _MemberBorderlessRow(
              member: overview.members[i],
              icon: _roleIcon(overview.members[i].role),
              busy: busy,
              onToggle: () => onToggleActive(overview.members[i]),
            ),
          ],
      ],
    );
  }
}

class _MemberBorderlessRow extends StatelessWidget {
  const _MemberBorderlessRow({
    required this.member,
    required this.icon,
    required this.busy,
    required this.onToggle,
  });

  final InstitutionMemberItem member;
  final IconData icon;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final statusPrefix = member.isActive ? 'AKTIF' : 'NONAKTIF';
    final statusColor = member.isActive
        ? AppColors.safeFg
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BorderlessThumbTile(
          title: member.isOwner
              ? '${member.memberName} (Pemilik Akun)'
              : member.memberName,
          statusText: '$statusPrefix · ${member.role.label}',
          statusColor: statusColor,
          fallbackIcon: icon,
          fallbackBgColor: member.isActive
              ? AppColors.primaryTint
              : AppColors.surfaceSoft,
          fallbackIconColor: member.isActive
              ? AppColors.primary
              : AppColors.textSecondary,
          metadata: [
            if (member.memberEmail.isNotEmpty)
              BorderlessMetaItem(
                icon: Icons.mail_outline_rounded,
                label: member.memberEmail,
              ),
            BorderlessMetaItem(
              icon: Icons.calendar_today_rounded,
              label: formatIndonesianDate(member.createdAtUtc),
            ),
          ],
        ),
        if (!member.isOwner) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : onToggle,
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  AppSpacing.minTouchTarget,
                  AppSpacing.minTouchTarget,
                ),
                foregroundColor: member.isActive
                    ? AppColors.dangerFg
                    : AppColors.primary,
              ),
              icon: Icon(
                member.isActive
                    ? Icons.person_off_rounded
                    : Icons.check_circle_rounded,
                size: 18,
              ),
              label: Text(
                member.isActive ? 'Nonaktifkan Staf' : 'Aktifkan Kembali',
                style: AppTypography.labelTag.copyWith(
                  color: member.isActive
                      ? AppColors.dangerFg
                      : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _SigningKeysSection extends StatelessWidget {
  const _SigningKeysSection({
    required this.overview,
    required this.kitchen,
    required this.busy,
    required this.onRotateKey,
    required this.onRevokeKey,
  });

  final TeamSecurityOverview overview;
  final KitchenProfile? kitchen;
  final bool busy;
  final VoidCallback? onRotateKey;
  final ValueChanged<SigningKeyItem>? onRevokeKey;

  Color _statusColor(SigningKeyStatus status) {
    return switch (status) {
      SigningKeyStatus.active => AppColors.safeFg,
      SigningKeyStatus.retired => AppColors.warnFg,
      SigningKeyStatus.revoked => AppColors.dangerFg,
    };
  }

  LacakStatusLevel _statusLevel(SigningKeyStatus status) {
    return switch (status) {
      SigningKeyStatus.active => LacakStatusLevel.safe,
      SigningKeyStatus.retired => LacakStatusLevel.warning,
      SigningKeyStatus.revoked => LacakStatusLevel.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isKitchenAdmin = overview.canManageKeys && kitchen != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isKitchenAdmin
              ? 'Keamanan Kunci QR (Ed25519)'
              : 'Kunci Verifikasi Dapur Mitra',
          style: AppTypography.titleSection,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isKitchenAdmin
              ? 'Rotasi kunci secara berkala atau cabut akses bila HP pencetak QR rusak/hilang. QR lama dari kunci pensiun aman tetap terbaca di sekolah.'
              : 'Daftar kunci publik Ed25519 SPPG mitra yang tersimpan di HP untuk verifikasi QR tanpa sinyal.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (isKitchenAdmin && onRotateKey != null) ...[
          const SizedBox(height: AppSpacing.md),
          LacakSecondaryButton(
            label: 'Rotasi Kunci Perangkat',
            icon: Icons.vpn_key_rounded,
            isLoading: busy,
            onPressed: busy ? null : onRotateKey,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (overview.signingKeys.isEmpty)
          const LacakEmptyState(
            icon: Icons.vpn_key_rounded,
            title: 'Belum ada catatan kunci QR',
            message:
                'Kunci keamanan otomatis dibuat saat Dapur SPPG menerbitkan QR batch pertama.',
          )
        else
          for (var i = 0; i < overview.signingKeys.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderHairline,
              ),
            _KeyBorderlessRow(
              keyItem: overview.signingKeys[i],
              statusColor: _statusColor(overview.signingKeys[i].status),
              statusLevel: _statusLevel(overview.signingKeys[i].status),
              canRevoke:
                  isKitchenAdmin &&
                  overview.signingKeys[i].status != SigningKeyStatus.revoked &&
                  onRevokeKey != null,
              busy: busy,
              onRevoke: onRevokeKey == null
                  ? null
                  : () => onRevokeKey!(overview.signingKeys[i]),
            ),
          ],
      ],
    );
  }
}

class _KeyBorderlessRow extends StatelessWidget {
  const _KeyBorderlessRow({
    required this.keyItem,
    required this.statusColor,
    required this.statusLevel,
    required this.canRevoke,
    required this.busy,
    required this.onRevoke,
  });

  final SigningKeyItem keyItem;
  final Color statusColor;
  final LacakStatusLevel statusLevel;
  final bool canRevoke;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final deviceLabel = (keyItem.deviceLabel ?? '').isNotEmpty
        ? keyItem.deviceLabel!
        : 'Perangkat SPPG';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BorderlessThumbTile(
          title: keyItem.keyId,
          statusText: '${keyItem.status.badgeLabel} · $deviceLabel',
          statusColor: statusColor,
          fallbackIcon: Icons.vpn_key_rounded,
          fallbackBgColor: AppColors.surfaceSoft,
          fallbackIconColor: statusColor,
          metadata: [
            BorderlessMetaItem(
              icon: Icons.schedule_rounded,
              label: 'Dibuat ${formatIndonesianDate(keyItem.createdAtUtc)}',
            ),
            if (keyItem.revokedAtUtc != null)
              BorderlessMetaItem(
                icon: Icons.gpp_bad_rounded,
                label: 'Dicabut ${formatIndonesianDate(keyItem.revokedAtUtc!)}',
              )
            else if (keyItem.retiredAtUtc != null)
              BorderlessMetaItem(
                icon: Icons.history_rounded,
                label: 'Pensiun ${formatIndonesianDate(keyItem.retiredAtUtc!)}',
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LacakStatusTag(
                level: statusLevel,
                label: keyItem.status.badgeLabel,
              ),
              if (canRevoke && onRevoke != null)
                TextButton.icon(
                  onPressed: busy ? null : onRevoke,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppSpacing.minTouchTarget,
                      AppSpacing.minTouchTarget,
                    ),
                    foregroundColor: AppColors.dangerFg,
                  ),
                  icon: const Icon(Icons.gpp_bad_rounded, size: 18),
                  label: Text(
                    'Cabut Kunci',
                    style: AppTypography.labelTag.copyWith(
                      color: AppColors.dangerFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddMemberFormResult {
  const _AddMemberFormResult({
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final InstitutionMemberRole role;
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.institutionType});

  final InstitutionType institutionType;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  InstitutionMemberRole _selectedRole = InstitutionMemberRole.staff;
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  List<InstitutionMemberRole> get _availableRoles =>
      widget.institutionType == InstitutionType.sppg
      ? const [
          InstitutionMemberRole.staff,
          InstitutionMemberRole.courier,
          InstitutionMemberRole.admin,
        ]
      : const [
          InstitutionMemberRole.staff,
          InstitutionMemberRole.admin,
        ];

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.length < 2) {
      setState(() => _validationError = 'Nama lengkap anggota wajib diisi.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _validationError = 'Masukkan alamat email yang valid.');
      return;
    }
    Navigator.of(context).pop(
      _AddMemberFormResult(
        name: name,
        email: email,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tambah Staf Pelaksana', style: AppTypography.titleSection),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Anggota dapat masuk memakai akun email LacakSaji untuk membantu pencatatan harian.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LacakTextField(
              label: 'Nama Lengkap',
              controller: _nameController,
              hintText: 'Contoh: Pak Hendra',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            LacakTextField(
              label: 'Email Akun LacakSaji',
              controller: _emailController,
              hintText: 'nama@institusi.id',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Peran di Institusi',
              style: AppTypography.titleItem,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final role in _availableRoles) ...[
              _ChoiceTile(
                title: role.label,
                selected: _selectedRole == role,
                onTap: () => setState(() => _selectedRole = role),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_validationError != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _validationError!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.dangerFg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            LacakPrimaryButton(
              label: 'Simpan Anggota Tim',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            LacakSecondaryButton(
              label: 'Batal',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotateKeyFormResult {
  const _RotateKeyFormResult({
    required this.deviceLabel,
    required this.revokePrevious,
  });

  final String deviceLabel;
  final bool revokePrevious;
}

class _RotateKeySheet extends StatefulWidget {
  const _RotateKeySheet();

  @override
  State<_RotateKeySheet> createState() => _RotateKeySheetState();
}

class _RotateKeySheetState extends State<_RotateKeySheet> {
  final _deviceLabelController = TextEditingController(
    text: 'HP Petugas Dapur Baru',
  );
  bool _revokePrevious = false;

  @override
  void dispose() {
    _deviceLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rotasi Kunci Perangkat SPPG',
              style: AppTypography.titleSection,
            ),
            const SizedBox(height: AppSpacing.md),
            LacakTextField(
              label: 'Label Perangkat Baru',
              controller: _deviceLabelController,
              hintText: 'Contoh: Tablet Kemas 2',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Perlakukan Kunci Sebelumnya Sebagai:',
              style: AppTypography.titleItem,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChoiceTile(
              title: 'Pensiun Aman (QR lama tetap diterima sekolah)',
              selected: !_revokePrevious,
              onTap: () => setState(() => _revokePrevious = false),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChoiceTile(
              title: 'Cabut Paksa (HP hilang / rusak, tolak QR baru)',
              selected: _revokePrevious,
              onTap: () => setState(() => _revokePrevious = true),
            ),
            const SizedBox(height: AppSpacing.lg),
            LacakPrimaryButton(
              label: 'Lanjutkan Rotasi Kunci',
              icon: Icons.vpn_key_rounded,
              onPressed: () {
                Navigator.of(context).pop(
                  _RotateKeyFormResult(
                    deviceLabel: _deviceLabelController.text.trim(),
                    revokePrevious: _revokePrevious,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            LacakSecondaryButton(
              label: 'Batal',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryTint : AppColors.surfaceBase,
      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderHairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: selected
                        ? AppColors.onPrimaryTint
                        : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

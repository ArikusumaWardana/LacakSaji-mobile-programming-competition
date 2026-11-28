import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/sync/offline_sync_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/text_scale_provider.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_sync_queue_sheet.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../allergens/domain/allergen_models.dart';
import '../../allergens/presentation/allergen_providers.dart';
import '../../allergens/presentation/widgets/school_allergen_profile_sheet.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/adm4_picker_sheet.dart';
import '../../auth/presentation/widgets/location_helper.dart';
import '../../kitchen/presentation/kitchen_providers.dart';
import '../../school/presentation/school_providers.dart';

/// C01: Editorial flat grouped profile, comfortable text scale chips,
/// sync status, operational settings, and sign-out screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editSchoolSettings(
    BuildContext context,
    WidgetRef ref,
    SchoolProfile school,
  ) async {
    final result = await showDialog<_SchoolOperationalEditResult>(
      context: context,
      builder: (_) => _EditSchoolOperationalDialog(
        initialPuskesmasWa: school.puskesmasWa,
        initialAdm4Code: school.adm4Code,
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }

    if (result.puskesmasWa.length < 10 || result.adm4Code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nomor WhatsApp minimal 10 digit dan kode wilayah kelurahan wajib diisi.',
          ),
        ),
      );
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateSchoolSettings(
          puskesmasWa: result.puskesmasWa,
          adm4Code: result.adm4Code,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Pengaturan operasional sekolah berhasil disimpan.'
                : (ref.read(authControllerProvider).errorMessage ??
                    'Gagal menyimpan pengaturan.'),
          ),
        ),
      );
    }
  }

  Future<void> _updateKitchenGps(
    BuildContext context,
    WidgetRef ref,
    KitchenProfile kitchen,
  ) async {
    final capture = await captureDeviceCoordinates();
    if (!context.mounted) {
      return;
    }
    if (!capture.success || capture.lat == null || capture.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(capture.message)),
      );
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateKitchenLocation(
          lat: capture.lat!,
          lng: capture.lng!,
          adm4Code: kitchen.adm4Code,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Titik lokasi GPS dapur berhasil diperbarui.'
                : (ref.read(authControllerProvider).errorMessage ??
                    'Gagal memperbarui lokasi dapur.'),
          ),
        ),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: 'Keluar dari Akun?',
      message:
          'Data pemeriksaan lokal yang belum tersinkronisasi tetap aman di HP ini sampai Anda masuk kembali.',
      confirmLabel: 'Ya, Keluar Akun',
      isDanger: true,
      confirmIcon: Icons.logout_rounded,
    );
    if (confirmed && context.mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  String? _cleanPersonName(String? rawName) {
    if (rawName == null) {
      return null;
    }
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final cleaned = trimmed.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    return cleaned.isEmpty ? trimmed : cleaned;
  }

  String _formatPicAndRole(UserProfile? profile) {
    if (profile == null) {
      return '-';
    }
    final cleanName = _cleanPersonName(profile.fullName) ?? '-';
    return '$cleanName · ${profile.role.label}';
  }

  String _formatAllergenSummary(List<SchoolAllergenEntry> entries) {
    if (entries.isEmpty) {
      return 'Belum ada data alergen siswa yang dicatat. Ketuk tombol di bawah untuk mengatur daftar alergen sekolah.';
    }
    return entries
        .map((e) => '${e.allergen.label} (${e.studentCount} siswa)')
        .join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final schoolAllergensAsync = ref.watch(schoolAllergensProvider);
    final textScale = ref.watch(textScaleProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);
    final anyBusy = authState.isBusy || syncState.isSyncing;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);
    final inAppShell = AppShellScope.maybeOf(context) != null;

    final profile = authState.profile;
    final kitchen = authState.kitchen;
    final school = authState.school;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: Column(
        children: [
          if (inAppShell)
            const MinimalTopHeader(
              contextLabel: 'Akun & Aplikasi',
              title: 'Profil & Pengaturan',
            )
          else
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
                      child: Text(
                        'Profil & Pengaturan',
                        style: AppTypography.headlinePage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
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
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            kitchen?.name ??
                                school?.name ??
                                _cleanPersonName(profile?.fullName) ??
                                'Pengguna LacakSaji',
                            style: AppTypography.titleSection.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          LacakStatusTag(
                            level: school?.verificationStatus ==
                                    SchoolVerificationStatus.pending
                                ? LacakStatusLevel.warning
                                : (school?.verificationStatus ==
                                          SchoolVerificationStatus.rejected
                                      ? LacakStatusLevel.danger
                                      : LacakStatusLevel.safe),
                            label: school != null
                                ? school.verificationStatus.label.toUpperCase()
                                : 'TERVERIFIKASI',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPicAndRole(profile),
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if ((profile?.email ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile!.email,
                          style: AppTypography.captionMuted,
                        ),
                      ],
                      if (kitchen != null || school != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        if (kitchen != null) ...[
                          _FlatSettingsRow(
                            label: 'Kode Mitra SPPG',
                            value: kitchen.inviteCode,
                            tabular: true,
                          ),
                          const Divider(height: 1),
                          _FlatSettingsRow(
                            label: 'Nomor Registrasi',
                            value: kitchen.regNumber,
                            tabular: true,
                          ),
                        ],
                        if (school != null) ...[
                          _FlatSettingsRow(
                            label: 'NPSN Sekolah',
                            value: school.npsn,
                            tabular: true,
                          ),
                          const Divider(height: 1),
                          _FlatSettingsRow(
                            label: 'Mitra SPPG',
                            value: school.partnerKitchenName ?? '-',
                          ),
                        ],
                        const Divider(height: 1),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Ukuran Teks Nyaman',
                        style: AppTypography.titleSection,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _TextScaleSegmentedChips(
                        selected: textScale,
                        onChanged: (selected) {
                          ref
                              .read(textScaleProvider.notifier)
                              .setScale(selected);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Pratinjau: Pastikan suhu penyimpanan sampel makanan selalu terjaga di bawah 5 C selama 48 jam.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Sinkronisasi & Operasional',
                        style: AppTypography.titleSection,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Icon(
                            isOffline
                                ? Icons.cloud_off_rounded
                                : Icons.cloud_done_rounded,
                            size: 22,
                            color: isOffline
                                ? AppColors.infoFg
                                : AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              isOffline
                                  ? 'Mode Tanpa Sinyal'
                                  : 'Terhubung ke Server',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleItem,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            flex: 0,
                            child: Text(
                              '$pendingCount antrean',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.tabular(
                                AppTypography.captionMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LacakSecondaryButton(
                        label: 'Sinkronkan & Perbarui Sekarang',
                        icon: Icons.sync_rounded,
                        isLoading: syncState.isSyncing ||
                            authState.busyAction ==
                                AuthBusyAction.refreshStatus,
                        onPressed: anyBusy
                            ? null
                            : () async {
                                final report = await ref
                                    .read(
                                      offlineSyncControllerProvider.notifier,
                                    )
                                    .syncNowWithReport();
                                final totalSynced = report.syncedCount;
                                if (totalSynced > 0) {
                                  if (kitchen != null) {
                                    invalidateKitchenProviders(ref);
                                  }
                                  if (school != null) {
                                    invalidateSchoolProviders(ref);
                                  }
                                }
                                final ok = await ref
                                    .read(authControllerProvider.notifier)
                                    .refreshStatus();
                                if (context.mounted) {
                                  final syncFeedback =
                                      report.remainingCount > 0 ||
                                          totalSynced > 0
                                      ? report.buildFeedbackMessage()
                                      : (ok
                                            ? 'Status akun dan profil berhasil disinkronkan.'
                                            : (ref
                                                      .read(
                                                        authControllerProvider,
                                                      )
                                                      .errorMessage ??
                                                  'Sinkronisasi belum berhasil.'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(syncFeedback),
                                      action: report.remainingCount > 0
                                          ? SnackBarAction(
                                              label: 'Lihat Rincian',
                                              onPressed: () {
                                                if (context.mounted) {
                                                  showPendingSyncQueueSheet(
                                                    context,
                                                    ref,
                                                  );
                                                }
                                              },
                                            )
                                          : null,
                                    ),
                                  );
                                }
                              },
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                showPendingSyncQueueSheet(context, ref),
                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                            label: Text(
                              'Lihat Rincian $pendingCount Data Belum Terkirim',
                            ),
                          ),
                        ),
                      ],
                      if (school != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        _FlatSettingsRow(
                          label: 'WhatsApp Puskesmas',
                          value: school.formattedPuskesmasWa,
                          tabular: true,
                        ),
                        const Divider(height: 1),
                        _FlatSettingsRow(
                          label: 'Kode Wilayah Kelurahan',
                          value: school.adm4Code,
                          tabular: true,
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        LacakSecondaryButton(
                          label: 'Ubah WA Puskesmas & Wilayah',
                          icon: Icons.edit_rounded,
                          isLoading: authState.busyAction ==
                              AuthBusyAction.updateSchoolSettings,
                          onPressed: anyBusy
                              ? null
                              : () => _editSchoolSettings(
                                  context,
                                  ref,
                                  school,
                                ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Profil Alergen Siswa (Tanpa Nama)',
                          style: AppTypography.titleSection,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatAllergenSummary(
                            schoolAllergensAsync.value ?? const [],
                          ),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LacakSecondaryButton(
                          label: 'Atur Profil Alergen Siswa',
                          icon: Icons.health_and_safety_rounded,
                          onPressed: anyBusy
                              ? null
                              : () async {
                                  final saved =
                                      await showModalBottomSheet<bool>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: AppColors.bgCanvas,
                                        constraints: const BoxConstraints(
                                          maxWidth:
                                              AppSpacing.tabletFormMaxWidth,
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(
                                              AppSpacing.radiusHero,
                                            ),
                                          ),
                                        ),
                                        builder: (_) =>
                                            SchoolAllergenProfileSheet(
                                              schoolId: school.id,
                                              initialEntries:
                                                  schoolAllergensAsync.value ??
                                                  const [],
                                            ),
                                      );
                                  if (saved == true && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profil alergen sekolah berhasil disimpan.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                      if (kitchen != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        _FlatSettingsRow(
                          label: 'Kode Wilayah Kelurahan',
                          value: kitchen.adm4Code,
                          tabular: true,
                        ),
                        const Divider(height: 1),
                        _FlatSettingsRow(
                          label: 'Koordinat Dapur',
                          value:
                              '${kitchen.lat.toStringAsFixed(5)}, ${kitchen.lng.toStringAsFixed(5)}',
                          tabular: true,
                        ),
                        const Divider(height: 1),
                        if (profile?.role == UserRole.kitchen) ...[
                          const SizedBox(height: AppSpacing.md),
                          LacakSecondaryButton(
                            label: 'Perbarui Lokasi GPS Dapur',
                            icon: Icons.location_on_rounded,
                            isLoading: authState.busyAction ==
                                AuthBusyAction.updateKitchenLocation,
                            onPressed: anyBusy
                                ? null
                                : () => _updateKitchenGps(
                                    context,
                                    ref,
                                    kitchen,
                                  ),
                          ),
                        ],
                      ],
                      if (authState.isInstitutionAdmin) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Tim & Keamanan Kunci',
                          style: AppTypography.titleSection,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Atur staf pelaksana pengganti (Multi-PIC) serta rotasi kunci segel digital QR.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LacakSecondaryButton(
                          label: 'Kelola Tim & Keamanan Kunci',
                          icon: Icons.group_rounded,
                          onPressed: anyBusy
                              ? null
                              : () => context.push(
                                    AppRoutes.settingsTeamSecurity,
                                  ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      LacakDangerButton(
                        label: 'Keluar Akun',
                        icon: Icons.logout_rounded,
                        isLoading: authState.busyAction == AuthBusyAction.signOut,
                        onPressed: anyBusy
                            ? null
                            : () => _confirmSignOut(context, ref),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '${AppConstants.appName} v${AppConstants.appVersion}',
                        textAlign: TextAlign.center,
                        style: AppTypography.tabular(
                          AppTypography.captionMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppConstants.bmkgFullAttribution,
                        textAlign: TextAlign.center,
                        style: AppTypography.captionLegal,
                      ),
                    ],
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

class _TextScaleSegmentedChips extends StatelessWidget {
  const _TextScaleSegmentedChips({
    required this.selected,
    required this.onChanged,
  });

  final ComfortableTextScale selected;
  final ValueChanged<ComfortableTextScale> onChanged;

  static const _options = [
    (
      value: ComfortableTextScale.standard,
      label: 'Standar',
      percent: '100%',
    ),
    (
      value: ComfortableTextScale.large,
      label: 'Besar',
      percent: '115%',
    ),
    (
      value: ComfortableTextScale.extraLarge,
      label: 'Ekstra Besar',
      percent: '130%',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackChips = constraints.maxWidth < 310 || textScale >= 1.25;
        if (stackChips) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _ScaleChipTile(
                  label: _options[i].label,
                  percent: _options[i].percent,
                  selected: selected == _options[i].value,
                  onTap: () => onChanged(_options[i].value),
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < _options.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ScaleChipTile(
                  label: _options[i].label,
                  percent: _options[i].percent,
                  selected: selected == _options[i].value,
                  onTap: () => onChanged(_options[i].value),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ScaleChipTile extends StatelessWidget {
  const _ScaleChipTile({
    required this.label,
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.primary : AppColors.surfaceSoft;
    final fgColor = selected ? AppColors.onPrimary : AppColors.chipInactiveText;
    final subColor = selected
        ? AppColors.onPrimary.withValues(alpha: 0.88)
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label $percent',
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.secondaryButtonMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelTag.copyWith(
                      color: fgColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    percent,
                    textAlign: TextAlign.center,
                    style: AppTypography.tabular(
                      AppTypography.captionLegal.copyWith(
                        color: subColor,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

class _FlatSettingsRow extends StatelessWidget {
  const _FlatSettingsRow({
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

class _SchoolOperationalEditResult {
  const _SchoolOperationalEditResult({
    required this.puskesmasWa,
    required this.adm4Code,
  });

  final String puskesmasWa;
  final String adm4Code;
}

class _EditSchoolOperationalDialog extends StatefulWidget {
  const _EditSchoolOperationalDialog({
    required this.initialPuskesmasWa,
    required this.initialAdm4Code,
  });

  final String initialPuskesmasWa;
  final String initialAdm4Code;

  @override
  State<_EditSchoolOperationalDialog> createState() =>
      _EditSchoolOperationalDialogState();
}

class _EditSchoolOperationalDialogState
    extends State<_EditSchoolOperationalDialog> {
  late final TextEditingController _waController;
  late final TextEditingController _adm4Controller;

  @override
  void initState() {
    super.initState();
    _waController = TextEditingController(text: widget.initialPuskesmasWa);
    _adm4Controller = TextEditingController(text: widget.initialAdm4Code);
  }

  @override
  void dispose() {
    _waController.dispose();
    _adm4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pengaturan Operasional Sekolah'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LacakTextField(
              label: 'Nomor WhatsApp Puskesmas',
              controller: _waController,
              keyboardType: TextInputType.phone,
              useTabularFigures: true,
            ),
            const SizedBox(height: AppSpacing.md),
            LacakTextField(
              label: 'Kode Wilayah Kelurahan',
              controller: _adm4Controller,
              useTabularFigures: true,
              suffixWidget: IconButton(
                onPressed: () async {
                  final picked = await showAdm4VillagePicker(context);
                  if (!mounted || picked == null) return;
                  _adm4Controller.text = picked.code;
                },
                tooltip: 'Pilih Kelurahan',
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ],
        ),
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
              label: 'Simpan Perubahan',
              onPressed: () => Navigator.of(context).pop(
                _SchoolOperationalEditResult(
                  puskesmasWa: normalizeIndonesianWaNumber(_waController.text),
                  adm4Code: _adm4Controller.text.trim(),
                ),
              ),
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

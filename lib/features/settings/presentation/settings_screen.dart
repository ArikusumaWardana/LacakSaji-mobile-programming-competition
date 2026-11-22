import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/sync/offline_sync_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/text_scale_provider.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_confirm_dialog.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_sync_queue_sheet.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/adm4_picker_sheet.dart';
import '../../auth/presentation/widgets/location_helper.dart';
import '../../kitchen/presentation/kitchen_providers.dart';
import '../../school/presentation/school_providers.dart';

/// C01: Shared profile, comfortable text scale, offline sync status, and logout screen.
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

  /// Strips trailing parenthetical role notes from seeded `fullName` values
  /// (e.g. `Ibu Ratna (Petugas SPPG Purwokerto Utara)` -> `Ibu Ratna`)
  /// so we never render double parentheses like `(Petugas...) (Petugas Dapur SPPG)`.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final textScale = ref.watch(textScaleProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);
    final anyBusy = authState.isBusy || syncState.isSyncing;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);

    final profile = authState.profile;
    final kitchen = authState.kitchen;
    final school = authState.school;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Profil & Pengaturan')),
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
                  // Open profile header directly on canvas (inspired by reference 2 profile header, no nested box)
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
                        style: AppTypography.headlinePage.copyWith(
                          fontSize: 22,
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
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatPicAndRole(profile),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if ((profile?.email ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile!.email,
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                  if (kitchen != null || school != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    LacakSectionSurface.separated(
                      children: [
                        if (kitchen != null) ...[
                          _SettingsRow(
                            label: 'Kode Mitra SPPG',
                            value: kitchen.inviteCode,
                            tabular: true,
                          ),
                          _SettingsRow(
                            label: 'Nomor Registrasi',
                            value: kitchen.regNumber,
                            tabular: true,
                          ),
                        ],
                        if (school != null) ...[
                          _SettingsRow(
                            label: 'NPSN Sekolah',
                            value: school.npsn,
                            tabular: true,
                          ),
                          _SettingsRow(
                            label: 'Mitra SPPG',
                            value: school.partnerKitchenName ?? '-',
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Ukuran Teks Nyaman',
                    style: AppTypography.titleSection,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LacakSegmentedControl<ComfortableTextScale>(
                    options: const [
                      LacakSegmentOption(
                        value: ComfortableTextScale.standard,
                        label: 'Standar',
                        subtitle: '100%',
                      ),
                      LacakSegmentOption(
                        value: ComfortableTextScale.large,
                        label: 'Besar',
                        subtitle: '115%',
                      ),
                      LacakSegmentOption(
                        value: ComfortableTextScale.extraLarge,
                        label: 'Ekstra Besar',
                        subtitle: '130%',
                      ),
                    ],
                    selectedValue: textScale,
                    onChanged: (selected) {
                      ref
                          .read(textScaleProvider.notifier)
                          .setScale(selected);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Pratinjau: Pastikan suhu penyimpanan sampel makanan selalu terjaga di bawah 5 C selama 48 jam.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Sinkronisasi & Operasional',
                    style: AppTypography.titleSection,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LacakSectionSurface.separated(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isOffline
                                      ? Icons.cloud_off_rounded
                                      : Icons.cloud_done_rounded,
                                  size: 22,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    isOffline
                                        ? 'Mode Tanpa Sinyal'
                                        : 'Terhubung ke Server',
                                    style: AppTypography.titleItem,
                                  ),
                                ),
                                Text(
                                  '$pendingCount antrean',
                                  style: AppTypography.tabular(
                                    AppTypography.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            LacakSecondaryButton(
                              label: 'Sinkronkan & Perbarui Sekarang',
                              icon: Icons.sync_rounded,
                              isLoading:
                                  syncState.isSyncing ||
                                  authState.busyAction ==
                                      AuthBusyAction.refreshStatus,
                              onPressed: anyBusy
                                  ? null
                                  : () async {
                                      final report = await ref
                                          .read(
                                            offlineSyncControllerProvider
                                                .notifier,
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                  icon: const Icon(
                                    Icons.list_alt_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Lihat Rincian $pendingCount Data Belum Terkirim',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (school != null) ...[
                        _SettingsRow(
                          label: 'WhatsApp Puskesmas',
                          value: school.formattedPuskesmasWa,
                          tabular: true,
                        ),
                        _SettingsRow(
                          label: 'Kode Wilayah Kelurahan',
                          value: school.adm4Code,
                          tabular: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: LacakSecondaryButton(
                            label: 'Ubah WA Puskesmas & Wilayah',
                            icon: Icons.edit_rounded,
                            isLoading:
                                authState.busyAction ==
                                AuthBusyAction.updateSchoolSettings,
                            onPressed: anyBusy
                                ? null
                                : () => _editSchoolSettings(
                                    context,
                                    ref,
                                    school,
                                  ),
                          ),
                        ),
                      ],
                      if (kitchen != null) ...[
                        _SettingsRow(
                          label: 'Kode Wilayah Kelurahan',
                          value: kitchen.adm4Code,
                          tabular: true,
                        ),
                        _SettingsRow(
                          label: 'Koordinat Dapur',
                          value:
                              '${kitchen.lat.toStringAsFixed(5)}, ${kitchen.lng.toStringAsFixed(5)}',
                          tabular: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: LacakSecondaryButton(
                            label: 'Perbarui Lokasi GPS Dapur',
                            icon: Icons.location_on_rounded,
                            isLoading:
                                authState.busyAction ==
                                AuthBusyAction.updateKitchenLocation,
                            onPressed: anyBusy
                                ? null
                                : () => _updateKitchenGps(
                                    context,
                                    ref,
                                    kitchen,
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LacakDangerButton(
                    label: 'Keluar Akun',
                    icon: Icons.logout_rounded,
                    isLoading: authState.busyAction == AuthBusyAction.signOut,
                    onPressed: anyBusy
                        ? null
                        : () => _confirmSignOut(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    textAlign: TextAlign.center,
                    style: AppTypography.tabular(
                      AppTypography.labelTag.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
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
              style: tabular
                  ? AppTypography.tabular(AppTypography.titleItem)
                  : AppTypography.titleItem,
            ),
          ),
        ],
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

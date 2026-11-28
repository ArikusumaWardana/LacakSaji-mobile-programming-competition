import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/widgets/location_helper.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../../kitchen/presentation/kitchen_providers.dart';
import '../../school/domain/danger_zone_calculator.dart';
import '../../traceability/domain/traceability_models.dart';
import '../../traceability/presentation/traceability_providers.dart';

typedef CourierQrScannerViewBuilder =
    Widget Function(
      BuildContext context,
      bool torchEnabled,
      void Function(String rawQr) onDetected,
    );

final courierQrScannerViewBuilderProvider =
    Provider<CourierQrScannerViewBuilder>((ref) {
      return (context, torchEnabled, onDetected) => _LiveCourierScannerView(
        torchEnabled: torchEnabled,
        onDetected: onDetected,
      );
    });

/// K02: Courier load-at-kitchen & arrive-at-school QR seal scanner.
class CourierScanScreen extends ConsumerStatefulWidget {
  const CourierScanScreen({super.key, this.initialMode});

  final CourierScanMode? initialMode;

  @override
  ConsumerState<CourierScanScreen> createState() => _CourierScanScreenState();
}

class _CourierScanScreenState extends ConsumerState<CourierScanScreen> {
  late CourierScanMode _mode;
  bool _torchEnabled = false;
  bool _includeGps = false;
  bool _busy = false;
  bool _showSpinner = false;
  List<PartnerSchoolItem> _schools = const [];
  PartnerSchoolItem? _selectedSchool;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode ?? CourierScanMode.loadAtKitchen;
    Future.microtask(_loadPartnerSchoolsBestEffort);
  }

  Future<void> _loadPartnerSchoolsBestEffort() async {
    final kitchen = ref.read(authControllerProvider).kitchen;
    if (kitchen == null) {
      return;
    }
    try {
      final list = await ref
          .read(kitchenRepositoryProvider)
          .fetchPartnerSchools(sppgId: kitchen.id);
      if (mounted) {
        setState(() {
          _schools = list
              .where(
                (s) => s.verificationStatus == SchoolVerificationStatus.approved,
              )
              .toList(growable: false);
        });
      }
    } catch (_) {
      // Optional list; offline courier scans still succeed without selecting school.
    }
  }

  Future<void> _handleDetectedQr(String rawQr) async {
    if (_busy || rawQr.trim().isEmpty) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    final kitchen = auth.kitchen;
    final actor = auth.profile;
    if (kitchen == null || actor == null) {
      return;
    }

    setState(() {
      _busy = true;
      _showSpinner = true;
    });
    unawaited(HapticFeedback.mediumImpact().catchError((_) {}));

    final parsed = BatchQrPayload.tryParse(rawQr.trim());
    if (parsed == null) {
      if (mounted) {
        setState(() => _showSpinner = false);
      }
      await _showResultSheet(
        isError: true,
        title: 'QR Segel Tidak Dikenali',
        message:
            'Pastikan kamera mengarah ke QR Segel LacakSaji yang tercetak di wadah atau Surat Jalan Digital.',
      );
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }

    double? lat;
    double? lng;
    if (_includeGps) {
      final gps = await captureDeviceCoordinates();
      if (gps.success) {
        lat = gps.lat;
        lng = gps.lng;
      }
    }

    final isOffline = ref.read(isOfflineProvider).value ?? false;
    try {
      final recorded = await ref
          .read(traceabilityRepositoryProvider)
          .recordCourierScan(
            kitchen: kitchen,
            actor: actor,
            qrPayload: parsed,
            mode: _mode,
            isOffline: isOffline,
            schoolId: _mode == CourierScanMode.arriveAtSchool
                ? _selectedSchool?.id
                : null,
            schoolName: _mode == CourierScanMode.arriveAtSchool
                ? _selectedSchool?.name
                : null,
            lat: lat,
            lng: lng,
          );
      invalidateTraceabilityProviders(ref);
      if (!mounted) {
        return;
      }
      setState(() => _showSpinner = false);
      final transitMin = recorded.transitDurationMinutes;
      final timestampText = _mode == CourierScanMode.loadAtKitchen
          ? formatWibDateTime(recorded.effectiveDepartedAtUtc)
          : formatWibDateTime(recorded.arrivedAtUtc ?? recorded.loadedAtUtc);

      final details = <String>[
        'Batch: ${parsed.menuName} (${parsed.batchCode})',
        'Waktu terkunci: $timestampText',
        if (_mode == CourierScanMode.arriveAtSchool && transitMin != null)
          'Durasi transit jalan: ${formatDurationMinutes(transitMin)}',
        if (lat != null && lng != null)
          'Koordinat GPS: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        recorded.isPendingSync
            ? 'Tersimpan offline di HP dan akan otomatis terkirim saat ada sinyal.'
            : 'Tersinkronisasi ke server SPPG.',
      ].join('\n');

      await _showResultSheet(
        isError: false,
        title: _mode == CourierScanMode.loadAtKitchen
            ? 'Muat Batch Berhasil Dicatat'
            : 'Kedatangan di Sekolah Dicatat',
        message: details,
      );
      if (mounted) {
        context.pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _showSpinner = false);
      await _showResultSheet(
        isError: true,
        title: 'Gagal Mencatat Pindai Kurir',
        message: error.toString().replaceFirst('FormatException: ', ''),
      );
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showResultSheet({
    required bool isError,
    required String title,
    required String message,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCanvas,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusHero),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LacakStatusBanner(
                  level: isError ? LacakStatusLevel.danger : LacakStatusLevel.safe,
                  title: title,
                  description: message,
                ),
                const SizedBox(height: AppSpacing.lg),
                LacakPrimaryButton(
                  label: isError ? 'Coba Lagi' : 'Selesai',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openManualDialog() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualCourierQrDialog(),
    );
    if (raw != null && raw.trim().isNotEmpty && mounted) {
      await _handleDetectedQr(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(authControllerProvider).kitchen;
    final scannerBuilder = ref.watch(courierQrScannerViewBuilderProvider);
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = AppSpacing.horizontalPadding(size.width);
    final maxWidth = AppSpacing.maxContentWidth(size.width);
    final frameSize = AppSpacing.adaptiveQrSize(size.width, size.height);

    if (kitchen == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: LacakErrorState(message: 'SPPG mitra belum dimuat.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                scannerBuilder(context, _torchEnabled, _handleDetectedQr),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: frameSize,
                      height: frameSize,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.surfaceBase,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusHero,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CircleOverlayButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            tooltip: 'Kembali',
                            onTap: () => context.pop(),
                          ),
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.scrimPill,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _mode.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelTag.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          _CircleOverlayButton(
                            icon: _torchEnabled
                                ? Icons.flashlight_off_rounded
                                : Icons.flashlight_on_rounded,
                            tooltip: _torchEnabled
                                ? 'Matikan Senter'
                                : 'Nyalakan Senter',
                            onTap: () => setState(
                              () => _torchEnabled = !_torchEnabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showSpinner)
                  Container(
                    color: AppColors.textPrimary.withValues(alpha: 0.72),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.surfaceBase,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.surfaceBase,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusHero),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  AppSpacing.md,
                  horizontalPad,
                  AppSpacing.lg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilterChipStrip<CourierScanMode>(
                          padding: EdgeInsets.zero,
                          selectedValue: _mode,
                          onSelected: (next) => setState(() => _mode = next),
                          items: CourierScanMode.values
                              .map(
                                (mode) => FilterChipItem(
                                  value: mode,
                                  label: mode.label,
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _mode.subtitle,
                          style: AppTypography.captionMuted,
                        ),
                        if (_mode == CourierScanMode.arriveAtSchool &&
                            _schools.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedSchool?.id,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Sekolah tujuan (opsional)',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 10,
                              ),
                            ),
                            items: _schools
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (id) {
                              setState(() {
                                _selectedSchool = _schools
                                    .where((s) => s.id == id)
                                    .firstOrNull;
                              });
                            },
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.primary,
                          title: Text(
                            'Catat Lokasi GPS Opsional',
                            style: AppTypography.labelTag.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: _includeGps,
                          onChanged: (v) => setState(() => _includeGps = v),
                        ),
                        LacakSecondaryButton(
                          label: 'Input Kode QR Manual',
                          icon: Icons.keyboard_rounded,
                          onPressed: _busy ? null : _openManualDialog,
                        ),
                      ],
                    ),
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

class _CircleOverlayButton extends StatelessWidget {
  const _CircleOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scrimPill,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        icon: Icon(icon, size: 22, color: AppColors.onPrimary),
      ),
    );
  }
}

class _LiveCourierScannerView extends StatefulWidget {
  const _LiveCourierScannerView({
    required this.torchEnabled,
    required this.onDetected,
  });

  final bool torchEnabled;
  final void Function(String rawQr) onDetected;

  @override
  State<_LiveCourierScannerView> createState() =>
      _LiveCourierScannerViewState();
}

class _LiveCourierScannerViewState extends State<_LiveCourierScannerView> {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void didUpdateWidget(covariant _LiveCourierScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.torchEnabled != widget.torchEnabled) {
      unawaited(_controller.toggleTorch().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        final rawValue = capture.barcodes.firstOrNull?.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          widget.onDetected(rawValue);
        }
      },
    );
  }
}

class _ManualCourierQrDialog extends StatefulWidget {
  const _ManualCourierQrDialog();

  @override
  State<_ManualCourierQrDialog> createState() => _ManualCourierQrDialogState();
}

class _ManualCourierQrDialogState extends State<_ManualCourierQrDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Input Payload QR Segel'),
      content: LacakTextField(
        label: 'JSON Payload QR',
        controller: _controller,
        hintText: 'Tempel JSON QR Segel di sini',
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        LacakPrimaryButton(
          label: 'Proses QR',
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}

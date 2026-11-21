import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../../core/widgets/lacak_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/school_models.dart';
import 'school_providers.dart';

typedef QrScannerViewBuilder =
    Widget Function(
      BuildContext context,
      bool torchEnabled,
      void Function(String rawQr) onDetected,
    );

final qrScannerViewBuilderProvider = Provider<QrScannerViewBuilder>((ref) {
  return (context, torchEnabled, onDetected) => _LiveMobileScannerView(
    torchEnabled: torchEnabled,
    onDetected: onDetected,
  );
});

/// G02: Full-screen QR seal scanner verifying Ed25519 cryptographic signature 100% offline.
class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  bool _torchEnabled = false;
  bool _busy = false;
  bool _showSpinner = false;

  Future<void> _handleDetectedQr(String rawQr) async {
    if (_busy || rawQr.trim().isEmpty) {
      return;
    }

    final school = ref.read(authControllerProvider).school;
    if (school == null) {
      return;
    }

    setState(() {
      _busy = true;
      _showSpinner = true;
    });
    unawaited(HapticFeedback.mediumImpact().catchError((_) {}));

    final isOffline = ref.read(isOfflineProvider).value ?? false;
    late final QrVerificationResult result;
    try {
      result = await ref
          .read(schoolRepositoryProvider)
          .verifyQrPayloadOffline(
            rawQrText: rawQr,
            school: school,
            isOffline: isOffline,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _showSpinner = false);
      await _showVerificationErrorSheet(
        title: 'Gagal Memverifikasi QR',
        message: 'Terjadi kesalahan saat memeriksa segel QR: $error',
      );
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _showSpinner = false);

    if (result.isValid && result.context != null) {
      context.pushReplacement(AppRoutes.schoolDangerGate, extra: result.context);
      return;
    }

    await _showVerificationErrorSheet(
      title: result.errorTitle ?? 'QR Segel Tidak Valid',
      message:
          result.errorMessage ??
          'Kode QR tidak dapat diverifikasi oleh sekolah ini.',
    );

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _showVerificationErrorSheet({
    required String title,
    required String message,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.tabletFormMaxWidth,
      ),
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSurface),
        ),
        side: BorderSide(color: AppColors.borderHairline, width: 1),
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
                  level: LacakStatusLevel.danger,
                  title: title,
                  description: message,
                ),
                const SizedBox(height: AppSpacing.lg),
                LacakPrimaryButton(
                  label: 'Pindai Ulang QR',
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openManualQrDialog() async {
    final submitted = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualQrInputDialog(),
    );

    if (submitted != null && submitted.isNotEmpty && mounted) {
      await _handleDetectedQr(submitted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(authControllerProvider).school;
    final scannerBuilder = ref.watch(qrScannerViewBuilderProvider);
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);
    final frameSize = AppSpacing.adaptiveQrSize(width, size.height);

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        title: const Text('Pindai QR Segel Batch'),
      ),
      body: SafeArea(
        child: school == null
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: LacakErrorState(
                      message: 'Profil sekolah belum dimuat.',
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        scannerBuilder(
                          context,
                          _torchEnabled,
                          _handleDetectedQr,
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: frameSize,
                              height: frameSize,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.surfaceBase,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_showSpinner)
                          Container(
                            color: AppColors.textPrimary.withValues(alpha: 0.72),
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.all(AppSpacing.xl),
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBase,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSurface,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'Memverifikasi Segel Digital & Cuaca...',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.titleItem,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: AppColors.surfaceBase,
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
                            Text(
                              'Arahkan kamera ke Kode QR pada HP Kurir atau label wadah makanan.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final textScaler =
                                    MediaQuery.textScalerOf(context);
                                final stack = constraints.maxWidth < 310 ||
                                    textScaler.scale(16) > 19.5;
                                final torchBtn = LacakSecondaryButton(
                                  label: _torchEnabled
                                      ? 'Matikan Senter'
                                      : 'Lampu Senter',
                                  icon: Icons.flashlight_on_rounded,
                                  onPressed: () => setState(
                                    () => _torchEnabled = !_torchEnabled,
                                  ),
                                );
                                final closeBtn = LacakSecondaryButton(
                                  label: 'Tutup',
                                  icon: Icons.close_rounded,
                                  onPressed: () => context.pop(),
                                );
                                if (stack) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      torchBtn,
                                      const SizedBox(height: AppSpacing.sm),
                                      closeBtn,
                                    ],
                                  );
                                }
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: torchBtn),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(child: closeBtn),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: _busy ? null : _openManualQrDialog,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(
                                  double.infinity,
                                  AppSpacing.minTouchTarget,
                                ),
                              ),
                              icon:
                                  const Icon(Icons.qr_code_2_rounded, size: 20),
                              label: const Text('Masukkan Kode QR Manual'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LiveMobileScannerView extends StatefulWidget {
  const _LiveMobileScannerView({
    required this.torchEnabled,
    required this.onDetected,
  });

  final bool torchEnabled;
  final void Function(String rawQr) onDetected;

  @override
  State<_LiveMobileScannerView> createState() => _LiveMobileScannerViewState();
}

class _LiveMobileScannerViewState extends State<_LiveMobileScannerView> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void didUpdateWidget(covariant _LiveMobileScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.torchEnabled != widget.torchEnabled) {
      _controller.toggleTorch();
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
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null && value.trim().isNotEmpty) {
            widget.onDetected(value);
            break;
          }
        }
      },
      errorBuilder: (context, error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LacakErrorState(
              title: 'Kamera pemindai belum siap',
              message:
                  'Pastikan izin kamera diberikan, atau gunakan tombol Masukkan Kode QR Manual di bawah.',
              onRetry: () => _controller.start(),
            ),
          ),
        );
      },
    );
  }
}

class _ManualQrInputDialog extends StatefulWidget {
  const _ManualQrInputDialog();

  @override
  State<_ManualQrInputDialog> createState() => _ManualQrInputDialogState();
}

class _ManualQrInputDialogState extends State<_ManualQrInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Masukkan Kode QR Manual'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tempelkan teks isi Kode QR apabila kamera terhalang atau saat uji coba.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            LacakTextField(
              label: 'Teks Isi Kode QR',
              controller: _controller,
              hintText: '{"batch_id":...}',
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
              label: 'Verifikasi Kode QR',
              onPressed: () {
                final value = _controller.text.trim();
                if (value.isNotEmpty) {
                  Navigator.of(context).pop(value);
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

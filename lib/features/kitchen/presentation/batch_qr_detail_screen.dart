import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_logo.dart';
import '../../../core/widgets/lacak_section_surface.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../data/batch_export_service.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';

/// D03: Digital QR Seal Card (Surat Jalan Digital PNG share & printable PDF export).
class BatchQrDetailScreen extends ConsumerStatefulWidget {
  const BatchQrDetailScreen({
    super.key,
    required this.batchId,
    this.initialBatch,
  });

  final String batchId;
  final FoodBatchItem? initialBatch;

  @override
  ConsumerState<BatchQrDetailScreen> createState() =>
      _BatchQrDetailScreenState();
}

class _BatchQrDetailScreenState extends ConsumerState<BatchQrDetailScreen> {
  final GlobalKey _waybillBoundaryKey = GlobalKey();
  bool _sharingPng = false;
  bool _exportingPdf = false;
  Future<String?>? _signedPhotoFuture;
  String? _loadedStoragePath;

  Future<String?> _resolveSignedPhoto(String storagePath) {
    if (_loadedStoragePath != storagePath || _signedPhotoFuture == null) {
      _loadedStoragePath = storagePath;
      _signedPhotoFuture =
          ref.read(kitchenRepositoryProvider).createSignedPhotoUrl(storagePath);
    }
    return _signedPhotoFuture!;
  }

  Future<void> _shareWaybillPng(FoodBatchItem batch) async {
    if (_sharingPng) {
      return;
    }
    setState(() => _sharingPng = true);
    try {
      final pngBytes =
          await ref.read(waybillPngCapturerProvider)(_waybillBoundaryKey);

      await ref.read(batchExportServiceProvider).shareDigitalWaybillPng(
            batch: batch,
            pngBytes: pngBytes,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kartu Surat Jalan Digital ${batch.batchCode} siap dibagikan ke kurir.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Belum dapat membagikan gambar: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharingPng = false);
      }
    }
  }

  Future<void> _exportPrintablePdf(FoodBatchItem batch) async {
    if (_exportingPdf) {
      return;
    }
    setState(() => _exportingPdf = true);
    try {
      await ref
          .read(batchExportServiceProvider)
          .exportAndSharePrintableLabelPdf(batch);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Label cetak PDF ${batch.batchCode} berhasil dibuat.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor label PDF: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = AppSpacing.horizontalPadding(width);
    final maxWidth = AppSpacing.maxContentWidth(width);
    final qrSize = AppSpacing.adaptiveQrSize(width);

    final initial = widget.initialBatch;
    final AsyncValue<FoodBatchItem?> batchAsync = initial != null
        ? AsyncValue.data(initial)
        : ref.watch(kitchenBatchDetailProvider(widget.batchId));

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(title: const Text('Kartu QR Segel & Surat Jalan')),
      body: SafeArea(
        child: batchAsync.when(
          loading: () => Padding(
            padding: EdgeInsets.all(horizontalPad),
            child: const LacakSkeletonList(
              itemCount: 3,
              loadingLabel: 'Memuat kartu segel digital...',
            ),
          ),
          error: (error, _) => Padding(
            padding: EdgeInsets.all(horizontalPad),
            child: LacakErrorState(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(kitchenBatchDetailProvider(widget.batchId)),
            ),
          ),
          data: (batch) {
            if (batch == null) {
              return Padding(
                padding: EdgeInsets.all(horizontalPad),
                child: const LacakErrorState(
                  title: 'Data batch tidak ditemukan',
                  message:
                      'Batch ini belum tersedia atau tidak termasuk dalam dapur Anda.',
                ),
              );
            }

            return SingleChildScrollView(
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
                      if (batch.isPendingSync) ...[
                        const LacakStatusBanner(
                          level: LacakStatusLevel.offline,
                          title: 'Batch Disimpan di HP (Belum Terkirim)',
                          description:
                              'QR Segel sudah aktif dan dapat langsung dipindai oleh sekolah meski tanpa sinyal. Foto dan catatan akan otomatis terkirim saat online.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      RepaintBoundary(
                        key: _waybillBoundaryKey,
                        child: Container(
                          color: AppColors.bgCanvas,
                          child: LacakSectionSurface(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final textScaler =
                                        MediaQuery.textScalerOf(context);
                                    final compactHeader =
                                        constraints.maxWidth < 290 ||
                                        textScaler.scale(14) > 17.5;
                                    final brandGroup = Row(
                                      mainAxisSize: compactHeader
                                          ? MainAxisSize.max
                                          : MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const LacakLogoMark(size: 28),
                                        const SizedBox(width: AppSpacing.sm),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'SURAT JALAN DIGITAL',
                                                style: AppTypography.captionLegal
                                                    .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              Text(
                                                batch.sppgName,
                                                style: AppTypography.titleItem,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                    const verifiedTag = LacakStatusTag(
                                      level: LacakStatusLevel.safe,
                                      label: 'TERVERIFIKASI',
                                      icon: Icons.verified_user_rounded,
                                    );
                                    if (compactHeader) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          brandGroup,
                                          const SizedBox(height: AppSpacing.sm),
                                          verifiedTag,
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(child: brandGroup),
                                        const SizedBox(width: AppSpacing.sm),
                                        verifiedTag,
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                const Divider(height: 1),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'KODE BATCH PENGIRIMAN',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.captionLegal.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  batch.batchCode,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.tabular(
                                    AppTypography.displayStatus,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.lg,
                                    ),
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
                                      data: batch.qrPayloadJson,
                                      version: QrVersions.auto,
                                      errorCorrectionLevel:
                                          QrErrorCorrectLevel.M,
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
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(height: 1),
                                _WaybillDetailRow(
                                  label: 'Menu Makanan',
                                  value: batch.menuName,
                                ),
                                const Divider(height: 1),
                                _WaybillDetailRow(
                                  label: 'Kategori Risiko',
                                  value: batch.riskCategory.label,
                                ),
                                const Divider(height: 1),
                                _WaybillDetailRow(
                                  label: 'Jumlah Porsi',
                                  value: '${batch.portionCount} porsi',
                                  tabular: true,
                                ),
                                const Divider(height: 1),
                                _WaybillDetailRow(
                                  label: 'Jam Segel',
                                  value: formatWibDateTime(batch.sealedAtUtc),
                                  tabular: true,
                                ),
                                const Divider(height: 1),
                                _WaybillDetailRow(
                                  label: 'Status Waktu',
                                  value: batch.timestampSource.label,
                                ),
                                const Divider(height: 1),
                                const _WaybillDetailRow(
                                  label: 'Keamanan Segel',
                                  value: 'Segel Digital Asli',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LacakPrimaryButton(
                        label: 'Bagikan ke WhatsApp Kurir (Gambar)',
                        icon: Icons.share_rounded,
                        isLoading: _sharingPng,
                        onPressed: () => _shareWaybillPng(batch),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LacakSecondaryButton(
                        label: 'Simpan Label Siap Cetak (PDF)',
                        icon: Icons.picture_as_pdf_rounded,
                        isLoading: _exportingPdf,
                        onPressed: () => _exportPrintablePdf(batch),
                      ),
                      if (batch.localPhotoPath != null ||
                          batch.packagingPhotoUrl != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Dokumentasi Pengemasan (Kamera Langsung)',
                          style: AppTypography.titleSection,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LacakSectionSurface(
                          padding: EdgeInsets.zero,
                          child: _BatchPhotoPreview(
                            localPhotoPath: batch.localPhotoPath,
                            storagePath: batch.packagingPhotoUrl,
                            resolveSignedUrl: _resolveSignedPhoto,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaybillDetailRow extends StatelessWidget {
  const _WaybillDetailRow({
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTypography.captionLegal.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.left,
            style: tabular
                ? AppTypography.tabular(AppTypography.titleItem)
                : AppTypography.titleItem,
          ),
        ],
      ),
    );
  }
}

class _BatchPhotoPreview extends StatelessWidget {
  const _BatchPhotoPreview({
    required this.localPhotoPath,
    required this.storagePath,
    required this.resolveSignedUrl,
  });

  final String? localPhotoPath;
  final String? storagePath;
  final Future<String?> Function(String path) resolveSignedUrl;

  Widget _buildPhotoLoader({double? progress}) {
    return Container(
      height: 200,
      width: double.infinity,
      color: AppColors.surfaceSubtle,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              color: AppColors.primary,
              backgroundColor: AppColors.borderHairline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Memuat foto dokumentasi pengemasan...',
            textAlign: TextAlign.center,
            style: AppTypography.labelTag.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (localPhotoPath != null && File(localPhotoPath!).existsSync()) {
      return Image.file(
        File(localPhotoPath!),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Foto pengemasan lokal telah diamankan.',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }

    if (storagePath == null || storagePath!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: resolveSignedUrl(storagePath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPhotoLoader();
        }
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Foto pengemasan tersimpan di penyimpanan aman Dapur SPPG.',
              style: AppTypography.bodyMedium,
            ),
          );
        }
        return Image.network(
          url,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            final expected = loadingProgress.expectedTotalBytes;
            final progress = (expected != null && expected > 0)
                ? loadingProgress.cumulativeBytesLoaded / expected
                : null;
            return _buildPhotoLoader(progress: progress);
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 220),
                child: child,
              );
            }
            return _buildPhotoLoader();
          },
          errorBuilder: (_, _, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Pratinjau foto tidak tersedia saat tanpa sinyal.',
              style: AppTypography.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/editorial_widgets.dart';
import '../../../core/widgets/lacak_buttons.dart';
import '../../../core/widgets/lacak_feedback_states.dart';
import '../../../core/widgets/lacak_logo.dart';
import '../../../core/widgets/lacak_status_badge.dart';
import '../../traceability/domain/traceability_models.dart';
import '../../traceability/presentation/traceability_providers.dart';
import '../../traceability/presentation/widgets/supply_chain_timeline.dart';
import '../data/batch_export_service.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_providers.dart';
import 'widgets/kitchen_photo_builder.dart';

/// D03: Editorial Digital QR Seal Card with FramedHeroHeader, 20dp framed waybill card,
/// and StickyBottomActionBar WhatsApp PNG dispatch.
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
      body: batchAsync.when(
        loading: () => SafeArea(
          child: Padding(
            padding: EdgeInsets.all(horizontalPad),
            child: const LacakSkeletonList(
              itemCount: 3,
              loadingLabel: 'Memuat kartu segel digital...',
            ),
          ),
        ),
        error: (error, _) => SafeArea(
          child: Padding(
            padding: EdgeInsets.all(horizontalPad),
            child: LacakErrorState(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(kitchenBatchDetailProvider(widget.batchId)),
            ),
          ),
        ),
        data: (batch) {
          if (batch == null) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(horizontalPad),
                child: const LacakErrorState(
                  title: 'Data batch tidak ditemukan',
                  message:
                      'Batch ini belum tersedia atau tidak termasuk dalam dapur Anda.',
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth == double.infinity
                            ? double.infinity
                            : maxWidth + horizontalPad * 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: KitchenBatchPhotoBuilder(
                                localPhotoPath: batch.localPhotoPath,
                                storagePath: batch.packagingPhotoUrl,
                                builder: (context, imageProvider) {
                                  return FramedHeroHeader(
                                    height: 256,
                                    image: imageProvider,
                                    actionIcon: Icons.picture_as_pdf_rounded,
                                    actionTooltip: 'Simpan Label Cetak (PDF)',
                                    onActionTap: () =>
                                        _exportPrintablePdf(batch),
                                    title: batch.menuName,
                                    subtitle:
                                        '${batch.sppgName} · ${batch.batchCode}',
                                    metrics: [
                                      HeroMetricItem(
                                        icon: Icons.restaurant_rounded,
                                        label: '${batch.portionCount} Porsi',
                                      ),
                                      HeroMetricItem(
                                        icon: Icons.schedule_rounded,
                                        label:
                                            formatWibTime(batch.sealedAtUtc),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPad,
                              AppSpacing.lg,
                              horizontalPad,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (batch.isPendingSync) ...[
                                  const LacakStatusBanner(
                                    level: LacakStatusLevel.offline,
                                    title:
                                        'Batch Disimpan di HP (Belum Terkirim)',
                                    description:
                                        'QR Segel sudah aktif dan dapat langsung dipindai oleh sekolah meski tanpa sinyal.',
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                RepaintBoundary(
                                  key: _waybillBoundaryKey,
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.xl,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBase,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusHero,
                                      ),
                                      border: Border.all(
                                        color: AppColors.borderHairline,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final textScaler =
                                                MediaQuery.textScalerOf(
                                                  context,
                                                );
                                            final compactHeader =
                                                constraints.maxWidth < 290 ||
                                                textScaler.scale(14) > 17.5;
                                            final brandGroup = Row(
                                              mainAxisSize: compactHeader
                                                  ? MainAxisSize.max
                                                  : MainAxisSize.min,
                                              children: [
                                                const LacakLogoMark(size: 28),
                                                const SizedBox(
                                                  width: AppSpacing.sm,
                                                ),
                                                Flexible(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'SURAT JALAN DIGITAL',
                                                        style: AppTypography
                                                            .captionLegal
                                                            .copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.4,
                                                        ),
                                                      ),
                                                      Text(
                                                        batch.sppgName,
                                                        style: AppTypography
                                                            .titleItem,
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
                                                  const SizedBox(
                                                    height: AppSpacing.sm,
                                                  ),
                                                  verifiedTag,
                                                ],
                                              );
                                            }
                                            return Row(
                                              children: [
                                                Expanded(child: brandGroup),
                                                const SizedBox(
                                                  width: AppSpacing.sm,
                                                ),
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
                                          style: AppTypography.captionLegal
                                              .copyWith(
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
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppSpacing.radiusSurface,
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
                                              backgroundColor:
                                                  AppColors.surfaceBase,
                                              eyeStyle: const QrEyeStyle(
                                                eyeShape: QrEyeShape.square,
                                                color: AppColors.textPrimary,
                                              ),
                                              dataModuleStyle:
                                                  const QrDataModuleStyle(
                                                dataModuleShape:
                                                    QrDataModuleShape.square,
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
                                          value: formatWibDateTime(
                                            batch.sealedAtUtc,
                                          ),
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
                                const SizedBox(height: AppSpacing.lg),
                                LacakSecondaryButton(
                                  label: 'Simpan Label Siap Cetak (PDF)',
                                  icon: Icons.picture_as_pdf_rounded,
                                  isLoading: _exportingPdf,
                                  onPressed: () => _exportPrintablePdf(batch),
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                _BatchTraceabilitySections(batch: batch),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              StickyBottomActionBar(
                summaryLabel: 'Kode Segel Digital',
                summaryValue: batch.batchCode,
                ctaLabel: 'Bagikan WA Kurir',
                ctaIcon: Icons.share_rounded,
                isLoading: _sharingPng,
                onCtaPressed: () => _shareWaybillPng(batch),
              ),
            ],
          );
        },
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
            style: tabular
                ? AppTypography.tabular(AppTypography.titleItem)
                : AppTypography.titleItem,
          ),
        ],
      ),
    );
  }
}

class _BatchTraceabilitySections extends ConsumerWidget {
  const _BatchTraceabilitySections({required this.batch});

  final FoodBatchItem batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(
      batchSupplyChainTimelineProvider((
        sppgId: batch.sppgId,
        batchId: batch.id,
        sealedAtUtc: batch.sealedAtUtc,
        schoolScannedAtUtc: null,
      )),
    );
    final ingredientsAsync = ref.watch(
      batchIngredientLogsProvider((sppgId: batch.sppgId, batchId: batch.id)),
    );

    final fallbackTimeline = SupplyChainTimelineData(
      batchId: batch.id,
      sealedAtUtc: batch.sealedAtUtc,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SupplyChainTimeline(
          timeline: timelineAsync.value ?? fallbackTimeline,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: Text(
                'Hulu Bahan Baku Tertaut',
                style: AppTypography.titleSection,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.kitchenIngredients),
              child: const Text('Kelola'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ingredientsAsync.when(
          loading: () => Text(
            'Memuat catatan pemasok bahan...',
            style: AppTypography.bodyMedium,
          ),
          error: (_, _) => Text(
            'Catatan bahan baku belum dapat dimuat.',
            style: AppTypography.bodyMedium,
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
                ),
                child: Text(
                  'Belum ada catatan pemasok bahan baku untuk batch ini. Buka menu Bahan Baku untuk menautkan lot pemasok.',
                  style: AppTypography.bodyMedium,
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < logs.length; i++)
                  BorderlessThumbTile(
                    title:
                        '${logs[i].ingredientName} · ${logs[i].supplierName}',
                    statusText: 'Exp ${logs[i].formattedExpiryDate}',
                    statusColor: AppColors.primary,
                    fallbackIcon: Icons.inventory_2_rounded,
                    showBottomDivider: i < logs.length - 1,
                    metadata: [
                      BorderlessMetaItem(
                        icon: Icons.qr_code_rounded,
                        label: 'Lot ${logs[i].supplierBatchNo}',
                      ),
                      if (logs[i].isPendingSync)
                        const BorderlessMetaItem(
                          icon: Icons.cloud_off_rounded,
                          label: 'Belum Terkirim',
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

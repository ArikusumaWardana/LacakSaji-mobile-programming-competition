import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/lacak_buttons.dart';
import '../../data/parent_summary_export_service.dart';
import 'parent_daily_summary_card.dart';

class ParentSummaryShareSheet extends ConsumerStatefulWidget {
  const ParentSummaryShareSheet({
    super.key,
    required this.schoolName,
    required this.dateUtc,
    required this.menuName,
    required this.batchCode,
    required this.cookedAtUtc,
    required this.arrivedAtUtc,
    required this.sampleLabelCode,
    this.allergenTags = const [],
    this.localPhotoPath,
  });

  final String schoolName;
  final DateTime dateUtc;
  final String menuName;
  final String batchCode;
  final DateTime cookedAtUtc;
  final DateTime arrivedAtUtc;
  final String sampleLabelCode;
  final List<String> allergenTags;
  final String? localPhotoPath;

  @override
  ConsumerState<ParentSummaryShareSheet> createState() =>
      _ParentSummaryShareSheetState();
}

class _ParentSummaryShareSheetState
    extends ConsumerState<ParentSummaryShareSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _sharePng() async {
    if (_sharing) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final pngBytes = await ref.read(parentSummaryPngCapturerProvider)(
        _boundaryKey,
      );
      await ref
          .read(parentSummaryExportServiceProvider)
          .shareParentSummaryPng(
            schoolName: widget.schoolName,
            dateUtc: widget.dateUtc,
            menuName: widget.menuName,
            batchCode: widget.batchCode,
            cookedAtUtc: widget.cookedAtUtc,
            arrivedAtUtc: widget.arrivedAtUtc,
            sampleLabelCode: widget.sampleLabelCode,
            allergenTags: widget.allergenTags,
            pngBytes: pngBytes,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kartu ringkasan ${widget.batchCode} siap dibagikan ke Wali Murid.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Belum dapat membagikan gambar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pratinjau Kartu Wali Murid',
                          style: AppTypography.titleSection,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bebas data pribadi pelapor & nomor telepon.',
                          style: AppTypography.captionMuted,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _sharing
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'Tutup',
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: ParentDailySummaryCard(
                          schoolName: widget.schoolName,
                          dateUtc: widget.dateUtc,
                          menuName: widget.menuName,
                          batchCode: widget.batchCode,
                          cookedAtUtc: widget.cookedAtUtc,
                          arrivedAtUtc: widget.arrivedAtUtc,
                          sampleLabelCode: widget.sampleLabelCode,
                          allergenTags: widget.allergenTags,
                          localPhotoPath: widget.localPhotoPath,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LacakPrimaryButton(
                label: 'Bagikan PNG ke Wali Murid',
                icon: Icons.share_rounded,
                isLoading: _sharing,
                onPressed: _sharePng,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

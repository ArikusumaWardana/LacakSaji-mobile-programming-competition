import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/lacak_logo.dart';
import '../../../../core/widgets/lacak_status_badge.dart';
import '../../../allergens/domain/allergen_models.dart';
import '../../../kitchen/domain/kitchen_models.dart';

/// Editorial shareable summary card for parents and school committees.
/// Intentionally excludes phone numbers, reporter identities, and internal KLB logs.
class ParentDailySummaryCard extends StatelessWidget {
  const ParentDailySummaryCard({
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

  String _allergenSummary() {
    if (allergenTags.isEmpty) {
      return 'Tidak ada alergen utama (telur, susu, ikan, kacang, kedelai, gluten) yang ditandai.';
    }
    return allergenTags.map(AllergenTag.displayLabelFor).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        localPhotoPath != null &&
        localPhotoPath!.isNotEmpty &&
        File(localPhotoPath!).existsSync();

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: AppColors.bgCanvas,
        borderRadius: BorderRadius.circular(AppSpacing.radiusHero),
        border: Border.all(color: AppColors.borderHairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const LacakLogoMark(size: 32, inverted: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RINGKASAN HARIAN MAKANAN SEKOLAH',
                        style: AppTypography.captionLegal.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schoolName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleItem.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatIndonesianDate(dateUtc),
                        style: AppTypography.tabular(AppTypography.captionMuted),
                      ),
                    ),
                    const LacakStatusTag(
                      level: LacakStatusLevel.safe,
                      label: 'LULUS CEK VISUAL',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSurface),
                  child: SizedBox(
                    height: 152,
                    child: hasPhoto
                        ? Image.file(
                            File(localPhotoPath!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Container(
                            color: AppColors.primaryTint,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Dokumentasi Sampel Tersimpan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  menuName,
                  style: AppTypography.headlinePage,
                ),
                const SizedBox(height: 2),
                Text(
                  'Kode Menu Harian: $batchCode',
                  style: AppTypography.tabular(AppTypography.captionMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSurface,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryInfoLine(
                        label: 'Jam Masak & Segel',
                        value: formatWibTime(cookedAtUtc),
                      ),
                      const Divider(height: AppSpacing.md),
                      _SummaryInfoLine(
                        label: 'Jam Tiba di Sekolah',
                        value: formatWibTime(arrivedAtUtc),
                      ),
                      const Divider(height: AppSpacing.md),
                      const _SummaryInfoLine(
                        label: 'Pemeriksaan Sekolah',
                        value: 'Lulus Cek Visual & Organoleptik',
                      ),
                      const Divider(height: AppSpacing.md),
                      _SummaryInfoLine(
                        label: 'Bank Sampel 48 Jam',
                        value: 'Tersimpan ($sampleLabelCode)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: allergenTags.isEmpty
                        ? AppColors.safeBg
                        : AppColors.warnBg,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSurface,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.health_and_safety_rounded,
                        size: 20,
                        color: allergenTags.isEmpty
                            ? AppColors.safeFg
                            : AppColors.warnFg,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Alergen Menu',
                              style: AppTypography.labelTag.copyWith(
                                color: allergenTags.isEmpty
                                    ? AppColors.safeFg
                                    : AppColors.warnFg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _allergenSummary(),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Kartu verifikasi publik orang tua dan komite sekolah. Diterbitkan oleh tim sekolah melalui LacakSaji.',
                  style: AppTypography.captionLegal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryInfoLine extends StatelessWidget {
  const _SummaryInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: AppTypography.captionMuted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.tabular(
              AppTypography.labelTag.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

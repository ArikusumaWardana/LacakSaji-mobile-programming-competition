import 'package:material_ui/material_ui.dart';

import 'package:lacak_saji/core/constants/demo_accounts.dart';
import 'package:lacak_saji/core/theme/app_colors.dart';
import 'package:lacak_saji/core/theme/app_spacing.dart';
import 'package:lacak_saji/core/theme/app_typography.dart';
import 'package:lacak_saji/core/widgets/lacak_section_surface.dart';
import 'package:lacak_saji/core/widgets/lacak_text_field.dart';

/// Bottom sheet allowing quick selection of BMKG `adm4` village codes.
Future<Adm4VillageOption?> showAdm4VillagePicker(BuildContext context) {
  return showModalBottomSheet<Adm4VillageOption>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(
      maxWidth: AppSpacing.tabletFormMaxWidth,
    ),
    backgroundColor: AppColors.bgCanvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusSurface),
      ),
    ),
    builder: (sheetContext) => const _Adm4PickerSheet(),
  );
}

class _Adm4PickerSheet extends StatefulWidget {
  const _Adm4PickerSheet();

  @override
  State<_Adm4PickerSheet> createState() => _Adm4PickerSheetState();
}

class _Adm4PickerSheetState extends State<_Adm4PickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kBanyumasAdm4Options.where((item) {
      if (_query.isEmpty) {
        return true;
      }
      final q = _query.toLowerCase();
      return item.villageName.toLowerCase().contains(q) ||
          item.districtName.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih Wilayah Kelurahan',
                      style: AppTypography.titleSection,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Tutup',
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LacakTextField(
                label: 'Cari Kelurahan atau Kecamatan',
                controller: _searchController,
                hintText: 'Contoh: Grendeng, Sokaraja, 33.02',
                prefixIcon: Icons.search_rounded,
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            'Kelurahan tidak ditemukan. Anda juga dapat mengetik kode wilayah kelurahan langsung di formulir.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: LacakSectionSurface.separated(
                          children: filtered
                              .map(
                                (item) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.xs,
                                  ),
                                  leading: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                  title: Text(
                                    '${item.villageName}, ${item.districtName}',
                                    style: AppTypography.titleItem,
                                  ),
                                  subtitle: Text(
                                    'Kode Wilayah: ${item.code}',
                                    style: AppTypography.tabular(
                                      AppTypography.bodyMedium,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(context).pop(item),
                                ),
                              )
                              .toList(),
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/lacak_buttons.dart';
import '../../../../core/widgets/lacak_status_badge.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/allergen_models.dart';
import '../allergen_providers.dart';

/// Zero-PII Student Allergen Profile editor sheet for C01 School Settings.
class SchoolAllergenProfileSheet extends ConsumerStatefulWidget {
  const SchoolAllergenProfileSheet({
    super.key,
    required this.schoolId,
    required this.initialEntries,
  });

  final String schoolId;
  final List<SchoolAllergenEntry> initialEntries;

  @override
  ConsumerState<SchoolAllergenProfileSheet> createState() =>
      _SchoolAllergenProfileSheetState();
}

class _SchoolAllergenProfileSheetState
    extends ConsumerState<SchoolAllergenProfileSheet> {
  final Map<AllergenTag, bool> _enabled = {};
  final Map<AllergenTag, int> _counts = {};
  final Map<AllergenTag, AllergenSeverity> _severities = {};
  final Map<AllergenTag, String> _ids = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final tag in AllergenTag.values) {
      _enabled[tag] = false;
      _counts[tag] = 1;
      _severities[tag] = AllergenSeverity.moderate;
      _ids[tag] = const Uuid().v4();
    }
    for (final entry in widget.initialEntries) {
      _enabled[entry.allergen] = true;
      _counts[entry.allergen] = entry.studentCount < 1 ? 1 : entry.studentCount;
      _severities[entry.allergen] = entry.severity;
      if (entry.id.isNotEmpty) {
        _ids[entry.allergen] = entry.id;
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final entries = <SchoolAllergenEntry>[];
    for (final tag in AllergenTag.values) {
      if (_enabled[tag] == true) {
        entries.add(
          SchoolAllergenEntry(
            id: _ids[tag] ?? const Uuid().v4(),
            schoolId: widget.schoolId,
            allergen: tag,
            studentCount: _counts[tag] ?? 1,
            severity: _severities[tag] ?? AllergenSeverity.moderate,
          ),
        );
      }
    }

    final isOffline = ref.read(isOfflineProvider).value ?? false;
    final actorId = ref.read(authControllerProvider).profile?.id;
    try {
      await ref
          .read(allergenRepositoryProvider)
          .saveSchoolAllergens(
            schoolId: widget.schoolId,
            entries: entries,
            isOffline: isOffline,
            updatedByUserId: actorId,
          );
      ref.invalidate(schoolAllergensProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan profil alergen: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.86;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight < 620 ? maxSheetHeight : 620,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profil Alergen Siswa',
                      style: AppTypography.titleSection,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    tooltip: 'Tutup',
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LacakStatusBanner(
                        level: LacakStatusLevel.offline,
                        icon: Icons.privacy_tip_rounded,
                        title: 'Privasi Tanpa Nama Siswa',
                        description:
                            'Cukup centang jenis alergen dan jumlah siswa terdampak agar sistem langsung memperingatkan saat QR batch dipindai offline.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (var index = 0;
                          index < AllergenTag.values.length;
                          index++) ...[
                        if (index > 0) const Divider(height: 1),
                        Builder(
                          builder: (context) {
                            final tag = AllergenTag.values[index];
                            final checked = _enabled[tag] ?? false;
                            final count = _counts[tag] ?? 1;
                            final severity =
                                _severities[tag] ?? AllergenSeverity.moderate;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: AppColors.primary,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      tag.label,
                                      style: AppTypography.titleItem.copyWith(
                                        fontWeight: checked
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    value: checked,
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(
                                            () =>
                                                _enabled[tag] = value ?? false,
                                          ),
                                  ),
                                  if (checked) ...[
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSoft,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusSurface,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '$count siswa terdampak',
                                                  style: AppTypography.tabular(
                                                    AppTypography.titleItem,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Kurangi jumlah siswa',
                                                onPressed: _saving || count <= 1
                                                    ? null
                                                    : () => setState(
                                                        () => _counts[tag] =
                                                            count - 1,
                                                      ),
                                                style: IconButton.styleFrom(
                                                  minimumSize: const Size(
                                                    AppSpacing.minTouchTarget,
                                                    AppSpacing.minTouchTarget,
                                                  ),
                                                  backgroundColor:
                                                      AppColors.surfaceBase,
                                                ),
                                                icon: const Icon(
                                                  Icons.remove_rounded,
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              IconButton(
                                                tooltip: 'Tambah jumlah siswa',
                                                onPressed: _saving
                                                    ? null
                                                    : () => setState(
                                                        () => _counts[tag] =
                                                            count + 1,
                                                      ),
                                                style: IconButton.styleFrom(
                                                  minimumSize: const Size(
                                                    AppSpacing.minTouchTarget,
                                                    AppSpacing.minTouchTarget,
                                                  ),
                                                  backgroundColor:
                                                      AppColors.surfaceBase,
                                                ),
                                                icon: const Icon(
                                                  Icons.add_rounded,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Wrap(
                                            spacing: AppSpacing.sm,
                                            children: [
                                              ChoiceChip(
                                                label: const Text('Sedang'),
                                                selected: severity !=
                                                    AllergenSeverity.severe,
                                                onSelected: _saving
                                                    ? null
                                                    : (_) => setState(
                                                        () =>
                                                            _severities[tag] =
                                                                AllergenSeverity
                                                                    .moderate,
                                                      ),
                                              ),
                                              ChoiceChip(
                                                label: const Text('Berat'),
                                                selected: severity ==
                                                    AllergenSeverity.severe,
                                                onSelected: _saving
                                                    ? null
                                                    : (_) => setState(
                                                        () =>
                                                            _severities[tag] =
                                                                AllergenSeverity
                                                                    .severe,
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LacakPrimaryButton(
                label: 'Simpan Profil Alergen',
                icon: Icons.health_and_safety_rounded,
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

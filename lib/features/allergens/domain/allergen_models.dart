import '../../../core/database/app_database.dart';

/// Standardized zero-PII food allergen tags embedded lightly inside offline QR payloads.
enum AllergenTag {
  telur('telur', 'Telur'),
  susuLaktosa('susu_laktosa', 'Susu / Laktosa'),
  ikanSeafood('ikan_seafood', 'Ikan / Seafood'),
  kacang('kacang', 'Kacang'),
  kedelai('kedelai', 'Kedelai / Tahu-Tempe'),
  gluten('gluten', 'Gluten');

  const AllergenTag(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AllergenTag? fromDb(String? raw) {
    if (raw == null) {
      return null;
    }
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty) {
      return null;
    }
    for (final tag in AllergenTag.values) {
      if (tag.dbValue == clean || tag.label.toLowerCase() == clean) {
        return tag;
      }
    }
    if (clean.contains('telur')) return AllergenTag.telur;
    if (clean.contains('susu') || clean.contains('laktosa')) {
      return AllergenTag.susuLaktosa;
    }
    if (clean.contains('ikan') ||
        clean.contains('seafood') ||
        clean.contains('udang')) {
      return AllergenTag.ikanSeafood;
    }
    if (clean.contains('kacang')) return AllergenTag.kacang;
    if (clean.contains('kedelai') ||
        clean.contains('tahu') ||
        clean.contains('tempe') ||
        clean.contains('kecap')) {
      return AllergenTag.kedelai;
    }
    if (clean.contains('gluten') || clean.contains('gandum')) {
      return AllergenTag.gluten;
    }
    return null;
  }

  static List<String> normalizeTags(Iterable<String> rawTags) {
    final normalized = <String>{};
    for (final raw in rawTags) {
      final parsed = fromDb(raw);
      if (parsed != null) {
        normalized.add(parsed.dbValue);
      } else {
        final clean = raw.trim().toLowerCase();
        if (clean.isNotEmpty) {
          normalized.add(clean);
        }
      }
    }
    final sorted = normalized.toList()..sort();
    return List<String>.unmodifiable(sorted);
  }

  static String displayLabelFor(String rawTag) {
    return fromDb(rawTag)?.label ?? rawTag.trim();
  }
}

enum AllergenSeverity {
  mild('mild', 'Ringan'),
  moderate('moderate', 'Sedang'),
  severe('severe', 'Berat / Anafilaksis');

  const AllergenSeverity(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AllergenSeverity fromDb(String? value) {
    for (final s in AllergenSeverity.values) {
      if (s.dbValue == value) {
        return s;
      }
    }
    return AllergenSeverity.moderate;
  }
}

/// Zero-PII school-level allergen count record (no student names stored).
class SchoolAllergenEntry {
  const SchoolAllergenEntry({
    required this.id,
    required this.schoolId,
    required this.allergen,
    required this.studentCount,
    this.severity = AllergenSeverity.moderate,
    this.handlingNote,
    this.updatedAtUtc,
  });

  final String id;
  final String schoolId;
  final AllergenTag allergen;
  final int studentCount;
  final AllergenSeverity severity;
  final String? handlingNote;
  final DateTime? updatedAtUtc;

  Map<String, dynamic> toDbMap({String? updatedByUserId}) {
    return {
      'id': id,
      'school_id': schoolId,
      'allergen_tag': allergen.dbValue,
      'student_count': studentCount < 1 ? 1 : studentCount,
      'severity_level': severity.dbValue,
      if (handlingNote != null && handlingNote!.trim().isNotEmpty)
        'handling_note': handlingNote!.trim(),
      if (updatedByUserId != null && updatedByUserId.isNotEmpty)
        'updated_by': updatedByUserId,
      'updated_at': (updatedAtUtc ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }

  factory SchoolAllergenEntry.fromMap(Map<String, dynamic> map) {
    final parsedTag =
        AllergenTag.fromDb(map['allergen_tag'] as String?) ?? AllergenTag.telur;
    final rawCount = (map['student_count'] as num?)?.toInt() ?? 1;
    return SchoolAllergenEntry(
      id: (map['id'] as String?) ?? '',
      schoolId: (map['school_id'] as String?) ?? '',
      allergen: parsedTag,
      studentCount: rawCount < 1 ? 1 : rawCount,
      severity: AllergenSeverity.fromDb(map['severity_level'] as String?),
      handlingNote: map['handling_note'] as String?,
      updatedAtUtc: DateTime.tryParse('${map['updated_at'] ?? ''}')?.toUtc(),
    );
  }

  factory SchoolAllergenEntry.fromLocalRow(LocalSchoolAllergen row) {
    final parsedTag = AllergenTag.fromDb(row.allergenTag) ?? AllergenTag.telur;
    return SchoolAllergenEntry(
      id: row.id,
      schoolId: row.schoolId,
      allergen: parsedTag,
      studentCount: row.studentCount < 1 ? 1 : row.studentCount,
      severity: AllergenSeverity.fromDb(row.severityLevel),
      handlingNote: row.handlingNote,
      updatedAtUtc: row.updatedAt.toUtc(),
    );
  }
}

class AllergenMatchWarning {
  const AllergenMatchWarning({required this.matchedEntries});

  final List<SchoolAllergenEntry> matchedEntries;

  bool get hasMatches => matchedEntries.isNotEmpty;

  bool get hasSevereMatch =>
      matchedEntries.any((entry) => entry.severity == AllergenSeverity.severe);

  int get totalReportedCases => matchedEntries.fold<int>(
    0,
    (sum, item) => sum + item.studentCount,
  );

  static AllergenMatchWarning intersect({
    required List<String> batchAllergenTags,
    required List<SchoolAllergenEntry> schoolEntries,
  }) {
    if (batchAllergenTags.isEmpty || schoolEntries.isEmpty) {
      return const AllergenMatchWarning(matchedEntries: []);
    }
    final batchSet = AllergenTag.normalizeTags(batchAllergenTags).toSet();
    final matched = schoolEntries
        .where((entry) => batchSet.contains(entry.allergen.dbValue))
        .toList(growable: false);
    return AllergenMatchWarning(matchedEntries: matched);
  }

  String buildSummaryMessage() {
    if (matchedEntries.isEmpty) {
      return '';
    }
    final parts = matchedEntries
        .map((e) => '${e.allergen.label} (${e.studentCount} siswa)')
        .join(', ');
    final severityNote = hasSevereMatch
        ? 'Termasuk profil alergi berat. Wajib awasi ketat dan berikan menu pengganti.'
        : 'Siapkan pengawasan guru dan menu pengganti sebelum pembagian makanan.';
    return 'Menu batch ini mengandung bahan pemicu alergi yang tercatat di sekolah: $parts. $severityNote';
  }
}

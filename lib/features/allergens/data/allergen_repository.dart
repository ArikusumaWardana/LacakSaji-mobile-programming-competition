import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../domain/allergen_models.dart';

abstract class AllergenRepository {
  Future<List<SchoolAllergenEntry>> fetchSchoolAllergens({
    required String schoolId,
    required bool isOffline,
  });

  Future<List<SchoolAllergenEntry>> saveSchoolAllergens({
    required String schoolId,
    required List<SchoolAllergenEntry> entries,
    required bool isOffline,
    String? updatedByUserId,
  });

  Future<int> syncPendingAllergenProfiles({String? schoolId});
}

class SupabaseAllergenRepository implements AllergenRepository {
  SupabaseAllergenRepository({
    required this._client,
    required this._database,
    this._backgroundSyncScheduler,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final SupabaseClient? _client;
  final AppDatabase _database;
  final BackgroundSyncScheduler? _backgroundSyncScheduler;
  final Uuid _uuid;

  @override
  Future<List<SchoolAllergenEntry>> fetchSchoolAllergens({
    required String schoolId,
    required bool isOffline,
  }) async {
    final localRows = await _database.getSchoolAllergens(schoolId);
    final localEntries = localRows
        .map(SchoolAllergenEntry.fromLocalRow)
        .toList(growable: false);

    final client = _client;
    if (isOffline || client == null) {
      return localEntries;
    }

    try {
      final rows = List<Map<String, dynamic>>.from(
        await client
                .from('school_allergen_profiles')
                .select(
                  'id, school_id, allergen_tag, student_count, severity_level, handling_note, updated_at',
                )
                .eq('school_id', schoolId)
                .order('allergen_tag', ascending: true)
            as List,
      );
      final remoteEntries = rows
          .map(SchoolAllergenEntry.fromMap)
          .toList(growable: false);

      final now = DateTime.now().toUtc();
      await _database.replaceSchoolAllergens(
        schoolId: schoolId,
        entries: remoteEntries
            .map(
              (entry) => LocalSchoolAllergensCompanion(
                id: Value(entry.id.isNotEmpty ? entry.id : _uuid.v4()),
                schoolId: Value(schoolId),
                allergenTag: Value(entry.allergen.dbValue),
                studentCount: Value(entry.studentCount),
                severityLevel: Value(entry.severity.dbValue),
                handlingNote: Value(entry.handlingNote),
                updatedAt: Value(entry.updatedAtUtc ?? now),
              ),
            )
            .toList(growable: false),
      );
      return remoteEntries;
    } catch (_) {
      return localEntries;
    }
  }

  @override
  Future<List<SchoolAllergenEntry>> saveSchoolAllergens({
    required String schoolId,
    required List<SchoolAllergenEntry> entries,
    required bool isOffline,
    String? updatedByUserId,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final normalized = <AllergenTag, SchoolAllergenEntry>{};
    for (final entry in entries) {
      normalized[entry.allergen] = SchoolAllergenEntry(
        id: entry.id.isNotEmpty ? entry.id : _uuid.v4(),
        schoolId: schoolId,
        allergen: entry.allergen,
        studentCount: entry.studentCount < 1 ? 1 : entry.studentCount,
        severity: entry.severity,
        handlingNote: entry.handlingNote?.trim(),
        updatedAtUtc: nowUtc,
      );
    }
    final nextList = normalized.values.toList(growable: false)
      ..sort((a, b) => a.allergen.dbValue.compareTo(b.allergen.dbValue));

    await _database.replaceSchoolAllergens(
      schoolId: schoolId,
      entries: nextList
          .map(
            (e) => LocalSchoolAllergensCompanion(
              id: Value(e.id),
              schoolId: Value(schoolId),
              allergenTag: Value(e.allergen.dbValue),
              studentCount: Value(e.studentCount),
              severityLevel: Value(e.severity.dbValue),
              handlingNote: Value(e.handlingNote),
              updatedAt: Value(nowUtc),
            ),
          )
          .toList(growable: false),
    );

    final payloadMap = {
      'school_id': schoolId,
      'entries': nextList
          .map((e) => e.toDbMap(updatedByUserId: updatedByUserId))
          .toList(growable: false),
    };

    var synced = false;
    final client = _client;
    if (!isOffline && client != null) {
      try {
        await _syncSchoolAllergensToRemote(
          client: client,
          schoolId: schoolId,
          entries: nextList,
          updatedByUserId: updatedByUserId,
        );
        synced = true;
      } catch (_) {
        synced = false;
      }
    }

    if (!synced) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion(
          entityId: Value(schoolId),
          operationType: const Value('sync_school_allergens'),
          payloadJson: Value(jsonEncode(payloadMap)),
          localPhotoPathsJson: const Value('[]'),
          createdAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
        ),
      );
      try {
        await _backgroundSyncScheduler?.scheduleImmediateConnectedSync();
      } catch (_) {}
    }

    return nextList;
  }

  Future<void> _syncSchoolAllergensToRemote({
    required SupabaseClient client,
    required String schoolId,
    required List<SchoolAllergenEntry> entries,
    String? updatedByUserId,
  }) async {
    final existingRows = List<Map<String, dynamic>>.from(
      await client
              .from('school_allergen_profiles')
              .select('id, allergen_tag')
              .eq('school_id', schoolId)
          as List,
    );
    final activeTags = entries.map((e) => e.allergen.dbValue).toSet();
    final idsToDelete = existingRows
        .where((r) => !activeTags.contains(r['allergen_tag']))
        .map((r) => r['id'] as String?)
        .whereType<String>()
        .toList(growable: false);

    if (idsToDelete.isNotEmpty) {
      await client
          .from('school_allergen_profiles')
          .delete()
          .inFilter('id', idsToDelete);
    }

    if (entries.isNotEmpty) {
      await client
          .from('school_allergen_profiles')
          .upsert(
            entries
                .map((e) => e.toDbMap(updatedByUserId: updatedByUserId))
                .toList(growable: false),
            onConflict: 'school_id,allergen_tag',
          );
    }
  }

  @override
  Future<int> syncPendingAllergenProfiles({String? schoolId}) async {
    final client = _client;
    if (client == null) {
      return 0;
    }
    final result = await replayDriftSyncQueue(
      database: _database,
      client: client,
      schoolId: schoolId,
      operationTypes: const {'sync_school_allergens'},
    );
    return result.syncedCount;
  }
}

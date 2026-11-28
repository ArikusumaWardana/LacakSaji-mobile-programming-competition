import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/local_bmkg_cache_table.dart';
import 'tables/local_institution_members_table.dart';
import 'tables/local_sample_vaults_table.dart';
import 'tables/local_school_allergens_table.dart';
import 'tables/local_signing_keys_table.dart';
import 'tables/local_sppg_keys_table.dart';
import 'tables/local_sync_queue_table.dart';
import 'tables/local_traceability_drafts_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LocalSppgKeys,
    LocalSigningKeys,
    LocalInstitutionMembers,
    LocalSchoolAllergens,
    LocalTraceabilityDrafts,
    LocalBmkgCache,
    LocalSyncQueue,
    LocalSampleVaults,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(localSigningKeys);
        await m.createTable(localInstitutionMembers);
        await m.createTable(localSchoolAllergens);
        await m.createTable(localTraceabilityDrafts);
        await customStatement(
          "INSERT OR IGNORE INTO local_signing_keys "
          "(key_id, sppg_id, public_key_b64, status, device_label, created_at, updated_at) "
          "SELECT 'legacy-' || substr(replace(sppg_id, '-', ''), 1, 8), "
          "sppg_id, public_key_b64, 'active', 'Perangkat Utama Awal', updated_at, updated_at "
          "FROM local_sppg_keys",
        );
      }
    },
  );

  Future<void> upsertSppgKey(LocalSppgKeysCompanion entry) {
    return into(localSppgKeys).insertOnConflictUpdate(entry);
  }

  Future<LocalSppgKey?> getSppgKey(String sppgId) {
    return (select(
      localSppgKeys,
    )..where((t) => t.sppgId.equals(sppgId))).getSingleOrNull();
  }

  Future<void> upsertSigningKey(LocalSigningKeysCompanion entry) {
    return into(localSigningKeys).insertOnConflictUpdate(entry);
  }

  Future<void> upsertSigningKeys(List<LocalSigningKeysCompanion> entries) {
    if (entries.isEmpty) {
      return Future.value();
    }
    return batch((b) {
      b.insertAllOnConflictUpdate(localSigningKeys, entries);
    });
  }

  Future<LocalSigningKey?> getSigningKeyById(String keyId) {
    return (select(
      localSigningKeys,
    )..where((t) => t.keyId.equals(keyId))).getSingleOrNull();
  }

  Future<List<LocalSigningKey>> getSigningKeysForSppg(String sppgId) {
    return (select(localSigningKeys)
          ..where((t) => t.sppgId.equals(sppgId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<LocalSigningKey?> getActiveSigningKeyForSppg(String sppgId) {
    return (select(localSigningKeys)
          ..where(
            (t) => t.sppgId.equals(sppgId) & t.status.equals('active'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertInstitutionMember(LocalInstitutionMembersCompanion entry) {
    return into(localInstitutionMembers).insertOnConflictUpdate(entry);
  }

  Future<void> replaceInstitutionMembersForScope({
    required String institutionType,
    required String institutionId,
    required List<LocalInstitutionMembersCompanion> entries,
  }) {
    return transaction(() async {
      await (delete(localInstitutionMembers)..where(
            (t) =>
                t.institutionType.equals(institutionType) &
                t.institutionId.equals(institutionId),
          ))
          .go();
      if (entries.isNotEmpty) {
        await batch((b) {
          b.insertAllOnConflictUpdate(localInstitutionMembers, entries);
        });
      }
    });
  }

  Future<List<LocalInstitutionMember>> getInstitutionMembers({
    required String institutionType,
    required String institutionId,
  }) {
    return (select(localInstitutionMembers)
          ..where(
            (t) =>
                t.institutionType.equals(institutionType) &
                t.institutionId.equals(institutionId),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> upsertSchoolAllergen(LocalSchoolAllergensCompanion entry) {
    return into(localSchoolAllergens).insertOnConflictUpdate(entry);
  }

  Future<List<LocalSchoolAllergen>> getSchoolAllergens(String schoolId) {
    return (select(localSchoolAllergens)
          ..where((t) => t.schoolId.equals(schoolId))
          ..orderBy([(t) => OrderingTerm.asc(t.allergenTag)]))
        .get();
  }

  Future<void> replaceSchoolAllergens({
    required String schoolId,
    required List<LocalSchoolAllergensCompanion> entries,
  }) {
    return transaction(() async {
      await (delete(
        localSchoolAllergens,
      )..where((t) => t.schoolId.equals(schoolId))).go();
      if (entries.isNotEmpty) {
        await batch((b) {
          b.insertAllOnConflictUpdate(localSchoolAllergens, entries);
        });
      }
    });
  }

  Future<int> deleteSchoolAllergenById(String id) {
    return (delete(
      localSchoolAllergens,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> upsertTraceabilityDraft(LocalTraceabilityDraftsCompanion entry) {
    return into(localTraceabilityDrafts).insertOnConflictUpdate(entry);
  }

  Future<List<LocalTraceabilityDraft>> getUnsyncedTraceabilityDrafts(
    String institutionId,
  ) {
    return (select(localTraceabilityDrafts)
          ..where(
            (t) =>
                t.institutionId.equals(institutionId) &
                t.isSynced.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<LocalTraceabilityDraft>> getTraceabilityDrafts({
    required String recordType,
    String? institutionId,
    String? batchId,
  }) {
    return (select(localTraceabilityDrafts)
          ..where((t) {
            var expr = t.recordType.equals(recordType);
            if (institutionId != null) {
              expr = expr & t.institutionId.equals(institutionId);
            }
            if (batchId != null) {
              expr = expr & t.batchId.equals(batchId);
            }
            return expr;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<LocalTraceabilityDraft?> getTraceabilityDraftById(String id) {
    return (select(
      localTraceabilityDrafts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> markTraceabilityDraftSynced(String id) {
    return (update(localTraceabilityDrafts)..where((t) => t.id.equals(id)))
        .write(
          LocalTraceabilityDraftsCompanion(
            isSynced: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<int> deleteTraceabilityDraft(String id) {
    return (delete(
      localTraceabilityDrafts,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> upsertBmkgForecasts(List<LocalBmkgCacheCompanion> entries) {
    return batch((b) {
      b.insertAllOnConflictUpdate(localBmkgCache, entries);
    });
  }

  Future<LocalBmkgCacheData?> getNearestBmkgForecast(
    String adm4Code,
    DateTime targetUtc,
  ) async {
    final rows = await (select(localBmkgCache)
          ..where(
            (t) =>
                t.adm4Code.equals(adm4Code) &
                t.expiresAt.isBiggerThanValue(targetUtc),
          ))
        .get();
    if (rows.isEmpty) {
      return null;
    }
    rows.sort((a, b) {
      final diffA = (a.forecastTimeUtc.difference(targetUtc)).abs();
      final diffB = (b.forecastTimeUtc.difference(targetUtc)).abs();
      return diffA.compareTo(diffB);
    });
    return rows.first;
  }

  Future<int> pruneExpiredBmkgCache(DateTime nowUtc) {
    return (delete(
      localBmkgCache,
    )..where((t) => t.expiresAt.isSmallerOrEqualValue(nowUtc))).go();
  }

  Future<int> enqueueSyncItem(LocalSyncQueueCompanion entry) {
    return into(localSyncQueue).insert(entry);
  }

  Stream<int> watchPendingSyncCount() {
    final countExp = localSyncQueue.id.count();
    final query = selectOnly(localSyncQueue)
      ..addColumns([countExp])
      ..where(localSyncQueue.status.isIn(const ['pending', 'failed']));
    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  Future<List<LocalSyncQueueData>> getPendingSyncItems() {
    return (select(localSyncQueue)
          ..where((t) => t.status.isIn(const ['pending', 'failed']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<LocalSyncQueueData>> watchPendingSyncItems() {
    return (select(localSyncQueue)
          ..where((t) => t.status.isIn(const ['pending', 'failed']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<int> deleteSyncItemById(int id) {
    return (delete(localSyncQueue)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteSyncItemsByIds(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value(0);
    }
    return (delete(localSyncQueue)..where((t) => t.id.isIn(ids))).go();
  }

  /// Recovers queue rows left stuck in `syncing` if app closed or skipped mid-sync.
  Future<int> recoverStuckSyncingItems() {
    return (update(localSyncQueue)..where((t) => t.status.equals('syncing')))
        .write(
          LocalSyncQueueCompanion(
            status: const Value('pending'),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<int> updateSyncItemStatus({
    required int id,
    required String status,
    int? retryCount,
    String? lastError,
  }) {
    return (update(localSyncQueue)..where((t) => t.id.equals(id))).write(
      LocalSyncQueueCompanion(
        status: Value(status),
        retryCount: retryCount == null ? const Value.absent() : Value(retryCount),
        lastError: Value(lastError),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> upsertSampleVault(LocalSampleVaultsCompanion entry) {
    return into(localSampleVaults).insertOnConflictUpdate(entry);
  }

  Future<LocalSampleVault?> getSampleVaultByInspection(String inspectionId) {
    return (select(localSampleVaults)
          ..where((t) => t.inspectionId.equals(inspectionId))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<List<LocalSampleVault>> watchActiveSampleVaults(String schoolId) {
    return (select(localSampleVaults)
          ..where(
            (t) => t.schoolId.equals(schoolId) & t.status.equals('active'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.expiresAt)]))
        .watch();
  }

  Stream<List<LocalSampleVault>> watchHistorySampleVaults(String schoolId) {
    return (select(localSampleVaults)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.status.isIn(const ['disposed', 'lab_submitted']),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.storedAt)]))
        .watch();
  }

  Future<int> updateSampleVaultStatus({
    required String id,
    required String status,
    bool? isSynced,
  }) {
    return (update(localSampleVaults)..where((t) => t.id.equals(id))).write(
      LocalSampleVaultsCompanion(
        status: Value(status),
        isSynced: isSynced == null ? const Value.absent() : Value(isSynced),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lacak_saji_offline.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

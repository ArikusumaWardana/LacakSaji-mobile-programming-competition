import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/local_bmkg_cache_table.dart';
import 'tables/local_sample_vaults_table.dart';
import 'tables/local_sppg_keys_table.dart';
import 'tables/local_sync_queue_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LocalSppgKeys,
    LocalBmkgCache,
    LocalSyncQueue,
    LocalSampleVaults,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> upsertSppgKey(LocalSppgKeysCompanion entry) {
    return into(localSppgKeys).insertOnConflictUpdate(entry);
  }

  Future<LocalSppgKey?> getSppgKey(String sppgId) {
    return (select(
      localSppgKeys,
    )..where((t) => t.sppgId.equals(sppgId))).getSingleOrNull();
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

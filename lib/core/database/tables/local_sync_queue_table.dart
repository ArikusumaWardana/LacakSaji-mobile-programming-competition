import 'package:drift/drift.dart';

/// Offline-first sync queue replayed automatically when connectivity returns.
class LocalSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// One of: create_batch, create_inspection, create_sample, create_waste_log, create_alert.
  TextColumn get operationType => text()();

  TextColumn get entityId => text()();

  TextColumn get payloadJson => text()();

  TextColumn get localPhotoPathsJson =>
      text().withDefault(const Constant('[]'))();

  /// One of: pending, syncing, failed.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

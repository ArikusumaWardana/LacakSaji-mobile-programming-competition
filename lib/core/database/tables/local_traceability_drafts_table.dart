import 'package:drift/drift.dart';

/// Offline storage for traceability records (ingredients, transit, tray returns, alert resolutions).
class LocalTraceabilityDrafts extends Table {
  TextColumn get id => text()();

  /// One of: ingredient_log, transit_handover, tray_return, alert_resolution.
  TextColumn get recordType => text()();

  TextColumn get institutionId => text()();

  TextColumn get batchId => text().nullable()();

  TextColumn get payloadJson => text()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

import 'package:drift/drift.dart';

/// Local copy of 2x24h Bank Sampel records keeping countdown and reminders accurate offline.
class LocalSampleVaults extends Table {
  TextColumn get id => text()();

  TextColumn get inspectionId => text()();

  TextColumn get schoolId => text()();

  TextColumn get menuName => text()();

  TextColumn get labelCode => text().unique()();

  DateTimeColumn get storedAt => dateTime()();

  DateTimeColumn get expiresAt => dateTime()();

  /// One of: active, disposed, lab_submitted.
  TextColumn get status => text().withDefault(const Constant('active'))();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

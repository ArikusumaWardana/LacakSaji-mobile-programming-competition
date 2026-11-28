import 'package:drift/drift.dart';

/// Cached Multi-PIC and courier members for SPPG and schools.
class LocalInstitutionMembers extends Table {
  TextColumn get id => text()();

  /// One of: sppg, school.
  TextColumn get institutionType => text()();

  TextColumn get institutionId => text()();

  TextColumn get userId => text().nullable()();

  TextColumn get memberName => text()();

  TextColumn get memberEmail => text()();

  /// One of: admin, staff, courier.
  TextColumn get role => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

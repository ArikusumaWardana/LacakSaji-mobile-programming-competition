import 'package:drift/drift.dart';

/// Cached zero-PII aggregate student allergen profiles per school.
class LocalSchoolAllergens extends Table {
  TextColumn get id => text()();

  TextColumn get schoolId => text()();

  TextColumn get allergenTag => text()();

  IntColumn get studentCount => integer().withDefault(const Constant(1))();

  /// One of: mild, moderate, severe.
  TextColumn get severityLevel =>
      text().withDefault(const Constant('moderate'))();

  TextColumn get handlingNote => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

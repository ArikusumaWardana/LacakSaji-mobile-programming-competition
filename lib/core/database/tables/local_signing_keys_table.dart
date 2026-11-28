import 'package:drift/drift.dart';

/// Cached SPPG Ed25519 signing keys supporting offline rotation and revocation checks.
class LocalSigningKeys extends Table {
  TextColumn get keyId => text()();

  TextColumn get sppgId => text()();

  TextColumn get publicKeyB64 => text()();

  /// One of: active, retired, revoked.
  TextColumn get status => text().withDefault(const Constant('active'))();

  TextColumn get deviceLabel => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get retiredAt => dateTime().nullable()();

  DateTimeColumn get revokedAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {keyId};
}

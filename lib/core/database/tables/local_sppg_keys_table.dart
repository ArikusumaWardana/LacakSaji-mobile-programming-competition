import 'package:drift/drift.dart';

/// Cached SPPG Ed25519 public keys enabling 100% offline QR verification.
class LocalSppgKeys extends Table {
  TextColumn get sppgId => text()();

  TextColumn get sppgName => text()();

  TextColumn get inviteCode => text()();

  TextColumn get publicKeyB64 => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sppgId};
}

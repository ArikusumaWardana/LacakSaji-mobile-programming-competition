import 'package:drift/drift.dart';

/// Cached 3-hourly BMKG forecasts per village `adm4_code` (valid up to 72 hours).
@TableIndex(
  name: 'idx_bmkg_adm4_forecast',
  columns: {#adm4Code, #forecastTimeUtc},
  unique: true,
)
class LocalBmkgCache extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get adm4Code => text()();

  DateTimeColumn get forecastTimeUtc => dateTime()();

  RealColumn get temperatureC => real()();

  IntColumn get humidityPct => integer().nullable()();

  TextColumn get weatherDesc => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();

  DateTimeColumn get expiresAt => dateTime()();
}

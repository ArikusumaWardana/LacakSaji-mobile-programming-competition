import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

enum BmkgSource {
  live('live', 'Data Langsung BMKG'),
  cached('cached', 'Data Tersimpan (Mode Estimasi Offline)'),
  fallbackOffline('fallback_offline', 'Mode Estimasi Offline');

  const BmkgSource(this.dbValue, this.label);

  final String dbValue;
  final String label;
}

class BmkgWeatherReading {
  const BmkgWeatherReading({
    required this.adm4Code,
    required this.temperatureC,
    required this.source,
    required this.observedAtUtc,
    this.humidityPct,
    this.weatherDesc,
  });

  final String adm4Code;
  final double temperatureC;
  final BmkgSource source;
  final DateTime observedAtUtc;
  final int? humidityPct;
  final String? weatherDesc;

  bool get isHot => temperatureC >= AppConstants.hotTemperatureThresholdC;

  String get formattedTemperature => '${temperatureC.toStringAsFixed(1)} C';
}

abstract class BmkgWeatherService {
  Future<BmkgWeatherReading> getCurrentWeather({
    required String adm4Code,
    required bool isOffline,
    bool forceRefresh = false,
  });
}

class DioBmkgWeatherService implements BmkgWeatherService {
  DioBmkgWeatherService({
    required this._database,
    Dio? dio,
    DateTime Function()? clockUtc,
  }) : _clockUtc = clockUtc ?? (() => DateTime.now().toUtc()),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 6),
               receiveTimeout: const Duration(seconds: 6),
               headers: const {
                 'User-Agent': 'LacakSaji/1.0 (Android MBG Food Safety)',
                 'Accept': 'application/json',
               },
             ),
           );

  final AppDatabase _database;
  final Dio _dio;
  final DateTime Function() _clockUtc;

  static const String _bmkgEndpoint =
      'https://api.bmkg.go.id/publik/prakiraan-cuaca';

  @override
  Future<BmkgWeatherReading> getCurrentWeather({
    required String adm4Code,
    required bool isOffline,
    bool forceRefresh = false,
  }) async {
    final nowUtc = _clockUtc();
    final cleanAdm4 = adm4Code.trim();
    if (cleanAdm4.isEmpty) {
      return BmkgWeatherReading(
        adm4Code: adm4Code,
        temperatureC: AppConstants.bmkgOfflineFallbackTempC,
        source: BmkgSource.fallbackOffline,
        observedAtUtc: nowUtc,
        weatherDesc: 'Estimasi suhu lingkungan standar',
      );
    }

    final cachedRow = await _database.getNearestBmkgForecast(cleanAdm4, nowUtc);
    final cacheIsFresh =
        cachedRow != null &&
        nowUtc.difference(cachedRow.fetchedAt) < AppConstants.bmkgRefreshInterval;

    if (!forceRefresh && cacheIsFresh) {
      return BmkgWeatherReading(
        adm4Code: cleanAdm4,
        temperatureC: cachedRow.temperatureC,
        humidityPct: cachedRow.humidityPct,
        weatherDesc: cachedRow.weatherDesc,
        source: isOffline ? BmkgSource.cached : BmkgSource.live,
        observedAtUtc: cachedRow.forecastTimeUtc,
      );
    }

    if (!isOffline) {
      try {
        final response = await _dio.get<dynamic>(
          _bmkgEndpoint,
          queryParameters: {'adm4': cleanAdm4},
        );
        final parsedEntries = parseBmkgForecastJson(
          rawJson: response.data,
          adm4Code: cleanAdm4,
          fetchedAtUtc: nowUtc,
        );
        if (parsedEntries.isNotEmpty) {
          await _database.pruneExpiredBmkgCache(nowUtc);
          await _database.upsertBmkgForecasts(parsedEntries);
          final freshNearest = await _database.getNearestBmkgForecast(
            cleanAdm4,
            nowUtc,
          );
          if (freshNearest != null) {
            return BmkgWeatherReading(
              adm4Code: cleanAdm4,
              temperatureC: freshNearest.temperatureC,
              humidityPct: freshNearest.humidityPct,
              weatherDesc: freshNearest.weatherDesc,
              source: BmkgSource.live,
              observedAtUtc: freshNearest.forecastTimeUtc,
            );
          }
        }
      } catch (_) {
        // Fall through cleanly to local Drift cache or 31.0 C offline constant.
      }
    }

    if (cachedRow != null) {
      return BmkgWeatherReading(
        adm4Code: cleanAdm4,
        temperatureC: cachedRow.temperatureC,
        humidityPct: cachedRow.humidityPct,
        weatherDesc: cachedRow.weatherDesc,
        source: BmkgSource.cached,
        observedAtUtc: cachedRow.forecastTimeUtc,
      );
    }

    return BmkgWeatherReading(
      adm4Code: cleanAdm4,
      temperatureC: AppConstants.bmkgOfflineFallbackTempC,
      source: BmkgSource.fallbackOffline,
      observedAtUtc: nowUtc,
      weatherDesc: 'Estimasi suhu lokal tanpa sinyal',
    );
  }

  /// Parses BMKG public `adm4` JSON forecast structure into Drift cache companions.
  static List<LocalBmkgCacheCompanion> parseBmkgForecastJson({
    required dynamic rawJson,
    required String adm4Code,
    required DateTime fetchedAtUtc,
  }) {
    if (rawJson is! Map) {
      return const [];
    }
    final dataList = rawJson['data'];
    if (dataList is! List || dataList.isEmpty) {
      return const [];
    }

    final firstLocation = dataList.first;
    if (firstLocation is! Map) {
      return const [];
    }

    final cuacaRaw = firstLocation['cuaca'];
    if (cuacaRaw is! List || cuacaRaw.isEmpty) {
      return const [];
    }

    final entries = <LocalBmkgCacheCompanion>[];
    final seenForecastTimes = <DateTime>{};
    final expiresAt = fetchedAtUtc.add(AppConstants.bmkgCacheTtl);

    void visitItem(dynamic item) {
      if (item is List) {
        for (final nested in item) {
          visitItem(nested);
        }
        return;
      }
      if (item is! Map) {
        return;
      }

      final tempRaw = item['t'];
      final tempC = tempRaw is num
          ? tempRaw.toDouble()
          : double.tryParse(tempRaw?.toString() ?? '');
      if (tempC == null) {
        return;
      }

      final forecastUtc = _parseBmkgTimestamp(item) ?? fetchedAtUtc;
      if (!seenForecastTimes.add(forecastUtc)) {
        return;
      }

      final huRaw = item['hu'];
      final humidityPct = huRaw is num
          ? huRaw.round()
          : int.tryParse(huRaw?.toString() ?? '');
      final desc = item['weather_desc']?.toString().replaceAll('\u2014', ', ');

      entries.add(
        LocalBmkgCacheCompanion.insert(
          adm4Code: adm4Code,
          forecastTimeUtc: forecastUtc,
          temperatureC: tempC,
          humidityPct: humidityPct == null
              ? const Value.absent()
              : Value(humidityPct),
          weatherDesc: (desc == null || desc.trim().isEmpty)
              ? const Value.absent()
              : Value(desc.trim()),
          fetchedAt: fetchedAtUtc,
          expiresAt: expiresAt,
        ),
      );
    }

    for (final bucket in cuacaRaw) {
      visitItem(bucket);
    }

    return entries;
  }

  static DateTime? _parseBmkgTimestamp(Map item) {
    final utcRaw = item['utc_datetime']?.toString();
    if (utcRaw != null && utcRaw.trim().isNotEmpty) {
      final normalized = '${utcRaw.trim().replaceFirst(' ', 'T')}Z';
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    final localRaw = item['local_datetime']?.toString();
    if (localRaw != null && localRaw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(localRaw.trim().replaceFirst(' ', 'T'));
      if (parsed != null) {
        return parsed.subtract(const Duration(hours: 7)).toUtc();
      }
    }
    return null;
  }
}

final bmkgWeatherServiceProvider = Provider<BmkgWeatherService>((ref) {
  return DioBmkgWeatherService(database: ref.watch(appDatabaseProvider));
});

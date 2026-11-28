import '../../../core/constants/app_constants.dart';
import '../../kitchen/domain/kitchen_models.dart';

enum DangerZoneStatus {
  green('GREEN', 'WAKTU PENGIRIMAN AMAN'),
  yellow('YELLOW', 'WASPADA: PERIKSA LEBIH KETAT'),
  red('RED', 'STOP: JANGAN DIBAGIKAN');

  const DangerZoneStatus(this.dbValue, this.bannerTitle);

  final String dbValue;
  final String bannerTitle;

  static DangerZoneStatus fromDb(String? value) {
    for (final item in DangerZoneStatus.values) {
      if (item.dbValue == value) {
        return item;
      }
    }
    return DangerZoneStatus.yellow;
  }
}

enum FoodTemperatureSource {
  bmkgEstimate('bmkg_estimate', 'Estimasi Suhu BMKG'),
  manualThermometer('manual_thermometer', 'Termometer Manual'),
  bleSensor('ble_sensor', 'Sensor Suhu BLE');

  const FoodTemperatureSource(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static FoodTemperatureSource fromDb(String? value) {
    for (final source in FoodTemperatureSource.values) {
      if (source.dbValue == value) {
        return source;
      }
    }
    return FoodTemperatureSource.bmkgEstimate;
  }
}

class DangerZoneEvaluation {
  const DangerZoneEvaluation({
    required this.status,
    required this.elapsedMinutes,
    required this.safeLimitMinutes,
    required this.stopLimitMinutes,
    required this.isHotWeather,
    required this.explanation,
    this.effectiveTempC,
    this.tempSource = FoodTemperatureSource.bmkgEstimate,
    this.isControlledHoldingTemp = false,
    this.hasClockSkew = false,
    this.rawElapsedMinutes = 0,
  });

  final DangerZoneStatus status;
  final int elapsedMinutes;
  final int safeLimitMinutes;
  final int stopLimitMinutes;
  final bool isHotWeather;
  final String explanation;
  final double? effectiveTempC;
  final FoodTemperatureSource tempSource;
  final bool isControlledHoldingTemp;
  final bool hasClockSkew;
  final int rawElapsedMinutes;
}

/// Evaluates PRD Section 3.3 Danger-Zone Clock matrix across menu risk, duration,
/// actual food core temperature (priority 1 when measured), and BMKG weather estimate (default).
abstract final class DangerZoneCalculator {
  static DangerZoneEvaluation evaluate({
    required FoodRiskCategory riskCategory,
    required DateTime sealedAtUtc,
    required DateTime scanAtUtc,
    required double temperatureC,
    double? actualTempC,
    FoodTemperatureSource tempSource = FoodTemperatureSource.bmkgEstimate,
  }) {
    final rawElapsed = scanAtUtc.toUtc().difference(sealedAtUtc.toUtc()).inMinutes;
    final hasClockSkew = rawElapsed < -5;
    final elapsedMinutes = rawElapsed < 0 ? 0 : rawElapsed;

    final hasActualTemp =
        actualTempC != null &&
        tempSource != FoodTemperatureSource.bmkgEstimate;
    final resolvedTempC = hasActualTemp ? actualTempC : temperatureC;
    final resolvedSource = hasActualTemp
        ? tempSource
        : FoodTemperatureSource.bmkgEstimate;

    // Priority 1: Controlled holding temperatures outside bacterial danger zone (<= 5 C or >= 60 C).
    if (hasActualTemp && (resolvedTempC >= 60.0 || resolvedTempC <= 5.0)) {
      final normalStop = switch (riskCategory) {
        FoodRiskCategory.high => AppConstants.highNormalStopMinutes,
        FoodRiskCategory.medium => AppConstants.mediumNormalStopMinutes,
        FoodRiskCategory.low => AppConstants.lowStopMinutes,
      };
      final normalSafe = switch (riskCategory) {
        FoodRiskCategory.high => AppConstants.highNormalSafeMinutes,
        FoodRiskCategory.medium => AppConstants.mediumNormalSafeMinutes,
        FoodRiskCategory.low => AppConstants.lowSafeMinutes,
      };
      final formattedTemp = '${resolvedTempC.toStringAsFixed(1)} C';
      if (elapsedMinutes <= normalStop) {
        return DangerZoneEvaluation(
          status: DangerZoneStatus.green,
          elapsedMinutes: elapsedMinutes,
          safeLimitMinutes: normalStop,
          stopLimitMinutes: normalStop,
          isHotWeather: false,
          effectiveTempC: resolvedTempC,
          tempSource: resolvedSource,
          isControlledHoldingTemp: true,
          hasClockSkew: hasClockSkew,
          rawElapsedMinutes: rawElapsed,
          explanation:
              'Suhu aktual makanan ($formattedTemp via ${resolvedSource.label}) berada di luar zona bahaya bakteri (5-60 C). Makanan aman dikonsumsi setelah cek visual dan aroma.',
        );
      }
      return DangerZoneEvaluation(
        status: DangerZoneStatus.yellow,
        elapsedMinutes: elapsedMinutes,
        safeLimitMinutes: normalSafe,
        stopLimitMinutes: normalStop,
        isHotWeather: false,
        effectiveTempC: resolvedTempC,
        tempSource: resolvedSource,
        isControlledHoldingTemp: true,
        hasClockSkew: hasClockSkew,
        rawElapsedMinutes: rawElapsed,
        explanation:
            'Suhu aktual makanan ($formattedTemp via ${resolvedSource.label}) terjaga di luar zona bahaya, namun durasi kirim sudah melebihi ${formatDurationMinutes(normalStop)}. Lakukan cek organoleptik menyeluruh.',
      );
    }

    final isHot = resolvedTempC >= AppConstants.hotTemperatureThresholdC;

    final int safeLimit;
    final int stopLimit;

    switch (riskCategory) {
      case FoodRiskCategory.high:
        safeLimit = isHot
            ? AppConstants.highHotSafeMinutes
            : AppConstants.highNormalSafeMinutes;
        stopLimit = isHot
            ? AppConstants.highHotStopMinutes
            : AppConstants.highNormalStopMinutes;
      case FoodRiskCategory.medium:
        safeLimit = isHot
            ? AppConstants.mediumHotSafeMinutes
            : AppConstants.mediumNormalSafeMinutes;
        stopLimit = isHot
            ? AppConstants.mediumHotStopMinutes
            : AppConstants.mediumNormalStopMinutes;
      case FoodRiskCategory.low:
        safeLimit = AppConstants.lowSafeMinutes;
        stopLimit = AppConstants.lowStopMinutes;
    }

    final tempContext = hasActualTemp
        ? 'suhu aktual ${resolvedTempC.toStringAsFixed(1)} C (${resolvedSource.label}, ${isHot ? 'zona hangat >= 32 C' : '< 32 C'})'
        : (isHot ? 'cuaca panas (>= 32 C)' : 'suhu normal (< 32 C)');

    if (elapsedMinutes <= safeLimit) {
      return DangerZoneEvaluation(
        status: DangerZoneStatus.green,
        elapsedMinutes: elapsedMinutes,
        safeLimitMinutes: safeLimit,
        stopLimitMinutes: stopLimit,
        isHotWeather: isHot,
        effectiveTempC: resolvedTempC,
        tempSource: resolvedSource,
        hasClockSkew: hasClockSkew,
        rawElapsedMinutes: rawElapsed,
        explanation:
            'Durasi perjalanan masih dalam batas aman ${formatDurationMinutes(safeLimit)} untuk ${riskCategory.label.toLowerCase()} pada $tempContext. Lanjutkan ke cek kondisi makanan.',
      );
    }

    if (elapsedMinutes <= stopLimit) {
      return DangerZoneEvaluation(
        status: DangerZoneStatus.yellow,
        elapsedMinutes: elapsedMinutes,
        safeLimitMinutes: safeLimit,
        stopLimitMinutes: stopLimit,
        isHotWeather: isHot,
        effectiveTempC: resolvedTempC,
        tempSource: resolvedSource,
        hasClockSkew: hasClockSkew,
        rawElapsedMinutes: rawElapsed,
        explanation:
            'Durasi perjalanan melewati batas optimal ${formatDurationMinutes(safeLimit)} pada $tempContext. Periksa bau, tampilan, dan kemasan dengan sangat teliti sebelum dibagikan.',
      );
    }

    return DangerZoneEvaluation(
      status: DangerZoneStatus.red,
      elapsedMinutes: elapsedMinutes,
      safeLimitMinutes: safeLimit,
      stopLimitMinutes: stopLimit,
      isHotWeather: isHot,
      effectiveTempC: resolvedTempC,
      tempSource: resolvedSource,
      hasClockSkew: hasClockSkew,
      rawElapsedMinutes: rawElapsed,
      explanation:
          'Durasi perjalanan melampaui batas maksimal ${formatDurationMinutes(stopLimit)} untuk ${riskCategory.label.toLowerCase()} pada $tempContext. Hentikan pembagian makanan demi keselamatan siswa.',
    );
  }
}

String formatDurationMinutes(int totalMinutes) {
  final clamped = totalMinutes < 0 ? 0 : totalMinutes;
  final hours = clamped ~/ 60;
  final minutes = clamped % 60;
  if (hours == 0) {
    return '$minutes menit';
  }
  if (minutes == 0) {
    return '$hours jam';
  }
  return '$hours jam $minutes menit';
}

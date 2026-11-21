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

class DangerZoneEvaluation {
  const DangerZoneEvaluation({
    required this.status,
    required this.elapsedMinutes,
    required this.safeLimitMinutes,
    required this.stopLimitMinutes,
    required this.isHotWeather,
    required this.explanation,
  });

  final DangerZoneStatus status;
  final int elapsedMinutes;
  final int safeLimitMinutes;
  final int stopLimitMinutes;
  final bool isHotWeather;
  final String explanation;
}

/// Evaluates PRD Section 3.3 Danger-Zone Clock matrix across menu risk, duration, and BMKG temperature.
abstract final class DangerZoneCalculator {
  static DangerZoneEvaluation evaluate({
    required FoodRiskCategory riskCategory,
    required DateTime sealedAtUtc,
    required DateTime scanAtUtc,
    required double temperatureC,
  }) {
    final rawElapsed = scanAtUtc.toUtc().difference(sealedAtUtc.toUtc()).inMinutes;
    final elapsedMinutes = rawElapsed < 0 ? 0 : rawElapsed;
    final isHot = temperatureC >= AppConstants.hotTemperatureThresholdC;

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

    final weatherLabel = isHot ? 'cuaca panas (>= 32 C)' : 'suhu normal (< 32 C)';

    if (elapsedMinutes <= safeLimit) {
      return DangerZoneEvaluation(
        status: DangerZoneStatus.green,
        elapsedMinutes: elapsedMinutes,
        safeLimitMinutes: safeLimit,
        stopLimitMinutes: stopLimit,
        isHotWeather: isHot,
        explanation:
            'Durasi perjalanan masih dalam batas aman ${formatDurationMinutes(safeLimit)} untuk ${riskCategory.label.toLowerCase()} pada $weatherLabel. Lanjutkan ke cek kondisi makanan.',
      );
    }

    if (elapsedMinutes <= stopLimit) {
      return DangerZoneEvaluation(
        status: DangerZoneStatus.yellow,
        elapsedMinutes: elapsedMinutes,
        safeLimitMinutes: safeLimit,
        stopLimitMinutes: stopLimit,
        isHotWeather: isHot,
        explanation:
            'Durasi perjalanan melewati batas optimal ${formatDurationMinutes(safeLimit)} pada $weatherLabel. Periksa bau, tampilan, dan kemasan dengan sangat teliti sebelum dibagikan.',
      );
    }

    return DangerZoneEvaluation(
      status: DangerZoneStatus.red,
      elapsedMinutes: elapsedMinutes,
      safeLimitMinutes: safeLimit,
      stopLimitMinutes: stopLimit,
      isHotWeather: isHot,
      explanation:
          'Durasi perjalanan melampaui batas maksimal ${formatDurationMinutes(stopLimit)} untuk ${riskCategory.label.toLowerCase()} pada $weatherLabel. Hentikan pembagian makanan demi keselamatan siswa.',
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

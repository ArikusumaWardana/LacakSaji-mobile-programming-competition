/// Domain constants defined in PRD_lacaksaji.md.
abstract final class AppConstants {
  static const String appName = 'LacakSaji';
  static const String appVersion = '1.0.0+1';

  // Danger-Zone thresholds in minutes (PRD Section 3.3).
  static const double hotTemperatureThresholdC = 32.0;

  static const int highHotSafeMinutes = 90;
  static const int highHotStopMinutes = 120;
  static const int highNormalSafeMinutes = 120;
  static const int highNormalStopMinutes = 180;

  static const int mediumHotSafeMinutes = 180;
  static const int mediumHotStopMinutes = 240;
  static const int mediumNormalSafeMinutes = 210;
  static const int mediumNormalStopMinutes = 270;

  static const int lowSafeMinutes = 360;
  static const int lowStopMinutes = 480;

  // BMKG weather cache & offline fallback rules (PRD Section 3.3 & 8).
  static const double bmkgOfflineFallbackTempC = 31.0;
  static const Duration bmkgCacheTtl = Duration(hours: 72);
  static const Duration bmkgRefreshInterval = Duration(hours: 3);
  static const String bmkgShortAttribution = 'Data cuaca oleh BMKG';
  static const String bmkgFullAttribution =
      'Data prakiraan cuaca bersumber dari BMKG (Badan Meteorologi, Klimatologi, dan Geofisika)';

  // Field verification, retention & AI thresholds.
  static const double schoolGpsRadiusMeters = 500.0;
  static const Duration sampleVaultRetention = Duration(hours: 48);
  static const Duration geminiVisionTimeout = Duration(seconds: 8);

  // WebP image compression & storage quota targets (PRD Section 8).
  static const int auditPhotoMaxWidthPx = 1024;
  static const int auditPhotoWebpQuality = 70;
  static const String auditPhotosBucket = 'audit-photos';

  // SharedPreferences keys.
  static const String textScalePrefKey = 'lacak_comfortable_text_scale';
}

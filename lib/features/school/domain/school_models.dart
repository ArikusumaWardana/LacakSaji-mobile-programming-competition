import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/network/bmkg_weather_service.dart';
import '../../alerts/domain/cluster_alert_models.dart';
import '../../auth/domain/auth_models.dart';
import '../../kitchen/domain/kitchen_models.dart';
import 'danger_zone_calculator.dart';

enum QrVerificationOutcome {
  valid,
  invalidFormat,
  invalidSignature,
  missingPublicKey,
  foreignSppg,
}

class VerifiedBatchScanContext {
  const VerifiedBatchScanContext({
    required this.payload,
    required this.riskCategory,
    required this.timestampSource,
    required this.sealedAtUtc,
    required this.scannedAtUtc,
    required this.sppgName,
    required this.sppgPublicKeyB64,
    required this.weather,
    required this.dangerEvaluation,
    required this.gpsWithinRadius,
    this.distanceMeters,
  });

  final BatchQrPayload payload;
  final FoodRiskCategory riskCategory;
  final BatchTimestampSource timestampSource;
  final DateTime sealedAtUtc;
  final DateTime scannedAtUtc;
  final String sppgName;
  final String sppgPublicKeyB64;
  final BmkgWeatherReading weather;
  final DangerZoneEvaluation dangerEvaluation;
  final bool gpsWithinRadius;
  final double? distanceMeters;
}

class QrVerificationResult {
  const QrVerificationResult({
    required this.outcome,
    this.context,
    this.errorTitle,
    this.errorMessage,
  });

  final QrVerificationOutcome outcome;
  final VerifiedBatchScanContext? context;
  final String? errorTitle;
  final String? errorMessage;

  bool get isValid => outcome == QrVerificationOutcome.valid && context != null;
}

enum OnDeviceVisualLabel {
  freshLikely('fresh_likely', 'Terindikasi Segar'),
  suspiciousDiscoloration('suspicious_discoloration', 'Curiga Perubahan Warna/Lendir'),
  packagingAnomaly('packaging_anomaly', 'Curiga Kemasan Tidak Utuh');

  const OnDeviceVisualLabel(this.dbValue, this.displayLabel);

  final String dbValue;
  final String displayLabel;

  static OnDeviceVisualLabel fromDb(String? value) {
    for (final item in OnDeviceVisualLabel.values) {
      if (item.dbValue == value) {
        return item;
      }
    }
    return OnDeviceVisualLabel.freshLikely;
  }
}

enum MenuMatchStatus {
  match('match', 'Sesuai Menu'),
  partial('partial', 'Sebagian Berbeda'),
  mismatch('mismatch', 'Tidak Sesuai Menu'),
  unknown('unknown', 'Belum Terverifikasi');

  const MenuMatchStatus(this.dbValue, this.displayLabel);

  final String dbValue;
  final String displayLabel;

  static MenuMatchStatus? fromDb(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final item in MenuMatchStatus.values) {
      if (item.dbValue == value) {
        return item;
      }
    }
    return null;
  }
}

class OnDeviceVisualResult {
  const OnDeviceVisualResult({
    required this.label,
    required this.confidence,
    required this.summaryText,
    required this.usedTfliteModel,
    this.localHints = const [],
    this.estimatedCarbWastePct,
    this.estimatedProteinWastePct,
    this.estimatedVegWastePct,
  });

  final OnDeviceVisualLabel label;
  final double confidence;
  final String summaryText;
  final bool usedTfliteModel;
  final List<String> localHints;
  final int? estimatedCarbWastePct;
  final int? estimatedProteinWastePct;
  final int? estimatedVegWastePct;
}

class CloudVisionResult {
  const CloudVisionResult({
    required this.ok,
    required this.provider,
    required this.fallbackRequired,
    required this.summaryText,
    this.freshnessStatus,
    this.confidence,
    this.slimeOrDiscolorationDetected,
    this.packagingIssueDetected,
    this.carbWastePct,
    this.proteinWastePct,
    this.vegWastePct,
    this.modelUsed,
    this.anomaliesFound = const [],
    this.riceCheck,
    this.proteinCheck,
    this.vegetableCheck,
    this.fruitAndPackCheck,
    this.menuMatch,
    this.menuMatchNote,
  });

  final bool ok;
  final String provider;
  final bool fallbackRequired;
  final String summaryText;
  final OnDeviceVisualLabel? freshnessStatus;
  final double? confidence;
  final bool? slimeOrDiscolorationDetected;
  final bool? packagingIssueDetected;
  final int? carbWastePct;
  final int? proteinWastePct;
  final int? vegWastePct;
  final String? modelUsed;
  final List<String> anomaliesFound;
  final String? riceCheck;
  final String? proteinCheck;
  final String? vegetableCheck;
  final String? fruitAndPackCheck;
  final MenuMatchStatus? menuMatch;
  final String? menuMatchNote;

  bool get hasMenuMismatch =>
      menuMatch == MenuMatchStatus.partial ||
      menuMatch == MenuMatchStatus.mismatch;

  Map<String, dynamic> toJsonMap() {
    return {
      'ok': ok,
      'provider': provider,
      'fallback_required': fallbackRequired,
      'summary_id': summaryText,
      if (modelUsed != null) 'model': modelUsed,
      if (freshnessStatus != null) 'freshness_status': freshnessStatus!.dbValue,
      if (confidence != null) 'confidence': confidence,
      if (slimeOrDiscolorationDetected != null)
        'slime_or_discoloration_detected': slimeOrDiscolorationDetected,
      if (packagingIssueDetected != null)
        'packaging_issue_detected': packagingIssueDetected,
      if (anomaliesFound.isNotEmpty) 'anomalies_found': anomaliesFound,
      if (riceCheck != null && riceCheck!.isNotEmpty) 'rice_check': riceCheck,
      if (proteinCheck != null && proteinCheck!.isNotEmpty)
        'protein_check': proteinCheck,
      if (vegetableCheck != null && vegetableCheck!.isNotEmpty)
        'vegetable_check': vegetableCheck,
      if (fruitAndPackCheck != null && fruitAndPackCheck!.isNotEmpty)
        'fruit_and_pack_check': fruitAndPackCheck,
      if (menuMatch != null) 'menu_match': menuMatch!.dbValue,
      if (menuMatchNote != null && menuMatchNote!.isNotEmpty)
        'menu_match_note': menuMatchNote,
    };
  }
}

class SchoolInspectionItem {
  const SchoolInspectionItem({
    required this.id,
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.schoolId,
    required this.scannedAtUtc,
    required this.elapsedMinutes,
    required this.bmkgTempC,
    required this.bmkgSource,
    required this.dangerStatus,
    required this.gpsWithinRadius,
    required this.manualSmellOk,
    required this.manualVisualOk,
    required this.manualPackOk,
    required this.finalDecision,
    this.sealedAtUtc,
    this.sampleLabelCode,
    this.samplePhotoUrl,
    this.localPhotoPath,
    this.tfliteLabel,
    this.tfliteConfidence,
    this.geminiSummaryJson,
    this.isPendingSync = false,
  });

  final String id;
  final String batchId;
  final String batchCode;
  final String menuName;
  final String schoolId;
  final DateTime scannedAtUtc;
  final int elapsedMinutes;
  final double bmkgTempC;
  final BmkgSource bmkgSource;
  final DangerZoneStatus dangerStatus;
  final bool gpsWithinRadius;
  final DateTime? sealedAtUtc;
  final String? sampleLabelCode;
  final String? samplePhotoUrl;
  final String? localPhotoPath;
  final String? tfliteLabel;
  final double? tfliteConfidence;
  final Map<String, dynamic>? geminiSummaryJson;
  final bool manualSmellOk;
  final bool manualVisualOk;
  final bool manualPackOk;
  final String finalDecision; // 'APPROVED' | 'REJECTED'
  final bool isPendingSync;

  DateTime get effectiveSealedAtUtc =>
      sealedAtUtc ?? scannedAtUtc.subtract(Duration(minutes: elapsedMinutes));
}

class SampleVaultItem {
  const SampleVaultItem({
    required this.id,
    required this.inspectionId,
    required this.schoolId,
    required this.menuName,
    required this.labelCode,
    required this.storedAtUtc,
    required this.expiresAtUtc,
    required this.status,
    required this.isSynced,
  });

  final String id;
  final String inspectionId;
  final String schoolId;
  final String menuName;
  final String labelCode;
  final DateTime storedAtUtc;
  final DateTime expiresAtUtc;
  final String status; // 'active' | 'disposed' | 'lab_submitted'
  final bool isSynced;

  Duration remainingFrom(DateTime nowUtc) {
    final diff = expiresAtUtc.toUtc().difference(nowUtc.toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool isReadyToDispose(DateTime nowUtc) =>
      remainingFrom(nowUtc) == Duration.zero;
}

class SampleVaultOnboardingArgs {
  const SampleVaultOnboardingArgs({
    required this.inspectionId,
    required this.menuName,
    required this.batchCode,
    required this.suggestedLabelCode,
  });

  final String inspectionId;
  final String menuName;
  final String batchCode;
  final String suggestedLabelCode;
}

class SchoolBatchOption {
  const SchoolBatchOption({
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.sealedAtUtc,
  });

  final String batchId;
  final String batchCode;
  final String menuName;
  final DateTime sealedAtUtc;

  String get displayLabel => '$batchCode · $menuName';
}

class AnomalyHandoffArgs {
  const AnomalyHandoffArgs({
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.sppgName,
    required this.sealedAtUtc,
    required this.bmkgTempC,
    required this.inspectionId,
    required this.reasonSummary,
    this.sppgId,
    this.scannedAtUtc,
    this.elapsedMinutes,
    this.bmkgSource,
    this.dangerStatus,
    this.localPhotoPath,
    this.sampleLabelCode,
    this.initialStage = ClusterAlertStage.preConsumption,
  });

  final String batchId;
  final String batchCode;
  final String menuName;
  final String sppgName;
  final DateTime sealedAtUtc;
  final double bmkgTempC;
  final String inspectionId;
  final String reasonSummary;
  final String? sppgId;
  final DateTime? scannedAtUtc;
  final int? elapsedMinutes;
  final BmkgSource? bmkgSource;
  final DangerZoneStatus? dangerStatus;
  final String? localPhotoPath;
  final String? sampleLabelCode;
  final ClusterAlertStage initialStage;
}

class SchoolDashboardData {
  const SchoolDashboardData({
    required this.school,
    required this.weather,
    required this.todayInspections,
    required this.activeSampleCount,
    required this.partnerKeyCached,
    this.nearestSampleExpiryUtc,
  });

  final SchoolProfile school;
  final BmkgWeatherReading weather;
  final List<SchoolInspectionItem> todayInspections;
  final int activeSampleCount;
  final DateTime? nearestSampleExpiryUtc;
  final bool partnerKeyCached;
}

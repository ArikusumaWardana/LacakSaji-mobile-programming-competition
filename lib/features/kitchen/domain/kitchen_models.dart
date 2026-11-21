import 'dart:convert';

import '../../../core/constants/demo_accounts.dart';
import '../../../core/crypto/batch_qr_payload.dart';
import '../../auth/domain/auth_models.dart';

enum FoodRiskCategory {
  high(
    'HIGH',
    'Risiko Tinggi',
    'Makanan bersantan, kuah basah, ayam suwir basah, atau olahan susu segar',
    'Batas aman: 1,5 jam saat cuaca panas (>= 32 C) atau 2 jam saat suhu normal.',
  ),
  medium(
    'MEDIUM',
    'Risiko Sedang',
    'Nasi, tumisan kering, atau lauk goreng dan bakar dalam wadah tertutup',
    'Batas aman: 3 jam saat cuaca panas atau 3,5 jam saat suhu normal.',
  ),
  low(
    'LOW',
    'Risiko Rendah',
    'Roti kemasan pabrik, buah utuh berkulit, atau susu UHT tersegel',
    'Batas aman: 6 jam sebelum pembagian di sekolah.',
  );

  const FoodRiskCategory(
    this.dbValue,
    this.label,
    this.examples,
    this.safetyNote,
  );

  final String dbValue;
  final String label;
  final String examples;
  final String safetyNote;

  static FoodRiskCategory fromDb(String? value) {
    for (final category in FoodRiskCategory.values) {
      if (category.dbValue == value) {
        return category;
      }
    }
    return FoodRiskCategory.medium;
  }
}

enum BatchTimestampSource {
  serverVerified('server_verified', 'Waktu Resmi Server'),
  offlineUnverified(
    'offline_unverified',
    'Waktu Perangkat (Dicek Saat Ada Sinyal)',
  );

  const BatchTimestampSource(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static BatchTimestampSource fromDb(String? value) {
    for (final source in BatchTimestampSource.values) {
      if (source.dbValue == value) {
        return source;
      }
    }
    return BatchTimestampSource.serverVerified;
  }
}

enum SchoolDailyStatus {
  received('Sudah Terima'),
  notScanned('Belum Scan'),
  anomaly('Anomali');

  const SchoolDailyStatus(this.label);

  final String label;
}

enum HistoryTimeRange {
  today('Hari Ini', 1),
  last7Days('7 Hari', 7),
  last30Days('30 Hari', 30);

  const HistoryTimeRange(this.label, this.days);

  final String label;
  final int days;
}

class FoodBatchItem {
  const FoodBatchItem({
    required this.id,
    required this.sppgId,
    required this.sppgName,
    required this.batchCode,
    required this.menuName,
    required this.portionCount,
    required this.riskCategory,
    required this.sealedAtUtc,
    required this.timestampSource,
    required this.signatureB64,
    required this.createdAtUtc,
    this.packagingPhotoUrl,
    this.localPhotoPath,
    this.inspectedSchoolIds = const [],
    this.hasAnomalyReport = false,
    this.isPendingSync = false,
  });

  final String id;
  final String sppgId;
  final String sppgName;
  final String batchCode;
  final String menuName;
  final int portionCount;
  final FoodRiskCategory riskCategory;
  final DateTime sealedAtUtc;
  final BatchTimestampSource timestampSource;
  final String? packagingPhotoUrl;
  final String? localPhotoPath;
  final String signatureB64;
  final DateTime createdAtUtc;
  final List<String> inspectedSchoolIds;
  final bool hasAnomalyReport;
  final bool isPendingSync;

  int get sealedAtEpochSec =>
      sealedAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000;

  BatchQrPayload get qrPayload => BatchQrPayload(
        batchId: id,
        batchCode: batchCode,
        sppgId: sppgId,
        menuName: menuName,
        riskCategory: riskCategory.dbValue,
        sealedAtEpochSec: sealedAtEpochSec,
        timestampSource: timestampSource.dbValue,
        signatureB64: signatureB64,
      );

  String get qrPayloadJson => qrPayload.toMinifiedJson();

  Map<String, dynamic> toDbInsertMap() {
    return {
      'id': id,
      'sppg_id': sppgId,
      'batch_code': batchCode,
      'menu_name': menuName,
      'portion_count': portionCount,
      'risk_category': riskCategory.dbValue,
      'sealed_at': sealedAtUtc.toUtc().toIso8601String(),
      'timestamp_source': timestampSource.dbValue,
      'packaging_photo_url': packagingPhotoUrl,
      'signature_b64': signatureB64,
      'created_at': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  String toOfflineQueuePayloadJson() {
    return jsonEncode({
      ...toDbInsertMap(),
      'sppg_name': sppgName,
    });
  }

  factory FoodBatchItem.fromSupabaseMap(
    Map<String, dynamic> map, {
    required String sppgName,
    bool hasAnomalyReport = false,
  }) {
    final rawInspections = map['school_inspections'];
    final schoolIds = <String>{};
    var anomalyFromInspection = false;

    if (rawInspections is List) {
      for (final row in rawInspections) {
        if (row is Map<String, dynamic>) {
          final schoolId = row['school_id'] as String?;
          if (schoolId != null && schoolId.isNotEmpty) {
            schoolIds.add(schoolId);
          }
          final decision = row['final_decision'] as String?;
          final danger = row['danger_status'] as String?;
          if (decision == 'REJECTED' || danger == 'RED') {
            anomalyFromInspection = true;
          }
        }
      }
    }

    return FoodBatchItem(
      id: map['id'] as String,
      sppgId: map['sppg_id'] as String,
      sppgName: sppgName,
      batchCode: map['batch_code'] as String,
      menuName: map['menu_name'] as String,
      portionCount: (map['portion_count'] as num).toInt(),
      riskCategory: FoodRiskCategory.fromDb(map['risk_category'] as String?),
      sealedAtUtc: DateTime.parse(map['sealed_at'] as String).toUtc(),
      timestampSource: BatchTimestampSource.fromDb(
        map['timestamp_source'] as String?,
      ),
      packagingPhotoUrl: map['packaging_photo_url'] as String?,
      signatureB64: map['signature_b64'] as String,
      createdAtUtc: DateTime.parse(map['created_at'] as String).toUtc(),
      inspectedSchoolIds: schoolIds.toList(growable: false),
      hasAnomalyReport: hasAnomalyReport || anomalyFromInspection,
    );
  }

  factory FoodBatchItem.fromOfflineQueuePayload(
    String payloadJson, {
    String? localPhotoPath,
  }) {
    final map = Map<String, dynamic>.from(jsonDecode(payloadJson) as Map);
    return FoodBatchItem(
      id: map['id'] as String,
      sppgId: map['sppg_id'] as String,
      sppgName: (map['sppg_name'] as String?) ?? 'Dapur SPPG',
      batchCode: map['batch_code'] as String,
      menuName: map['menu_name'] as String,
      portionCount: (map['portion_count'] as num).toInt(),
      riskCategory: FoodRiskCategory.fromDb(map['risk_category'] as String?),
      sealedAtUtc: DateTime.parse(map['sealed_at'] as String).toUtc(),
      timestampSource: BatchTimestampSource.fromDb(
        map['timestamp_source'] as String?,
      ),
      packagingPhotoUrl: map['packaging_photo_url'] as String?,
      localPhotoPath: localPhotoPath,
      signatureB64: map['signature_b64'] as String,
      createdAtUtc: DateTime.parse(
        (map['created_at'] as String?) ?? (map['sealed_at'] as String),
      ).toUtc(),
      isPendingSync: true,
    );
  }
}

class PartnerSchoolItem {
  const PartnerSchoolItem({
    required this.id,
    required this.sppgId,
    required this.npsn,
    required this.name,
    required this.adm4Code,
    required this.puskesmasWa,
    required this.verificationStatus,
    required this.dailyStatus,
    required this.createdAtUtc,
    this.lastScannedAtUtc,
  });

  final String id;
  final String sppgId;
  final String npsn;
  final String name;
  final String adm4Code;
  final String puskesmasWa;
  final SchoolVerificationStatus verificationStatus;
  final SchoolDailyStatus dailyStatus;
  final DateTime createdAtUtc;
  final DateTime? lastScannedAtUtc;

  String get villageLabel => resolveAdm4VillageName(adm4Code);
}

class PlateWasteLogItem {
  const PlateWasteLogItem({
    required this.id,
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.schoolId,
    required this.schoolName,
    required this.carbWastePct,
    required this.proteinWastePct,
    required this.vegWastePct,
    required this.aiAssisted,
    required this.createdAtUtc,
  });

  final String id;
  final String batchId;
  final String batchCode;
  final String menuName;
  final String schoolId;
  final String schoolName;
  final int carbWastePct;
  final int proteinWastePct;
  final int vegWastePct;
  final bool aiAssisted;
  final DateTime createdAtUtc;

  bool get needsMenuReview =>
      carbWastePct >= 40 || proteinWastePct >= 40 || vegWastePct >= 40;
}

class PlateWasteSummary {
  const PlateWasteSummary({
    required this.avgCarbPct,
    required this.avgProteinPct,
    required this.avgVegPct,
    required this.sampleCount,
    required this.recommendations,
  });

  static const PlateWasteSummary empty = PlateWasteSummary(
    avgCarbPct: 0,
    avgProteinPct: 0,
    avgVegPct: 0,
    sampleCount: 0,
    recommendations: [],
  );

  final int avgCarbPct;
  final int avgProteinPct;
  final int avgVegPct;
  final int sampleCount;
  final List<String> recommendations;

  bool get hasHighWasteAlert =>
      sampleCount > 0 &&
      (avgCarbPct >= 40 || avgProteinPct >= 40 || avgVegPct >= 40);

  factory PlateWasteSummary.fromLogs(List<PlateWasteLogItem> logs) {
    if (logs.isEmpty) {
      return PlateWasteSummary.empty;
    }

    var carbSum = 0;
    var proteinSum = 0;
    var vegSum = 0;
    for (final log in logs) {
      carbSum += log.carbWastePct;
      proteinSum += log.proteinWastePct;
      vegSum += log.vegWastePct;
    }

    final count = logs.length;
    final avgCarb = (carbSum / count).round();
    final avgProtein = (proteinSum / count).round();
    final avgVeg = (vegSum / count).round();

    final recs = <String>[];
    if (avgVeg >= 40) {
      recs.add(
        'Rata-rata sisa sayuran mencapai $avgVeg%. Pertimbangkan potongan sayur lebih kecil, bumbu lebih ringan, atau variasi sayur manis.',
      );
    }
    if (avgCarb >= 40) {
      recs.add(
        'Rata-rata sisa karbohidrat mencapai $avgCarb%. Pertimbangkan penyesuaian takaran porsi nasi per jenjang kelas.',
      );
    }
    if (avgProtein >= 40) {
      recs.add(
        'Rata-rata sisa lauk protein mencapai $avgProtein%. Evaluasi tekstur keempukan lauk atau pilih olahan tanpa tulang.',
      );
    }
    if (recs.isEmpty) {
      recs.add(
        'Tingkat sisa makanan di seluruh komponen terkendali di bawah ambang 40%. Pertahankan komposisi dan porsi menu saat ini.',
      );
    }

    return PlateWasteSummary(
      avgCarbPct: avgCarb,
      avgProteinPct: avgProtein,
      avgVegPct: avgVeg,
      sampleCount: count,
      recommendations: recs,
    );
  }
}

class ActiveClusterAlertItem {
  const ActiveClusterAlertItem({
    required this.id,
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.reporterSchoolName,
    required this.stage,
    required this.symptomCount,
    required this.createdAtUtc,
  });

  final String id;
  final String batchId;
  final String batchCode;
  final String menuName;
  final String reporterSchoolName;
  final String stage;
  final int symptomCount;
  final DateTime createdAtUtc;
}

class KitchenDashboardData {
  const KitchenDashboardData({
    required this.kitchen,
    required this.todayBatches,
    required this.todayReceivedSchoolsCount,
    required this.approvedSchoolsCount,
    required this.pendingSchoolsCount,
    required this.activeAlertsToday,
    required this.weeklyWasteSummary,
  });

  final KitchenProfile kitchen;
  final List<FoodBatchItem> todayBatches;
  final int todayReceivedSchoolsCount;
  final int approvedSchoolsCount;
  final int pendingSchoolsCount;
  final List<ActiveClusterAlertItem> activeAlertsToday;
  final PlateWasteSummary weeklyWasteSummary;
}

class KitchenHistoryData {
  const KitchenHistoryData({
    required this.range,
    required this.batches,
    required this.wasteLogs,
    required this.wasteSummary,
  });

  final HistoryTimeRange range;
  final List<FoodBatchItem> batches;
  final List<PlateWasteLogItem> wasteLogs;
  final PlateWasteSummary wasteSummary;
}

const Map<String, String> _extraVillageNames = {
  '33.02.26.1004': 'Bancarkembar, Purwokerto Utara',
};

String resolveAdm4VillageName(String adm4Code) {
  for (final option in kBanyumasAdm4Options) {
    if (option.code == adm4Code) {
      return '${option.villageName}, ${option.districtName}';
    }
  }
  return _extraVillageNames[adm4Code] ?? 'Wilayah $adm4Code';
}

DateTime toWibDateTime(DateTime utc) {
  return utc.toUtc().add(const Duration(hours: 7));
}

bool isSameWibCalendarDay(DateTime aUtc, DateTime bUtc) {
  final aWib = toWibDateTime(aUtc);
  final bWib = toWibDateTime(bUtc);
  return aWib.year == bWib.year &&
      aWib.month == bWib.month &&
      aWib.day == bWib.day;
}

const List<String> _indonesianMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatWibTime(DateTime utc) {
  final wib = toWibDateTime(utc);
  final hh = wib.hour.toString().padLeft(2, '0');
  final mm = wib.minute.toString().padLeft(2, '0');
  return '$hh:$mm WIB';
}

String formatIndonesianDate(DateTime utc) {
  final wib = toWibDateTime(utc);
  final dd = wib.day.toString().padLeft(2, '0');
  final mon = _indonesianMonths[wib.month - 1];
  return '$dd $mon ${wib.year}';
}

String formatWibDateTime(DateTime utc) {
  return '${formatIndonesianDate(utc)}, ${formatWibTime(utc)}';
}

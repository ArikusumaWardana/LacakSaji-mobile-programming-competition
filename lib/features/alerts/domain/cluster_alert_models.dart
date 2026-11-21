import '../../school/domain/danger_zone_calculator.dart';
import '../../../core/network/bmkg_weather_service.dart';

final RegExp _unicodeEmojiRegex = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
  unicode: true,
);

/// Strips Unicode emojis and replaces em-dash (`U+2014`) across notifications, WA text, and PDFs.
String sanitizeZeroSlopCopy(String input) {
  return input
      .replaceAll('\u2014', ', ')
      .replaceAll('\u2013', '-')
      .replaceAll(_unicodeEmojiRegex, '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();
}

enum ClusterAlertStage {
  preConsumption(
    'pre_consumption',
    'Tahap 1: Ditemukan Sebelum Makan',
    'Makanan dicurigai basi, berlendir, kemasan rusak, atau lewat batas waktu sebelum dibagikan ke siswa.',
  ),
  postConsumption(
    'post_consumption',
    'Tahap 2: Ada Siswa Bergejala Setelah Makan',
    'Siswa mengalami gejala seperti mual, muntah, atau pusing setelah mengonsumsi batch ini.',
  );

  const ClusterAlertStage(this.dbValue, this.title, this.subtitle);

  final String dbValue;
  final String title;
  final String subtitle;

  static ClusterAlertStage fromDb(String? value) {
    if (value == postConsumption.dbValue) {
      return ClusterAlertStage.postConsumption;
    }
    return ClusterAlertStage.preConsumption;
  }
}

class ClusterAlertEvent {
  const ClusterAlertEvent({
    required this.id,
    required this.sppgId,
    required this.sppgName,
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.reporterSchoolId,
    required this.reporterSchoolName,
    required this.stage,
    required this.symptomCount,
    required this.broadcastEnabled,
    required this.createdAtUtc,
    this.notes,
    this.sampleLabelCode,
    this.pdfDispatched = false,
    this.activeReporterCount = 1,
    this.isPendingSync = false,
  });

  final String id;
  final String sppgId;
  final String sppgName;
  final String batchId;
  final String batchCode;
  final String menuName;
  final String reporterSchoolId;
  final String reporterSchoolName;
  final ClusterAlertStage stage;
  final int symptomCount;
  final String? notes;
  final bool broadcastEnabled;
  final String? sampleLabelCode;
  final bool pdfDispatched;
  final DateTime createdAtUtc;
  final int activeReporterCount;
  final bool isPendingSync;

  String get instructionText {
    if (stage == ClusterAlertStage.postConsumption) {
      return sanitizeZeroSlopCopy(
        'Tahap 2 (Pasca-Konsumsi): Tahan segera pembagian kloter siang untuk menu $menuName, pantau kondisi siswa, dan siapkan Bank Sampel 2x24 jam untuk pemeriksaan Puskesmas.',
      );
    }
    return sanitizeZeroSlopCopy(
      'Tahap 1 (Pra-Konsumsi): Hentikan dan tahan seluruh pembagian menu $menuName dari $sppgName sebelum dikonsumsi siswa.',
    );
  }

  static ClusterAlertEvent? fromFcmData(Map<String, dynamic> data) {
    if (data['type'] != 'cluster_alert') {
      return null;
    }
    final id = (data['alert_id'] as String?)?.trim() ?? '';
    final sppgId = (data['sppg_id'] as String?)?.trim() ?? '';
    final batchId = (data['batch_id'] as String?)?.trim() ?? '';
    if (id.isEmpty || sppgId.isEmpty || batchId.isEmpty) {
      return null;
    }
    final rawCreated = data['created_at'] as String?;
    final parsedCreated = rawCreated != null
        ? DateTime.tryParse(rawCreated)?.toUtc()
        : null;

    return ClusterAlertEvent(
      id: id,
      sppgId: sppgId,
      sppgName: sanitizeZeroSlopCopy(
        (data['sppg_name'] as String?) ?? 'Dapur SPPG Mitra',
      ),
      batchId: batchId,
      batchCode: sanitizeZeroSlopCopy(
        (data['batch_code'] as String?) ?? '-',
      ),
      menuName: sanitizeZeroSlopCopy(
        (data['menu_name'] as String?) ?? 'Menu Makan Bergizi Gratis',
      ),
      reporterSchoolId: (data['reporter_school_id'] as String?) ?? '',
      reporterSchoolName: sanitizeZeroSlopCopy(
        (data['reporter_school_name'] as String?) ?? 'Sekolah Mitra SPPG',
      ),
      stage: ClusterAlertStage.fromDb(data['stage'] as String?),
      symptomCount: int.tryParse('${data['symptom_count'] ?? 0}') ?? 0,
      notes: (data['notes'] as String?) == null
          ? null
          : sanitizeZeroSlopCopy(data['notes'] as String),
      broadcastEnabled: '${data['broadcast_enabled'] ?? 'true'}' != 'false',
      sampleLabelCode: (data['sample_label_code'] as String?)?.trim(),
      pdfDispatched: '${data['pdf_dispatched'] ?? 'false'}' == 'true',
      createdAtUtc: parsedCreated ?? DateTime.now().toUtc(),
      activeReporterCount:
          int.tryParse('${data['active_reporter_count'] ?? 1}') ?? 1,
    );
  }
}

class PuskesmasDraftArgs {
  const PuskesmasDraftArgs({
    required this.alertId,
    required this.batchId,
    required this.batchCode,
    required this.menuName,
    required this.sppgId,
    required this.sppgName,
    required this.sealedAtUtc,
    required this.scannedAtUtc,
    required this.elapsedMinutes,
    required this.bmkgTempC,
    required this.bmkgSource,
    required this.dangerStatus,
    required this.stage,
    required this.symptomCount,
    required this.reasonSummary,
    required this.broadcastEnabled,
    required this.reportedAtUtc,
    this.notes,
    this.localPhotoPath,
    this.sampleLabelCode,
    this.isPendingSync = false,
    this.initialPdfDispatched = false,
  });

  final String alertId;
  final String batchId;
  final String batchCode;
  final String menuName;
  final String sppgId;
  final String sppgName;
  final DateTime sealedAtUtc;
  final DateTime scannedAtUtc;
  final int elapsedMinutes;
  final double bmkgTempC;
  final BmkgSource bmkgSource;
  final DangerZoneStatus dangerStatus;
  final ClusterAlertStage stage;
  final int symptomCount;
  final String? notes;
  final String reasonSummary;
  final String? localPhotoPath;
  final String? sampleLabelCode;
  final bool broadcastEnabled;
  final bool isPendingSync;
  final bool initialPdfDispatched;
  final DateTime reportedAtUtc;
}

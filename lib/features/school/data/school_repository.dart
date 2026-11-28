import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/media/live_camera_webp_service.dart';
import '../../../core/network/bmkg_weather_service.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../allergens/domain/allergen_models.dart';
import '../../auth/domain/auth_error_mapper.dart';
import '../../auth/domain/auth_models.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/danger_zone_calculator.dart';
import '../domain/school_models.dart';

typedef DeviceLocationReader = Future<({double? lat, double? lng})> Function();

Future<({double? lat, double? lng})> defaultSchoolLocationReader() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return (lat: null, lng: null);
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (lat: null, lng: null);
    }
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      return (lat: lastKnown.latitude, lng: lastKnown.longitude);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 3),
      ),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return (lat: null, lng: null);
  }
}

abstract class SchoolRepository {
  Future<SchoolDashboardData> fetchDashboardData({
    required SchoolProfile school,
    required bool isOffline,
  });

  Future<QrVerificationResult> verifyQrPayloadOffline({
    required String rawQrText,
    required SchoolProfile school,
    required bool isOffline,
  });

  Future<SchoolInspectionItem> saveInspection({
    required SchoolProfile school,
    required VerifiedBatchScanContext scanContext,
    required CapturedWebpPhoto? samplePhoto,
    required OnDeviceVisualResult? onDeviceResult,
    required CloudVisionResult? cloudResult,
    required bool manualSmellOk,
    required bool manualVisualOk,
    required bool manualPackOk,
    required bool approved,
    required bool isOffline,
  });

  Future<SampleVaultItem> createSampleVault({
    required SchoolProfile school,
    required String inspectionId,
    required String menuName,
    required String labelCode,
    required bool isOffline,
  });

  Stream<List<SampleVaultItem>> watchActiveSamples(String schoolId);

  Stream<List<SampleVaultItem>> watchHistorySamples(String schoolId);

  Future<void> refreshSampleVaultsFromServer(String schoolId);

  Future<void> markSampleDisposed({
    required String sampleId,
    required bool isOffline,
  });

  Future<List<SchoolBatchOption>> fetchSelectableBatchesForWaste({
    required SchoolProfile school,
    required bool isOffline,
  });

  Future<bool> submitPlateWasteLog({
    required SchoolProfile school,
    required String batchId,
    required int carbWastePct,
    required int proteinWastePct,
    required int vegWastePct,
    required List<CapturedWebpPhoto> photos,
    required bool aiAssisted,
    required bool isOffline,
  });

  Future<int> syncPendingSchoolQueue({required SchoolProfile school});

  String generateSampleLabelCode(DateTime nowUtc);
}

class SupabaseSchoolRepository implements SchoolRepository {
  SupabaseSchoolRepository({
    required this._client,
    required this._database,
    required this._ed25519Service,
    required this._bmkgService,
    required this._notificationService,
    this._backgroundSyncScheduler,
    DeviceLocationReader? locationReader,
    Uuid? uuid,
    DateTime Function()? clockUtc,
  }) : _locationReader = locationReader ?? defaultSchoolLocationReader,
       _uuid = uuid ?? const Uuid(),
       _clockUtc = clockUtc ?? (() => DateTime.now().toUtc());

  final SupabaseClient? _client;
  final AppDatabase _database;
  final Ed25519Service _ed25519Service;
  final BmkgWeatherService _bmkgService;
  final LocalNotificationService _notificationService;
  final BackgroundSyncScheduler? _backgroundSyncScheduler;
  final DeviceLocationReader _locationReader;
  final Uuid _uuid;
  final DateTime Function() _clockUtc;

  static const String _labelChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  @override
  String generateSampleLabelCode(DateTime nowUtc) {
    final wib = toWibDateTime(nowUtc);
    final yy = (wib.year % 100).toString().padLeft(2, '0');
    final mm = wib.month.toString().padLeft(2, '0');
    final dd = wib.day.toString().padLeft(2, '0');
    final suffix = List.generate(
      3,
      (_) => _labelChars[_random.nextInt(_labelChars.length)],
    ).join();
    return 'SMP-$yy$mm-$dd$suffix';
  }

  @override
  Future<SchoolDashboardData> fetchDashboardData({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    final nowUtc = _clockUtc();
    final weatherFuture = _bmkgService.getCurrentWeather(
      adm4Code: school.adm4Code,
      isOffline: isOffline,
    );
    final cachedKeyFuture = school.sppgId == null
        ? Future<LocalSppgKey?>.value(null)
        : _database.getSppgKey(school.sppgId!);
    final localSamplesFuture = _database.watchActiveSampleVaults(school.id).first;
    final localQueuedInspectionsFuture = _readLocalQueuedInspections(school.id);

    final weather = await weatherFuture;
    final cachedKey = await cachedKeyFuture;
    var activeSamples = await localSamplesFuture;
    final localQueued = await localQueuedInspectionsFuture;
    final todayLocal = localQueued
        .where((i) => isSameWibCalendarDay(i.scannedAtUtc, nowUtc))
        .toList(growable: false);

    final client = _client;
    if (isOffline || client == null) {
      activeSamples.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      return SchoolDashboardData(
        school: school,
        weather: weather,
        todayInspections: todayLocal,
        activeSampleCount: activeSamples.length,
        nearestSampleExpiryUtc: activeSamples.isNotEmpty
            ? activeSamples.first.expiresAt.toUtc()
            : null,
        partnerKeyCached: cachedKey != null || (school.partnerPublicKey ?? '').isNotEmpty,
      );
    }

    try {
      await refreshSampleVaultsFromServer(school.id);
      activeSamples = await _database.watchActiveSampleVaults(school.id).first;
      activeSamples.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      final historySamples = await _database
          .watchHistorySampleVaults(school.id)
          .first;
      final sampleLabelByInspectionId = <String, String>{
        for (final s in activeSamples) s.inspectionId: s.labelCode,
        for (final s in historySamples) s.inspectionId: s.labelCode,
      };

      List<Map<String, dynamic>> inspectionRows;
      try {
        inspectionRows = List<Map<String, dynamic>>.from(
          await client
                  .from('school_inspections')
                  .select(
                    'id, batch_id, school_id, scanned_at, elapsed_minutes, '
                    'bmkg_temp_c, bmkg_source, danger_status, gps_within_radius, '
                    'sample_photo_url, tflite_label, tflite_confidence, '
                    'gemini_summary_json, actual_temp_celsius, temp_source, '
                    'manual_smell_ok, manual_visual_ok, manual_pack_ok, final_decision, '
                    'food_batches(batch_code, menu_name, sealed_at, allergen_tags)',
                  )
                  .eq('school_id', school.id)
                  .order('scanned_at', ascending: false)
                  .limit(30)
              as List,
        );
      } on PostgrestException catch (pgError) {
        if (pgError.code == 'PGRST204' || pgError.code == '42703') {
          inspectionRows = List<Map<String, dynamic>>.from(
            await client
                    .from('school_inspections')
                    .select(
                      'id, batch_id, school_id, scanned_at, elapsed_minutes, '
                      'bmkg_temp_c, bmkg_source, danger_status, gps_within_radius, '
                      'sample_photo_url, tflite_label, tflite_confidence, '
                      'gemini_summary_json, manual_smell_ok, manual_visual_ok, '
                      'manual_pack_ok, final_decision, '
                      'food_batches(batch_code, menu_name, sealed_at)',
                    )
                    .eq('school_id', school.id)
                    .order('scanned_at', ascending: false)
                    .limit(30)
                as List,
          );
        } else {
          rethrow;
        }
      }

      final remoteToday = inspectionRows
          .map(
            (row) => _mapRemoteInspectionRow(
              row,
              sampleLabelByInspectionId: sampleLabelByInspectionId,
            ),
          )
          .where((item) => isSameWibCalendarDay(item.scannedAtUtc, nowUtc))
          .toList(growable: false);

      return SchoolDashboardData(
        school: school,
        weather: weather,
        todayInspections: _mergeInspections(
          remote: remoteToday,
          localQueued: todayLocal,
        ),
        activeSampleCount: activeSamples.length,
        nearestSampleExpiryUtc: activeSamples.isNotEmpty
            ? activeSamples.first.expiresAt.toUtc()
            : null,
        partnerKeyCached:
            cachedKey != null || (school.partnerPublicKey ?? '').isNotEmpty,
      );
    } catch (_) {
      activeSamples.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      return SchoolDashboardData(
        school: school,
        weather: weather,
        todayInspections: todayLocal,
        activeSampleCount: activeSamples.length,
        nearestSampleExpiryUtc: activeSamples.isNotEmpty
            ? activeSamples.first.expiresAt.toUtc()
            : null,
        partnerKeyCached:
            cachedKey != null || (school.partnerPublicKey ?? '').isNotEmpty,
      );
    }
  }

  @override
  Future<QrVerificationResult> verifyQrPayloadOffline({
    required String rawQrText,
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    final payload = BatchQrPayload.tryParse(rawQrText.trim());
    if (payload == null) {
      return const QrVerificationResult(
        outcome: QrVerificationOutcome.invalidFormat,
        errorTitle: 'Kode QR Tidak Dikenali',
        errorMessage:
            'Pastikan Anda memindai QR Segel Digital LacakSaji yang diterbitkan oleh Dapur SPPG mitra.',
      );
    }

    if (school.sppgId != null &&
        school.sppgId!.isNotEmpty &&
        payload.sppgId != school.sppgId) {
      return const QrVerificationResult(
        outcome: QrVerificationOutcome.foreignSppg,
        errorTitle: 'Bukan Dapur SPPG Mitra Anda',
        errorMessage:
            'QR Segel ini berasal dari dapur SPPG lain dan tidak sesuai dengan tautan sekolah Anda.',
      );
    }

    var sppgName = school.partnerKitchenName ?? 'Dapur SPPG Mitra';
    var publicKeyB64 = '';
    final sealedAtUtc = DateTime.fromMillisecondsSinceEpoch(
      payload.sealedAtEpochSec * 1000,
      isUtc: true,
    );

    if (!isOffline && _client != null) {
      await _refreshSigningKeysForSppgSafe(payload.sppgId);
    }

    final cachedKey = await _database.getSppgKey(payload.sppgId);
    if (!isOffline &&
        (school.partnerPublicKey ?? '').isNotEmpty &&
        (cachedKey == null ||
            cachedKey.publicKeyB64 != school.partnerPublicKey)) {
      publicKeyB64 = school.partnerPublicKey!;
      await _cacheSppgKeySafe(
        sppgId: payload.sppgId,
        sppgName: sppgName,
        inviteCode: school.partnerInviteCode ?? '',
        publicKeyB64: publicKeyB64,
      );
    } else if (cachedKey != null && cachedKey.publicKeyB64.isNotEmpty) {
      sppgName = cachedKey.sppgName;
      publicKeyB64 = cachedKey.publicKeyB64;
    } else if ((school.partnerPublicKey ?? '').isNotEmpty) {
      publicKeyB64 = school.partnerPublicKey!;
      await _cacheSppgKeySafe(
        sppgId: payload.sppgId,
        sppgName: sppgName,
        inviteCode: school.partnerInviteCode ?? '',
        publicKeyB64: publicKeyB64,
      );
    } else if (!isOffline && _client != null) {
      try {
        final row = await _client
            .from('sppg_kitchens')
            .select('id, name, invite_code, public_key')
            .eq('id', payload.sppgId)
            .maybeSingle();
        if (row != null) {
          sppgName = (row['name'] as String?) ?? sppgName;
          publicKeyB64 = (row['public_key'] as String?) ?? '';
          if (publicKeyB64.isNotEmpty) {
            await _cacheSppgKeySafe(
              sppgId: payload.sppgId,
              sppgName: sppgName,
              inviteCode: (row['invite_code'] as String?) ?? '',
              publicKeyB64: publicKeyB64,
            );
          }
        }
      } catch (_) {
        // Stay offline-safe below.
      }
    }

    var unknownRotatedKeyOffline = false;
    if (payload.keyId != null && payload.keyId!.isNotEmpty) {
      final keyRecord = await _database.getSigningKeyById(payload.keyId!);
      if (keyRecord != null && keyRecord.sppgId == payload.sppgId) {
        if (Ed25519Service.isRevokedForSealTime(
          status: keyRecord.status,
          revokedAtUtc: keyRecord.revokedAt,
          sealedAtUtc: sealedAtUtc,
          timestampSource: payload.timestampSource,
        )) {
          return const QrVerificationResult(
            outcome: QrVerificationOutcome.revokedKey,
            errorTitle: 'Kunci Segel Sudah Dicabut',
            errorMessage:
                'Perangkat pencetak QR ini telah dicabut aksesnya sebelum waktu segel batch atau menggunakan jam offline tidak terverifikasi. Hentikan pembagian dan hubungi Dapur SPPG.',
          );
        }
        publicKeyB64 = keyRecord.publicKeyB64;
      } else {
        unknownRotatedKeyOffline = isOffline;
        if (publicKeyB64.isEmpty) {
          final sppgKeys = await _database.getSigningKeysForSppg(payload.sppgId);
          if (sppgKeys.isNotEmpty) {
            publicKeyB64 = sppgKeys.first.publicKeyB64;
          }
        }
      }
    }

    if (publicKeyB64.isEmpty) {
      return const QrVerificationResult(
        outcome: QrVerificationOutcome.missingPublicKey,
        errorTitle: 'Kunci Verifikasi Dapur Belum Tersimpan',
        errorMessage:
            'Hubungkan HP ke internet sekali atau tekan Perbarui Data Akun di menu Profil untuk mengunduh kunci verifikasi SPPG.',
      );
    }

    var signatureValid = await _ed25519Service.verifyCanonicalPayload(
      canonicalData: payload.toCanonicalSigningString(),
      signatureB64: payload.signatureB64,
      publicKeyB64: publicKeyB64,
    );

    if (!signatureValid && unknownRotatedKeyOffline) {
      return QrVerificationResult(
        outcome: QrVerificationOutcome.missingPublicKey,
        errorTitle: 'Kunci Verifikasi Dapur Perlu Diperbarui',
        errorMessage:
            'Kunci segel baru dapur (${payload.keyId}) belum tersimpan di HP ini. Hubungkan HP ke internet sekali lalu tekan Perbarui Data Akun di menu Profil.',
      );
    }

    if (!signatureValid && !isOffline && _client != null) {
      try {
        Map<String, dynamic>? serverRow;
        try {
          serverRow = await _client
              .from('food_batches')
              .select(
                'id, sppg_id, batch_code, menu_name, risk_category, sealed_at, timestamp_source, signature_b64, signing_key_id, allergen_tags',
              )
              .eq('id', payload.batchId)
              .maybeSingle();
        } on PostgrestException catch (pgError) {
          if (pgError.code == 'PGRST204' || pgError.code == '42703') {
            serverRow = await _client
                .from('food_batches')
                .select(
                  'id, sppg_id, batch_code, menu_name, risk_category, sealed_at, timestamp_source, signature_b64',
                )
                .eq('id', payload.batchId)
                .maybeSingle();
          } else {
            rethrow;
          }
        }
        if (serverRow != null) {
          final serverKeyId = serverRow['signing_key_id'] as String?;
          if (serverKeyId != null && serverKeyId.isNotEmpty) {
            final keyCheck = await _database.getSigningKeyById(serverKeyId);
            if (keyCheck != null &&
                Ed25519Service.isRevokedForSealTime(
                  status: keyCheck.status,
                  revokedAtUtc: keyCheck.revokedAt,
                  sealedAtUtc: sealedAtUtc,
                  timestampSource: payload.timestampSource,
                )) {
              return const QrVerificationResult(
                outcome: QrVerificationOutcome.revokedKey,
                errorTitle: 'Kunci Segel Sudah Dicabut',
                errorMessage:
                    'Perangkat pencetak QR ini telah dicabut aksesnya. Hentikan pembagian dan hubungi Dapur SPPG.',
              );
            }
          }
          final serverSealed = DateTime.tryParse(
            '${serverRow['sealed_at'] ?? ''}',
          )?.toUtc();
          final serverEpoch = serverSealed == null
              ? -1
              : serverSealed.millisecondsSinceEpoch ~/ 1000;
          final rawServerAllergens = serverRow['allergen_tags'];
          final allergensMatch = rawServerAllergens == null
              ? true
              : BatchQrPayload.normalizeAllergenTags(
                    (rawServerAllergens as List).map((e) => '$e'),
                  ).join(',') ==
                  BatchQrPayload.normalizeAllergenTags(
                    payload.allergenTags,
                  ).join(',');
          signatureValid =
              serverRow['batch_code'] == payload.batchCode &&
              serverRow['sppg_id'] == payload.sppgId &&
              serverRow['menu_name'] == payload.menuName &&
              serverRow['risk_category'] == payload.riskCategory &&
              serverRow['timestamp_source'] == payload.timestampSource &&
              serverRow['signature_b64'] == payload.signatureB64 &&
              allergensMatch &&
              (serverEpoch - payload.sealedAtEpochSec).abs() <= 1;
        }
      } catch (_) {
        // Keep cryptographic failure when server verification fails.
      }
    }

    if (!signatureValid) {
      return const QrVerificationResult(
        outcome: QrVerificationOutcome.invalidSignature,
        errorTitle: 'Segel Digital Tidak Valid',
        errorMessage:
            'Segel keamanan QR tidak cocok atau data telah diubah. Jangan terima kiriman tanpa QR asli dari dapur.',
      );
    }

    final scanAtUtc = _clockUtc();
    final riskCategory = FoodRiskCategory.fromDb(payload.riskCategory);
    final timestampSource = BatchTimestampSource.fromDb(payload.timestampSource);

    final weather = await _bmkgService.getCurrentWeather(
      adm4Code: school.adm4Code,
      isOffline: isOffline,
    );

    final coords = await _locationReader();
    var gpsWithinRadius = true;
    double? distanceMeters;
    if (coords.lat != null && coords.lng != null) {
      distanceMeters = Geolocator.distanceBetween(
        school.lat,
        school.lng,
        coords.lat!,
        coords.lng!,
      );
      gpsWithinRadius = distanceMeters <= AppConstants.schoolGpsRadiusMeters;
    }

    final dangerEvaluation = DangerZoneCalculator.evaluate(
      riskCategory: riskCategory,
      sealedAtUtc: sealedAtUtc,
      scanAtUtc: scanAtUtc,
      temperatureC: weather.temperatureC,
    );

    var matchedAllergens = const <SchoolAllergenEntry>[];
    if (payload.allergenTags.isNotEmpty) {
      try {
        final localAllergens = await _database.getSchoolAllergens(school.id);
        final schoolEntries = localAllergens
            .map(SchoolAllergenEntry.fromLocalRow)
            .toList(growable: false);
        matchedAllergens = AllergenMatchWarning.intersect(
          batchAllergenTags: payload.allergenTags,
          schoolEntries: schoolEntries,
        ).matchedEntries;
      } catch (_) {
        matchedAllergens = const [];
      }
    }

    return QrVerificationResult(
      outcome: QrVerificationOutcome.valid,
      context: VerifiedBatchScanContext(
        payload: payload,
        riskCategory: riskCategory,
        timestampSource: timestampSource,
        sealedAtUtc: sealedAtUtc,
        scannedAtUtc: scanAtUtc,
        sppgName: sppgName,
        sppgPublicKeyB64: publicKeyB64,
        weather: weather,
        dangerEvaluation: dangerEvaluation,
        gpsWithinRadius: gpsWithinRadius,
        distanceMeters: distanceMeters,
        matchedAllergens: matchedAllergens,
      ),
    );
  }

  @override
  Future<SchoolInspectionItem> saveInspection({
    required SchoolProfile school,
    required VerifiedBatchScanContext scanContext,
    required CapturedWebpPhoto? samplePhoto,
    required OnDeviceVisualResult? onDeviceResult,
    required CloudVisionResult? cloudResult,
    required bool manualSmellOk,
    required bool manualVisualOk,
    required bool manualPackOk,
    required bool approved,
    required bool isOffline,
  }) async {
    final inspectionId = _uuid.v4();
    final storagePath = samplePhoto != null
        ? 'inspections/${school.id}/$inspectionId.webp'
        : null;

    final dbMap = <String, dynamic>{
      'id': inspectionId,
      'batch_id': scanContext.payload.batchId,
      'school_id': school.id,
      'scanned_at': scanContext.scannedAtUtc.toUtc().toIso8601String(),
      'elapsed_minutes': scanContext.dangerEvaluation.elapsedMinutes,
      'bmkg_temp_c': double.parse(
        scanContext.weather.temperatureC.toStringAsFixed(1),
      ),
      'bmkg_source': scanContext.weather.source.dbValue,
      if (scanContext.actualTempC != null)
        'actual_temp_celsius': double.parse(
          scanContext.actualTempC!.toStringAsFixed(1),
        ),
      'temp_source': scanContext.tempSource.dbValue,
      'danger_status': scanContext.dangerEvaluation.status.dbValue,
      'gps_within_radius': scanContext.gpsWithinRadius,
      'sample_photo_url': storagePath,
      'tflite_label': onDeviceResult?.label.dbValue,
      'tflite_confidence': onDeviceResult == null
          ? null
          : double.parse(onDeviceResult.confidence.toStringAsFixed(3)),
      'gemini_summary_json': cloudResult?.toJsonMap(),
      'manual_smell_ok': manualSmellOk,
      'manual_visual_ok': manualVisualOk,
      'manual_pack_ok': manualPackOk,
      'final_decision': approved ? 'APPROVED' : 'REJECTED',
    };

    final item = SchoolInspectionItem(
      id: inspectionId,
      batchId: scanContext.payload.batchId,
      batchCode: scanContext.payload.batchCode,
      menuName: scanContext.payload.menuName,
      schoolId: school.id,
      scannedAtUtc: scanContext.scannedAtUtc,
      elapsedMinutes: scanContext.dangerEvaluation.elapsedMinutes,
      bmkgTempC: scanContext.weather.temperatureC,
      bmkgSource: scanContext.weather.source,
      dangerStatus: scanContext.dangerEvaluation.status,
      gpsWithinRadius: scanContext.gpsWithinRadius,
      samplePhotoUrl: storagePath,
      localPhotoPath: samplePhoto?.filePath,
      tfliteLabel: onDeviceResult?.label.dbValue,
      tfliteConfidence: onDeviceResult?.confidence,
      geminiSummaryJson: cloudResult?.toJsonMap(),
      actualTempC: scanContext.actualTempC,
      tempSource: scanContext.tempSource,
      allergenTags: scanContext.payload.allergenTags,
      manualSmellOk: manualSmellOk,
      manualVisualOk: manualVisualOk,
      manualPackOk: manualPackOk,
      finalDecision: approved ? 'APPROVED' : 'REJECTED',
      isPendingSync: true,
    );

    final client = _client;
    if (isOffline || client == null) {
      await _enqueueInspectionOffline(
        dbMap: dbMap,
        scanContext: scanContext,
        localPhotoPath: samplePhoto?.filePath,
      );
      return item;
    }

    try {
      if (samplePhoto != null && storagePath != null) {
        await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
              storagePath,
              samplePhoto.bytes,
              fileOptions: const FileOptions(
                contentType: 'image/webp',
                upsert: true,
              ),
            );
      }

      final persistedId = await _saveInspectionRemote(client, dbMap);

      return SchoolInspectionItem(
        id: persistedId,
        batchId: item.batchId,
        batchCode: item.batchCode,
        menuName: item.menuName,
        schoolId: item.schoolId,
        scannedAtUtc: item.scannedAtUtc,
        elapsedMinutes: item.elapsedMinutes,
        bmkgTempC: item.bmkgTempC,
        bmkgSource: item.bmkgSource,
        dangerStatus: item.dangerStatus,
        gpsWithinRadius: item.gpsWithinRadius,
        samplePhotoUrl: item.samplePhotoUrl,
        localPhotoPath: item.localPhotoPath,
        tfliteLabel: item.tfliteLabel,
        tfliteConfidence: item.tfliteConfidence,
        geminiSummaryJson: item.geminiSummaryJson,
        actualTempC: item.actualTempC,
        tempSource: item.tempSource,
        allergenTags: item.allergenTags,
        manualSmellOk: item.manualSmellOk,
        manualVisualOk: item.manualVisualOk,
        manualPackOk: item.manualPackOk,
        finalDecision: item.finalDecision,
        isPendingSync: false,
      );
    } on SocketException {
      await _enqueueInspectionOffline(
        dbMap: dbMap,
        scanContext: scanContext,
        localPhotoPath: samplePhoto?.filePath,
      );
      return item;
    } on TimeoutException {
      await _enqueueInspectionOffline(
        dbMap: dbMap,
        scanContext: scanContext,
        localPhotoPath: samplePhoto?.filePath,
      );
      return item;
    } catch (_) {
      await _enqueueInspectionOffline(
        dbMap: dbMap,
        scanContext: scanContext,
        localPhotoPath: samplePhoto?.filePath,
      );
      return item;
    }
  }

  /// Inserts a new inspection first so fresh rows only require Postgres INSERT
  /// privileges, then updates or fetches the existing row ID on unique conflict.
  Future<String> _saveInspectionRemote(
    SupabaseClient client,
    Map<String, dynamic> dbMap,
  ) async {
    final fallbackId = dbMap['id'] as String;
    try {
      final inserted = await client
          .from('school_inspections')
          .insert(dbMap)
          .select('id')
          .maybeSingle();
      return (inserted?['id'] as String?) ?? fallbackId;
    } on PostgrestException catch (pgError) {
      if (pgError.code == 'PGRST204') {
        final legacyInsert = Map<String, dynamic>.from(dbMap)
          ..remove('actual_temp_celsius')
          ..remove('temp_source');
        return _saveInspectionRemote(client, legacyInsert);
      }
      if (pgError.code != '23505') {
        rethrow;
      }

      final batchId = dbMap['batch_id'] as String?;
      final schoolId = dbMap['school_id'] as String?;
      if (batchId == null || schoolId == null) {
        return fallbackId;
      }

      final updatePayload = Map<String, dynamic>.from(dbMap)
        ..remove('id')
        ..remove('batch_id')
        ..remove('school_id');

      try {
        final updated = await client
            .from('school_inspections')
            .update(updatePayload)
            .eq('batch_id', batchId)
            .eq('school_id', schoolId)
            .select('id')
            .maybeSingle();
        if (updated?['id'] is String) {
          return updated!['id'] as String;
        }
      } on PostgrestException catch (updateError) {
        if (updateError.code != '42501') {
          rethrow;
        }
      }

      final existing = await client
          .from('school_inspections')
          .select('id')
          .eq('batch_id', batchId)
          .eq('school_id', schoolId)
          .maybeSingle();
      return (existing?['id'] as String?) ?? fallbackId;
    }
  }

  @override
  Future<SampleVaultItem> createSampleVault({
    required SchoolProfile school,
    required String inspectionId,
    required String menuName,
    required String labelCode,
    required bool isOffline,
  }) async {
    final sampleId = _uuid.v4();
    final storedAtUtc = _clockUtc();
    final expiresAtUtc = storedAtUtc.add(AppConstants.sampleVaultRetention);

    await _database.upsertSampleVault(
      LocalSampleVaultsCompanion.insert(
        id: sampleId,
        inspectionId: inspectionId,
        schoolId: school.id,
        menuName: menuName,
        labelCode: labelCode,
        storedAt: storedAtUtc,
        expiresAt: expiresAtUtc,
        status: const Value('active'),
        isSynced: const Value(false),
        createdAt: storedAtUtc,
      ),
    );

    try {
      await _notificationService.scheduleSampleVaultReminder(
        sampleId: sampleId,
        labelCode: labelCode,
        menuName: menuName,
        expiresAtUtc: expiresAtUtc,
      );
    } catch (_) {
      // Do not fail Bank Sampel persistence if notification plugin throws.
    }

    final dbMap = <String, dynamic>{
      'id': sampleId,
      'inspection_id': inspectionId,
      'school_id': school.id,
      'label_code': labelCode,
      'stored_at': storedAtUtc.toIso8601String(),
      'expires_at': expiresAtUtc.toIso8601String(),
      'status': 'active',
    };

    var isSynced = false;
    final client = _client;
    if (!isOffline && client != null) {
      try {
        await client.from('sample_vaults').insert(dbMap);
        await _database.updateSampleVaultStatus(
          id: sampleId,
          status: 'active',
          isSynced: true,
        );
        isSynced = true;
      } catch (_) {
        await _enqueueSampleOffline(dbMap);
      }
    } else {
      await _enqueueSampleOffline(dbMap);
    }

    return SampleVaultItem(
      id: sampleId,
      inspectionId: inspectionId,
      schoolId: school.id,
      menuName: menuName,
      labelCode: labelCode,
      storedAtUtc: storedAtUtc,
      expiresAtUtc: expiresAtUtc,
      status: 'active',
      isSynced: isSynced,
    );
  }

  @override
  Stream<List<SampleVaultItem>> watchActiveSamples(String schoolId) {
    return _database.watchActiveSampleVaults(schoolId).map(
      (rows) => rows.map(_mapLocalSampleRow).toList(growable: false),
    );
  }

  @override
  Stream<List<SampleVaultItem>> watchHistorySamples(String schoolId) {
    return _database.watchHistorySampleVaults(schoolId).map(
      (rows) => rows.map(_mapLocalSampleRow).toList(growable: false),
    );
  }

  @override
  Future<void> refreshSampleVaultsFromServer(String schoolId) async {
    final client = _client;
    if (client == null) {
      return;
    }
    try {
      final rows = List<Map<String, dynamic>>.from(
        await client
                .from('sample_vaults')
                .select(
                  'id, inspection_id, school_id, label_code, stored_at, expires_at, status, '
                  'school_inspections(food_batches(menu_name))',
                )
                .eq('school_id', schoolId)
                .order('stored_at', ascending: false)
                .limit(50)
            as List,
      );

      for (final row in rows) {
        final insp = row['school_inspections'] as Map<String, dynamic>?;
        final batch = insp?['food_batches'] as Map<String, dynamic>?;
        final menuName = (batch?['menu_name'] as String?) ?? 'Sampel Makanan';
        final storedAt = DateTime.parse(row['stored_at'] as String).toUtc();

        await _database.upsertSampleVault(
          LocalSampleVaultsCompanion.insert(
            id: row['id'] as String,
            inspectionId: row['inspection_id'] as String,
            schoolId: row['school_id'] as String,
            menuName: menuName,
            labelCode: row['label_code'] as String,
            storedAt: storedAt,
            expiresAt: DateTime.parse(row['expires_at'] as String).toUtc(),
            status: Value((row['status'] as String?) ?? 'active'),
            isSynced: const Value(true),
            createdAt: storedAt,
          ),
        );
      }
    } catch (_) {
      // Keep existing local Drift copy intact offline.
    }
  }

  @override
  Future<void> markSampleDisposed({
    required String sampleId,
    required bool isOffline,
  }) async {
    await _database.updateSampleVaultStatus(
      id: sampleId,
      status: 'disposed',
      isSynced: false,
    );

    try {
      await _notificationService.cancelSampleVaultReminder(sampleId);
    } catch (_) {
      // Non-fatal.
    }

    final client = _client;
    if (!isOffline && client != null) {
      try {
        await client
            .from('sample_vaults')
            .update({'status': 'disposed'})
            .eq('id', sampleId);
        await _database.updateSampleVaultStatus(
          id: sampleId,
          status: 'disposed',
          isSynced: true,
        );
        return;
      } catch (_) {
        // Enqueue below if network failed.
      }
    }

    final nowUtc = _clockUtc();
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'update_sample_status',
        entityId: sampleId,
        payloadJson: jsonEncode({'id': sampleId, 'status': 'disposed'}),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  @override
  Future<List<SchoolBatchOption>> fetchSelectableBatchesForWaste({
    required SchoolProfile school,
    required bool isOffline,
  }) async {
    final nowUtc = _clockUtc();
    final optionsById = <String, SchoolBatchOption>{};

    // Include batches from today's or recent local queued inspections so offline flow always works.
    final localInspections = await _readLocalQueuedInspections(school.id);
    for (final insp in localInspections) {
      optionsById[insp.batchId] = SchoolBatchOption(
        batchId: insp.batchId,
        batchCode: insp.batchCode,
        menuName: insp.menuName,
        sealedAtUtc: insp.scannedAtUtc,
      );
    }

    final client = _client;
    if (!isOffline && client != null && school.sppgId != null) {
      try {
        final cutoffIso = nowUtc
            .subtract(const Duration(days: 7))
            .toUtc()
            .toIso8601String();
        final batchRows = List<Map<String, dynamic>>.from(
          await client
                  .from('food_batches')
                  .select('id, batch_code, menu_name, sealed_at')
                  .eq('sppg_id', school.sppgId!)
                  .gte('sealed_at', cutoffIso)
                  .order('sealed_at', ascending: false)
                  .limit(20)
              as List,
        );

        for (final row in batchRows) {
          final id = row['id'] as String;
          optionsById[id] = SchoolBatchOption(
            batchId: id,
            batchCode: row['batch_code'] as String,
            menuName: row['menu_name'] as String,
            sealedAtUtc: DateTime.parse(row['sealed_at'] as String).toUtc(),
          );
        }
      } catch (_) {
        // Return locally available batches on network failure.
      }
    }

    final sorted = optionsById.values.toList(growable: false);
    sorted.sort((a, b) => b.sealedAtUtc.compareTo(a.sealedAtUtc));
    return sorted;
  }

  @override
  Future<bool> submitPlateWasteLog({
    required SchoolProfile school,
    required String batchId,
    required int carbWastePct,
    required int proteinWastePct,
    required int vegWastePct,
    required List<CapturedWebpPhoto> photos,
    required bool aiAssisted,
    required bool isOffline,
  }) async {
    final sppgId = school.sppgId;
    if (sppgId == null || sppgId.isEmpty) {
      throw const AuthFriendlyException(
        'Sekolah belum tertaut dengan Dapur SPPG aktif.',
      );
    }

    final logId = _uuid.v4();
    final nowUtc = _clockUtc();
    final photoPaths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      photoPaths.add('plate_waste/${school.id}/${logId}_$i.webp');
    }

    final payloadMap = <String, dynamic>{
      'id': logId,
      'batch_id': batchId,
      'school_id': school.id,
      'sppg_id': sppgId,
      'carb_waste_pct': carbWastePct.clamp(0, 100),
      'protein_waste_pct': proteinWastePct.clamp(0, 100),
      'veg_waste_pct': vegWastePct.clamp(0, 100),
      'photo_urls': photoPaths,
      'ai_assisted': aiAssisted,
      'created_at': nowUtc.toIso8601String(),
    };

    final localFiles = photos.map((p) => p.filePath).toList(growable: false);

    final client = _client;
    if (isOffline || client == null) {
      await _enqueueWasteOffline(payloadMap, localFiles, nowUtc);
      return false;
    }

    try {
      for (var i = 0; i < photos.length; i++) {
        await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
              photoPaths[i],
              photos[i].bytes,
              fileOptions: const FileOptions(
                contentType: 'image/webp',
                upsert: true,
              ),
            );
      }

      await client.from('plate_waste_logs').insert(payloadMap);
      return true;
    } on SocketException {
      await _enqueueWasteOffline(payloadMap, localFiles, nowUtc);
      return false;
    } on TimeoutException {
      await _enqueueWasteOffline(payloadMap, localFiles, nowUtc);
      return false;
    } catch (_) {
      await _enqueueWasteOffline(payloadMap, localFiles, nowUtc);
      return false;
    }
  }

  @override
  Future<int> syncPendingSchoolQueue({required SchoolProfile school}) async {
    final client = _client;
    if (client == null) {
      return 0;
    }

    final pendingItems = await _database.getPendingSyncItems();
    var syncedCount = 0;
    final remappedInspectionIds = <String, String>{};

    for (final row in pendingItems) {
      if (row.operationType != 'create_inspection' &&
          row.operationType != 'create_sample' &&
          row.operationType != 'update_sample_status' &&
          row.operationType != 'create_waste_log') {
        continue;
      }

      try {
        final map = Map<String, dynamic>.from(
          jsonDecode(row.payloadJson) as Map,
        );
        final localPaths = (jsonDecode(row.localPhotoPathsJson) as List)
            .whereType<String>()
            .toList(growable: false);

        if ((row.operationType == 'create_inspection' ||
                row.operationType == 'create_sample' ||
                row.operationType == 'create_waste_log') &&
            map['school_id'] != school.id) {
          continue;
        }

        await _database.updateSyncItemStatus(id: row.id, status: 'syncing');

        if (row.operationType == 'create_inspection') {
          final storagePath = map['sample_photo_url'] as String?;
          if (storagePath != null && localPaths.isNotEmpty) {
            final file = File(localPaths.first);
            if (file.existsSync()) {
              await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
                    storagePath,
                    await file.readAsBytes(),
                    fileOptions: const FileOptions(
                      contentType: 'image/webp',
                      upsert: true,
                    ),
                  );
            }
          }
          map.remove('batch_code');
          map.remove('menu_name');
          final localInspectionId = map['id'] as String?;
          final persistedId = await _saveInspectionRemote(client, map);
          if (localInspectionId != null && persistedId != localInspectionId) {
            remappedInspectionIds[localInspectionId] = persistedId;
          }
        } else if (row.operationType == 'create_sample') {
          final originalInspectionId = map['inspection_id'] as String?;
          if (originalInspectionId != null &&
              remappedInspectionIds.containsKey(originalInspectionId)) {
            map['inspection_id'] = remappedInspectionIds[originalInspectionId];
          }
          try {
            await client.from('sample_vaults').insert(map);
          } on PostgrestException catch (pgError) {
            if (pgError.code != '23505') {
              rethrow;
            }
          }
          await _database.updateSampleVaultStatus(
            id: row.entityId,
            status: (map['status'] as String?) ?? 'active',
            isSynced: true,
          );
        } else if (row.operationType == 'update_sample_status') {
          await client
              .from('sample_vaults')
              .update({'status': map['status']})
              .eq('id', row.entityId);
          await _database.updateSampleVaultStatus(
            id: row.entityId,
            status: (map['status'] as String?) ?? 'disposed',
            isSynced: true,
          );
        } else if (row.operationType == 'create_waste_log') {
          final remotePaths = (map['photo_urls'] as List? ?? const [])
              .whereType<String>()
              .toList(growable: false);
          for (var i = 0; i < remotePaths.length && i < localPaths.length; i++) {
            final file = File(localPaths[i]);
            if (file.existsSync()) {
              await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
                    remotePaths[i],
                    await file.readAsBytes(),
                    fileOptions: const FileOptions(
                      contentType: 'image/webp',
                      upsert: true,
                    ),
                  );
            }
          }
          try {
            await client.from('plate_waste_logs').insert(map);
          } on PostgrestException catch (pgError) {
            if (pgError.code != '23505') {
              rethrow;
            }
          }
        }

        await _database.updateSyncItemStatus(id: row.id, status: 'synced');
        syncedCount++;
      } catch (error) {
        await _database.updateSyncItemStatus(
          id: row.id,
          status: 'failed',
          retryCount: row.retryCount + 1,
          lastError: error.toString(),
        );
      }
    }

    return syncedCount;
  }

  Future<void> _enqueueInspectionOffline({
    required Map<String, dynamic> dbMap,
    required VerifiedBatchScanContext scanContext,
    String? localPhotoPath,
  }) async {
    final nowUtc = _clockUtc();
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'create_inspection',
        entityId: dbMap['id'] as String,
        payloadJson: jsonEncode({
          ...dbMap,
          'batch_code': scanContext.payload.batchCode,
          'menu_name': scanContext.payload.menuName,
          if (scanContext.payload.allergenTags.isNotEmpty)
            'allergen_tags': scanContext.payload.allergenTags,
        }),
        localPhotoPathsJson: Value(
          jsonEncode(localPhotoPath == null ? const [] : [localPhotoPath]),
        ),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  Future<void> _enqueueSampleOffline(Map<String, dynamic> dbMap) async {
    final nowUtc = _clockUtc();
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'create_sample',
        entityId: dbMap['id'] as String,
        payloadJson: jsonEncode(dbMap),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  Future<void> _enqueueWasteOffline(
    Map<String, dynamic> payloadMap,
    List<String> localFiles,
    DateTime nowUtc,
  ) async {
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'create_waste_log',
        entityId: payloadMap['id'] as String,
        payloadJson: jsonEncode(payloadMap),
        localPhotoPathsJson: Value(jsonEncode(localFiles)),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  Future<void> _triggerWorkmanagerSafe() async {
    try {
      await _backgroundSyncScheduler?.scheduleImmediateConnectedSync();
    } catch (_) {
      // Non-fatal fallback; foreground OfflineSyncController also handles sync.
    }
  }

  Future<List<SchoolInspectionItem>> _readLocalQueuedInspections(
    String schoolId,
  ) async {
    final rows = await _database.getPendingSyncItems();
    final items = <SchoolInspectionItem>[];
    for (final row in rows) {
      if (row.operationType != 'create_inspection') {
        continue;
      }
      try {
        final map = Map<String, dynamic>.from(
          jsonDecode(row.payloadJson) as Map,
        );
        if (map['school_id'] != schoolId) {
          continue;
        }
        final localPaths = (jsonDecode(row.localPhotoPathsJson) as List)
            .whereType<String>()
            .toList(growable: false);
        items.add(
          SchoolInspectionItem(
            id: map['id'] as String,
            batchId: map['batch_id'] as String,
            batchCode: (map['batch_code'] as String?) ?? '-',
            menuName: (map['menu_name'] as String?) ?? 'Menu SPPG',
            schoolId: schoolId,
            scannedAtUtc: DateTime.parse(map['scanned_at'] as String).toUtc(),
            elapsedMinutes: (map['elapsed_minutes'] as num).toInt(),
            bmkgTempC: (map['bmkg_temp_c'] as num).toDouble(),
            bmkgSource: _bmkgSourceFromDb(map['bmkg_source'] as String?),
            dangerStatus: DangerZoneStatus.fromDb(
              map['danger_status'] as String?,
            ),
            gpsWithinRadius: (map['gps_within_radius'] as bool?) ?? true,
            samplePhotoUrl: map['sample_photo_url'] as String?,
            localPhotoPath: localPaths.isNotEmpty ? localPaths.first : null,
            tfliteLabel: map['tflite_label'] as String?,
            tfliteConfidence: (map['tflite_confidence'] as num?)?.toDouble(),
            geminiSummaryJson: map['gemini_summary_json'] is Map
                ? Map<String, dynamic>.from(
                    map['gemini_summary_json'] as Map,
                  )
                : null,
            actualTempC: (map['actual_temp_celsius'] as num?)?.toDouble(),
            tempSource: FoodTemperatureSource.fromDb(
              map['temp_source'] as String?,
            ),
            allergenTags: (map['allergen_tags'] is List)
                ? BatchQrPayload.normalizeAllergenTags(
                    (map['allergen_tags'] as List).whereType<String>(),
                  )
                : const [],
            manualSmellOk: (map['manual_smell_ok'] as bool?) ?? true,
            manualVisualOk: (map['manual_visual_ok'] as bool?) ?? true,
            manualPackOk: (map['manual_pack_ok'] as bool?) ?? true,
            finalDecision: (map['final_decision'] as String?) ?? 'APPROVED',
            isPendingSync: true,
          ),
        );
      } catch (_) {
        // Ignore malformed local row.
      }
    }
    return items;
  }

  List<SchoolInspectionItem> _mergeInspections({
    required List<SchoolInspectionItem> remote,
    required List<SchoolInspectionItem> localQueued,
  }) {
    final byBatchId = <String, SchoolInspectionItem>{};
    for (final item in remote) {
      byBatchId[item.batchId] = item;
    }
    for (final item in localQueued) {
      byBatchId.putIfAbsent(item.batchId, () => item);
    }
    final list = byBatchId.values.toList(growable: false);
    list.sort((a, b) => b.scannedAtUtc.compareTo(a.scannedAtUtc));
    return list;
  }

  SchoolInspectionItem _mapRemoteInspectionRow(
    Map<String, dynamic> row, {
    Map<String, String> sampleLabelByInspectionId = const {},
  }) {
    final inspectionId = row['id'] as String;
    final batchMeta = row['food_batches'] as Map<String, dynamic>?;
    final rawSealed = batchMeta?['sealed_at'] as String?;
    return SchoolInspectionItem(
      id: inspectionId,
      batchId: row['batch_id'] as String,
      batchCode: (batchMeta?['batch_code'] as String?) ?? '-',
      menuName: (batchMeta?['menu_name'] as String?) ?? 'Menu SPPG',
      schoolId: row['school_id'] as String,
      scannedAtUtc: DateTime.parse(row['scanned_at'] as String).toUtc(),
      sealedAtUtc:
          rawSealed != null ? DateTime.tryParse(rawSealed)?.toUtc() : null,
      elapsedMinutes: (row['elapsed_minutes'] as num).toInt(),
      bmkgTempC: (row['bmkg_temp_c'] as num).toDouble(),
      bmkgSource: _bmkgSourceFromDb(row['bmkg_source'] as String?),
      dangerStatus: DangerZoneStatus.fromDb(row['danger_status'] as String?),
      gpsWithinRadius: (row['gps_within_radius'] as bool?) ?? true,
      sampleLabelCode: sampleLabelByInspectionId[inspectionId],
      samplePhotoUrl: row['sample_photo_url'] as String?,
      tfliteLabel: row['tflite_label'] as String?,
      tfliteConfidence: (row['tflite_confidence'] as num?)?.toDouble(),
      geminiSummaryJson: row['gemini_summary_json'] is Map
          ? Map<String, dynamic>.from(row['gemini_summary_json'] as Map)
          : null,
      actualTempC: (row['actual_temp_celsius'] as num?)?.toDouble(),
      tempSource: FoodTemperatureSource.fromDb(row['temp_source'] as String?),
      allergenTags: (batchMeta?['allergen_tags'] is List)
          ? BatchQrPayload.normalizeAllergenTags(
              (batchMeta!['allergen_tags'] as List).whereType<String>(),
            )
          : const [],
      manualSmellOk: (row['manual_smell_ok'] as bool?) ?? true,
      manualVisualOk: (row['manual_visual_ok'] as bool?) ?? true,
      manualPackOk: (row['manual_pack_ok'] as bool?) ?? true,
      finalDecision: (row['final_decision'] as String?) ?? 'APPROVED',
    );
  }

  BmkgSource _bmkgSourceFromDb(String? value) {
    for (final s in BmkgSource.values) {
      if (s.dbValue == value) {
        return s;
      }
    }
    return BmkgSource.fallbackOffline;
  }

  SampleVaultItem _mapLocalSampleRow(LocalSampleVault row) {
    return SampleVaultItem(
      id: row.id,
      inspectionId: row.inspectionId,
      schoolId: row.schoolId,
      menuName: row.menuName,
      labelCode: row.labelCode,
      storedAtUtc: row.storedAt.toUtc(),
      expiresAtUtc: row.expiresAt.toUtc(),
      status: row.status,
      isSynced: row.isSynced,
    );
  }

  Future<void> _cacheSppgKeySafe({
    required String sppgId,
    required String sppgName,
    required String inviteCode,
    required String publicKeyB64,
  }) async {
    try {
      await _database.upsertSppgKey(
        LocalSppgKeysCompanion(
          sppgId: Value(sppgId),
          sppgName: Value(sppgName),
          inviteCode: Value(inviteCode),
          publicKeyB64: Value(publicKeyB64),
          updatedAt: Value(_clockUtc()),
        ),
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _refreshSigningKeysForSppgSafe(String sppgId) async {
    final client = _client;
    if (client == null || sppgId.isEmpty) {
      return;
    }
    try {
      final rows = List<Map<String, dynamic>>.from(
        await client
                .from('signing_keys')
                .select(
                  'key_id, sppg_id, public_key, status, device_label, created_at, retired_at, revoked_at',
                )
                .eq('sppg_id', sppgId)
            as List,
      );
      final now = _clockUtc();
      final companions = rows
          .where((r) => (r['key_id'] as String?)?.isNotEmpty == true)
          .map(
            (r) => LocalSigningKeysCompanion(
              keyId: Value(r['key_id'] as String),
              sppgId: Value((r['sppg_id'] as String?) ?? sppgId),
              publicKeyB64: Value((r['public_key'] as String?) ?? ''),
              status: Value((r['status'] as String?) ?? 'active'),
              deviceLabel: Value(r['device_label'] as String?),
              createdAt: Value(
                DateTime.tryParse('${r['created_at'] ?? ''}')?.toUtc() ?? now,
              ),
              retiredAt: Value(
                DateTime.tryParse('${r['retired_at'] ?? ''}')?.toUtc(),
              ),
              revokedAt: Value(
                DateTime.tryParse('${r['revoked_at'] ?? ''}')?.toUtc(),
              ),
              updatedAt: Value(now),
            ),
          )
          .toList(growable: false);
      await _database.upsertSigningKeys(companions);
    } catch (_) {
      // Non-fatal: remote table may not be migrated yet or connection unstable.
    }
  }
}

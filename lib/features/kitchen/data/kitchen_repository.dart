import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/media/live_camera_webp_service.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/domain/auth_error_mapper.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/kitchen_models.dart';

abstract class KitchenRepository {
  Future<KitchenDashboardData> fetchDashboard({required KitchenProfile kitchen});

  Future<List<PartnerSchoolItem>> fetchPartnerSchools({required String sppgId});

  Future<void> reviewSchool({
    required String sppgId,
    required String schoolId,
    required SchoolVerificationStatus decision,
  });

  Future<KitchenHistoryData> fetchHistoryAndWaste({
    required KitchenProfile kitchen,
    required HistoryTimeRange range,
  });

  Future<FoodBatchItem?> fetchBatchById({
    required KitchenProfile kitchen,
    required String batchId,
  });

  Future<FoodBatchItem> createSealedBatch({
    required KitchenProfile kitchen,
    required String menuName,
    required int portionCount,
    required FoodRiskCategory riskCategory,
    required CapturedWebpPhoto photo,
    required bool isOffline,
    List<String> allergenTags = const [],
  });

  Future<int> syncPendingKitchenBatches({required KitchenProfile kitchen});

  Future<String?> createSignedPhotoUrl(String storagePath);
}

class SupabaseKitchenRepository implements KitchenRepository {
  SupabaseKitchenRepository({
    required this._client,
    required this._database,
    required this._ed25519Service,
    this._backgroundSyncScheduler,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final SupabaseClient? _client;
  final AppDatabase _database;
  final Ed25519Service _ed25519Service;
  final BackgroundSyncScheduler? _backgroundSyncScheduler;
  final Uuid _uuid;

  DateTime? _monotonicBaseUtc;
  Stopwatch? _monotonicStopwatch;

  static const String _batchCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const AuthFriendlyException(
        'Konfigurasi server belum tersedia. Periksa koneksi dan berkas .env.',
      );
    }
    return client;
  }

  DateTime _nextMonotonicOfflineUtc() {
    final base = _monotonicBaseUtc;
    final sw = _monotonicStopwatch;
    if (base == null || sw == null) {
      final now = DateTime.now().toUtc();
      _monotonicBaseUtc = now;
      _monotonicStopwatch = Stopwatch()..start();
      return now;
    }
    return base.add(sw.elapsed);
  }

  void _updateMonotonicAnchor(DateTime authoritativeUtc) {
    _monotonicBaseUtc = authoritativeUtc.toUtc();
    _monotonicStopwatch = Stopwatch()..start();
  }

  String _generateBatchCode(DateTime sealedAtUtc) {
    final wib = toWibDateTime(sealedAtUtc);
    final yy = (wib.year % 100).toString().padLeft(2, '0');
    final mm = wib.month.toString().padLeft(2, '0');
    final dd = wib.day.toString().padLeft(2, '0');
    final suffix = List.generate(
      4,
      (_) => _batchCodeChars[_random.nextInt(_batchCodeChars.length)],
    ).join();
    return 'BCH-$yy$mm-$dd$suffix';
  }

  DateTime _rangeCutoffUtc(DateTime nowUtc, HistoryTimeRange range) {
    if (range == HistoryTimeRange.today) {
      final wib = toWibDateTime(nowUtc);
      final wibMidnight = DateTime.utc(wib.year, wib.month, wib.day);
      return wibMidnight.subtract(const Duration(hours: 7));
    }
    return nowUtc.subtract(Duration(days: range.days));
  }

  Future<List<FoodBatchItem>> _readLocalQueuedBatches(String sppgId) async {
    final rows = await _database.getPendingSyncItems();
    final batches = <FoodBatchItem>[];
    for (final row in rows) {
      if (row.operationType != 'create_batch') {
        continue;
      }
      try {
        final paths = (jsonDecode(row.localPhotoPathsJson) as List)
            .whereType<String>()
            .toList(growable: false);
        final item = FoodBatchItem.fromOfflineQueuePayload(
          row.payloadJson,
          localPhotoPath: paths.isNotEmpty ? paths.first : null,
        );
        if (item.sppgId == sppgId) {
          batches.add(item);
        }
      } catch (_) {
        // Ignore malformed local queue payload instead of blocking UI load.
      }
    }
    return batches;
  }

  List<FoodBatchItem> _mergeBatches({
    required List<FoodBatchItem> remote,
    required List<FoodBatchItem> localQueued,
  }) {
    final byId = <String, FoodBatchItem>{};
    for (final item in remote) {
      byId[item.id] = item;
    }
    for (final item in localQueued) {
      byId.putIfAbsent(item.id, () => item);
    }
    final merged = byId.values.toList(growable: false);
    merged.sort((a, b) => b.sealedAtUtc.compareTo(a.sealedAtUtc));
    return merged;
  }

  @override
  Future<KitchenDashboardData> fetchDashboard({
    required KitchenProfile kitchen,
  }) async {
    final client = _client;
    final nowUtc = DateTime.now().toUtc();
    final localBatches = await _readLocalQueuedBatches(kitchen.id);

    if (client == null) {
      final todayLocal = localBatches
          .where((b) => isSameWibCalendarDay(b.sealedAtUtc, nowUtc))
          .toList(growable: false);
      return KitchenDashboardData(
        kitchen: kitchen,
        todayBatches: todayLocal,
        todayReceivedSchoolsCount: 0,
        approvedSchoolsCount: 0,
        pendingSchoolsCount: 0,
        activeAlertsToday: const [],
        weeklyWasteSummary: PlateWasteSummary.empty,
      );
    }

    try {
      final cutoff7Days = _rangeCutoffUtc(
        nowUtc,
        HistoryTimeRange.last7Days,
      ).toIso8601String();

      final responses = await Future.wait([
        client
            .from('food_batches')
            .select(
              'id, sppg_id, batch_code, menu_name, portion_count, risk_category, '
              'sealed_at, timestamp_source, packaging_photo_url, signature_b64, created_at, '
              'school_inspections(id, school_id, danger_status, final_decision, scanned_at)',
            )
            .eq('sppg_id', kitchen.id)
            .order('sealed_at', ascending: false)
            .limit(40),
        client
            .from('schools')
            .select('id, verification_status')
            .eq('sppg_id', kitchen.id),
        _fetchDashboardClusterAlerts(client, kitchen.id),
        client
            .from('plate_waste_logs')
            .select(
              'id, batch_id, school_id, carb_waste_pct, protein_waste_pct, '
              'veg_waste_pct, ai_assisted, created_at, '
              'schools(name), food_batches(batch_code, menu_name)',
            )
            .eq('sppg_id', kitchen.id)
            .gte('created_at', cutoff7Days)
            .order('created_at', ascending: false),
      ]);

      final batchRows = List<Map<String, dynamic>>.from(responses[0] as List);
      final schoolRows = List<Map<String, dynamic>>.from(responses[1] as List);
      final alertRows = List<Map<String, dynamic>>.from(responses[2] as List);
      final wasteRows = List<Map<String, dynamic>>.from(responses[3] as List);

      final alertBatchIds = <String>{};
      final activeAlertsToday = <ActiveClusterAlertItem>[];
      for (final row in alertRows) {
        final createdAt = DateTime.parse(row['created_at'] as String).toUtc();
        final batchId = row['batch_id'] as String;
        final resolutionStatus = AlertResolutionStatus.fromDb(
          row['resolution_status'] as String?,
        );
        if (resolutionStatus != AlertResolutionStatus.clarifiedSafe) {
          alertBatchIds.add(batchId);
        }
        if (isSameWibCalendarDay(createdAt, nowUtc)) {
          final batchMeta = row['food_batches'] as Map<String, dynamic>?;
          final schoolMeta = row['schools'] as Map<String, dynamic>?;
          activeAlertsToday.add(
            ActiveClusterAlertItem(
              id: row['id'] as String,
              batchId: batchId,
              batchCode: (batchMeta?['batch_code'] as String?) ?? '-',
              menuName: (batchMeta?['menu_name'] as String?) ?? 'Menu SPPG',
              reporterSchoolId: (row['reporter_school_id'] as String?) ?? '',
              reporterSchoolName:
                  (schoolMeta?['name'] as String?) ?? 'Sekolah Mitra',
              stage: (row['stage'] as String?) ?? 'pre_consumption',
              symptomCount: (row['symptom_count'] as num?)?.toInt() ?? 0,
              createdAtUtc: createdAt,
              resolutionStatus: resolutionStatus,
              resolutionNote: row['resolution_note'] as String?,
              resolvedAtUtc: row['resolved_at'] == null
                  ? null
                  : DateTime.tryParse(row['resolved_at'] as String)?.toUtc(),
            ),
          );
        }
      }

      final remoteBatches = batchRows
          .map(
            (row) => FoodBatchItem.fromSupabaseMap(
              row,
              sppgName: kitchen.name,
              hasAnomalyReport: alertBatchIds.contains(row['id'] as String),
            ),
          )
          .toList(growable: false);

      final todayRemote = remoteBatches
          .where((b) => isSameWibCalendarDay(b.sealedAtUtc, nowUtc))
          .toList(growable: false);
      final todayLocal = localBatches
          .where((b) => isSameWibCalendarDay(b.sealedAtUtc, nowUtc))
          .toList(growable: false);
      final todayBatches = _mergeBatches(
        remote: todayRemote,
        localQueued: todayLocal,
      );

      final receivedSchoolIdsToday = <String>{};
      for (final batch in todayBatches) {
        receivedSchoolIdsToday.addAll(batch.inspectedSchoolIds);
      }

      var approvedCount = 0;
      var pendingCount = 0;
      for (final row in schoolRows) {
        final status = SchoolVerificationStatus.fromDb(
          row['verification_status'] as String?,
        );
        if (status == SchoolVerificationStatus.approved) {
          approvedCount++;
        } else if (status == SchoolVerificationStatus.pending) {
          pendingCount++;
        }
      }

      final weeklyLogs = wasteRows
          .map(_mapWasteLogRow)
          .toList(growable: false);

      return KitchenDashboardData(
        kitchen: kitchen,
        todayBatches: todayBatches,
        todayReceivedSchoolsCount: receivedSchoolIdsToday.length,
        approvedSchoolsCount: approvedCount,
        pendingSchoolsCount: pendingCount,
        activeAlertsToday: activeAlertsToday,
        weeklyWasteSummary: PlateWasteSummary.fromLogs(weeklyLogs),
      );
    } on SocketException {
      final todayLocal = localBatches
          .where((b) => isSameWibCalendarDay(b.sealedAtUtc, nowUtc))
          .toList(growable: false);
      return KitchenDashboardData(
        kitchen: kitchen,
        todayBatches: todayLocal,
        todayReceivedSchoolsCount: 0,
        approvedSchoolsCount: 0,
        pendingSchoolsCount: 0,
        activeAlertsToday: const [],
        weeklyWasteSummary: PlateWasteSummary.empty,
      );
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  @override
  Future<List<PartnerSchoolItem>> fetchPartnerSchools({
    required String sppgId,
  }) async {
    final client = _requireClient();
    final nowUtc = DateTime.now().toUtc();

    try {
      final responses = await Future.wait([
        client
            .from('schools')
            .select(
              'id, sppg_id, npsn, name, adm4_code, puskesmas_wa, '
              'verification_status, created_at',
            )
            .eq('sppg_id', sppgId)
            .order('name', ascending: true),
        client
            .from('food_batches')
            .select(
              'id, sealed_at, '
              'school_inspections(school_id, danger_status, final_decision, scanned_at)',
            )
            .eq('sppg_id', sppgId)
            .order('sealed_at', ascending: false)
            .limit(20),
        client
            .from('cluster_alerts')
            .select('reporter_school_id, created_at')
            .eq('sppg_id', sppgId)
            .order('created_at', ascending: false)
            .limit(20),
      ]);

      final schoolRows = List<Map<String, dynamic>>.from(responses[0] as List);
      final batchRows = List<Map<String, dynamic>>.from(responses[1] as List);
      final alertRows = List<Map<String, dynamic>>.from(responses[2] as List);

      final scannedSchoolsToday = <String, DateTime>{};
      final anomalySchoolsToday = <String>{};

      for (final alert in alertRows) {
        final createdAt = DateTime.parse(alert['created_at'] as String).toUtc();
        if (isSameWibCalendarDay(createdAt, nowUtc)) {
          final reporterId = alert['reporter_school_id'] as String?;
          if (reporterId != null) {
            anomalySchoolsToday.add(reporterId);
          }
        }
      }

      for (final batch in batchRows) {
        final sealedAt = DateTime.parse(batch['sealed_at'] as String).toUtc();
        if (!isSameWibCalendarDay(sealedAt, nowUtc)) {
          continue;
        }
        final inspections = batch['school_inspections'];
        if (inspections is List) {
          for (final rawInsp in inspections) {
            if (rawInsp is Map<String, dynamic>) {
              final schoolId = rawInsp['school_id'] as String?;
              final scannedAtStr = rawInsp['scanned_at'] as String?;
              if (schoolId == null) {
                continue;
              }
              if (scannedAtStr != null) {
                final scannedAt = DateTime.parse(scannedAtStr).toUtc();
                final prev = scannedSchoolsToday[schoolId];
                if (prev == null || scannedAt.isAfter(prev)) {
                  scannedSchoolsToday[schoolId] = scannedAt;
                }
              }
              final decision = rawInsp['final_decision'] as String?;
              final danger = rawInsp['danger_status'] as String?;
              if (decision == 'REJECTED' || danger == 'RED') {
                anomalySchoolsToday.add(schoolId);
              }
            }
          }
        }
      }

      return schoolRows.map((row) {
        final schoolId = row['id'] as String;
        final verification = SchoolVerificationStatus.fromDb(
          row['verification_status'] as String?,
        );
        final SchoolDailyStatus dailyStatus;
        if (anomalySchoolsToday.contains(schoolId)) {
          dailyStatus = SchoolDailyStatus.anomaly;
        } else if (scannedSchoolsToday.containsKey(schoolId)) {
          dailyStatus = SchoolDailyStatus.received;
        } else {
          dailyStatus = SchoolDailyStatus.notScanned;
        }

        return PartnerSchoolItem(
          id: schoolId,
          sppgId: (row['sppg_id'] as String?) ?? sppgId,
          npsn: row['npsn'] as String,
          name: row['name'] as String,
          adm4Code: row['adm4_code'] as String,
          puskesmasWa: row['puskesmas_wa'] as String,
          verificationStatus: verification,
          dailyStatus: dailyStatus,
          createdAtUtc: DateTime.parse(row['created_at'] as String).toUtc(),
          lastScannedAtUtc: scannedSchoolsToday[schoolId],
        );
      }).toList(growable: false);
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  @override
  Future<void> reviewSchool({
    required String sppgId,
    required String schoolId,
    required SchoolVerificationStatus decision,
  }) async {
    final client = _requireClient();
    try {
      final updated = await client
          .from('schools')
          .update({'verification_status': decision.dbValue})
          .eq('id', schoolId)
          .eq('sppg_id', sppgId)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        throw const AuthFriendlyException(
          'Data sekolah tidak ditemukan atau bukan mitra dapur Anda.',
        );
      }
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  @override
  Future<KitchenHistoryData> fetchHistoryAndWaste({
    required KitchenProfile kitchen,
    required HistoryTimeRange range,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final cutoffUtc = _rangeCutoffUtc(nowUtc, range);
    final localBatches = (await _readLocalQueuedBatches(kitchen.id))
        .where((b) => !b.sealedAtUtc.isBefore(cutoffUtc))
        .toList(growable: false);

    final client = _client;
    if (client == null) {
      return KitchenHistoryData(
        range: range,
        batches: localBatches,
        wasteLogs: const [],
        wasteSummary: PlateWasteSummary.empty,
      );
    }

    try {
      final cutoffIso = cutoffUtc.toIso8601String();
      final responses = await Future.wait([
        client
            .from('food_batches')
            .select(
              'id, sppg_id, batch_code, menu_name, portion_count, risk_category, '
              'sealed_at, timestamp_source, packaging_photo_url, signature_b64, created_at, '
              'school_inspections(id, school_id, danger_status, final_decision)',
            )
            .eq('sppg_id', kitchen.id)
            .gte('sealed_at', cutoffIso)
            .order('sealed_at', ascending: false),
        client
            .from('plate_waste_logs')
            .select(
              'id, batch_id, school_id, carb_waste_pct, protein_waste_pct, '
              'veg_waste_pct, ai_assisted, created_at, '
              'schools(name), food_batches(batch_code, menu_name)',
            )
            .eq('sppg_id', kitchen.id)
            .gte('created_at', cutoffIso)
            .order('created_at', ascending: false),
        client
            .from('cluster_alerts')
            .select('batch_id')
            .eq('sppg_id', kitchen.id)
            .gte('created_at', cutoffIso),
      ]);

      final batchRows = List<Map<String, dynamic>>.from(responses[0] as List);
      final wasteRows = List<Map<String, dynamic>>.from(responses[1] as List);
      final alertRows = List<Map<String, dynamic>>.from(responses[2] as List);

      final alertBatchIds = alertRows
          .map((row) => row['batch_id'] as String?)
          .whereType<String>()
          .toSet();

      final remoteBatches = batchRows
          .map(
            (row) => FoodBatchItem.fromSupabaseMap(
              row,
              sppgName: kitchen.name,
              hasAnomalyReport: alertBatchIds.contains(row['id'] as String),
            ),
          )
          .toList(growable: false);

      final wasteLogs = wasteRows
          .map(_mapWasteLogRow)
          .toList(growable: false);

      return KitchenHistoryData(
        range: range,
        batches: _mergeBatches(remote: remoteBatches, localQueued: localBatches),
        wasteLogs: wasteLogs,
        wasteSummary: PlateWasteSummary.fromLogs(wasteLogs),
      );
    } on SocketException {
      return KitchenHistoryData(
        range: range,
        batches: localBatches,
        wasteLogs: const [],
        wasteSummary: PlateWasteSummary.empty,
      );
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  @override
  Future<FoodBatchItem?> fetchBatchById({
    required KitchenProfile kitchen,
    required String batchId,
  }) async {
    final localBatches = await _readLocalQueuedBatches(kitchen.id);
    for (final local in localBatches) {
      if (local.id == batchId) {
        return local;
      }
    }

    final client = _client;
    if (client == null) {
      return null;
    }

    try {
      final row = await client
          .from('food_batches')
          .select(
            'id, sppg_id, batch_code, menu_name, portion_count, risk_category, '
            'sealed_at, timestamp_source, packaging_photo_url, signature_b64, created_at, '
            'school_inspections(id, school_id, danger_status, final_decision)',
          )
          .eq('id', batchId)
          .eq('sppg_id', kitchen.id)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return FoodBatchItem.fromSupabaseMap(row, sppgName: kitchen.name);
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  @override
  Future<FoodBatchItem> createSealedBatch({
    required KitchenProfile kitchen,
    required String menuName,
    required int portionCount,
    required FoodRiskCategory riskCategory,
    required CapturedWebpPhoto photo,
    required bool isOffline,
    List<String> allergenTags = const [],
  }) async {
    final client = _client;

    // 1. Lock timestamp from Supabase server UTC clock when online; monotonic fallback offline.
    var sealedAtUtc = _nextMonotonicOfflineUtc();
    var timestampSource = BatchTimestampSource.offlineUnverified;
    if (!isOffline && client != null) {
      try {
        final rawServerTime = await client
            .rpc('get_server_time')
            .timeout(const Duration(seconds: 6));
        if (rawServerTime is String) {
          final parsed = DateTime.parse(rawServerTime).toUtc();
          sealedAtUtc = parsed;
          timestampSource = BatchTimestampSource.serverVerified;
          _updateMonotonicAnchor(parsed);
        }
      } catch (_) {
        timestampSource = BatchTimestampSource.offlineUnverified;
      }
    }

    // 2. Ensure Ed25519 private key & deterministic key_id exist locally & sync if online.
    var activeMaterial = await _ed25519Service.getOrCreateActiveKeyMaterial(
      sppgId: kitchen.id,
      legacyUserId: kitchen.ownerUserId,
    );
    if (!isOffline && client != null) {
      try {
        await client.from('signing_keys').upsert({
          'key_id': activeMaterial.keyId,
          'sppg_id': kitchen.id,
          'public_key': activeMaterial.publicKeyB64,
          'status': 'active',
          'device_label': 'Perangkat Dapur SPPG',
        });
      } catch (_) {
        // Ignore if signing_keys waits on migration or duplicate key.
      }
      if (kitchen.publicKey != activeMaterial.publicKeyB64) {
        try {
          await client
              .from('sppg_kitchens')
              .update({'public_key': activeMaterial.publicKeyB64})
              .eq('id', kitchen.id);
        } catch (_) {
          // Non-admin kitchen staff do not overwrite primary sppg_kitchens.public_key.
        }
      }
    }

    await _cachePublicKeyInDrift(
      kitchen: kitchen,
      publicKeyB64: activeMaterial.publicKeyB64,
      keyId: activeMaterial.keyId,
    );

    // 3. Build batch identity & Ed25519 cryptographic signature paired with key_id.
    final batchId = _uuid.v4();
    final batchCode = _generateBatchCode(sealedAtUtc);
    final cleanMenu = menuName.trim();
    final sealedEpochSec = sealedAtUtc.millisecondsSinceEpoch ~/ 1000;
    final alignedSealedUtc = DateTime.fromMillisecondsSinceEpoch(
      sealedEpochSec * 1000,
      isUtc: true,
    );

    final cleanAllergens = BatchQrPayload.normalizeAllergenTags(allergenTags);
    final signed = await _ed25519Service.signBatchWithKeyId(
      sppgId: kitchen.id,
      legacyUserId: kitchen.ownerUserId,
      buildCanonicalForKeyId: (keyId) =>
          BatchQrPayload.buildCanonicalSigningString(
            batchId: batchId,
            batchCode: batchCode,
            sppgId: kitchen.id,
            menuName: cleanMenu,
            riskCategory: riskCategory.dbValue,
            sealedAtEpochSec: sealedEpochSec,
            timestampSource: timestampSource.dbValue,
            keyId: keyId,
            allergenTags: cleanAllergens,
          ),
    );
    activeMaterial = SppgSigningKeyMaterial(
      keyId: signed.keyId,
      publicKeyB64: signed.publicKeyB64,
    );

    final storagePath = 'batches/${kitchen.id}/$batchId.webp';

    final batch = FoodBatchItem(
      id: batchId,
      sppgId: kitchen.id,
      sppgName: kitchen.name,
      batchCode: batchCode,
      menuName: cleanMenu,
      portionCount: portionCount,
      riskCategory: riskCategory,
      sealedAtUtc: alignedSealedUtc,
      timestampSource: timestampSource,
      signingKeyId: activeMaterial.keyId,
      allergenTags: cleanAllergens,
      packagingPhotoUrl: storagePath,
      localPhotoPath: photo.filePath,
      signatureB64: signed.signatureB64,
      createdAtUtc: alignedSealedUtc,
      isPendingSync: false,
    );

    if (isOffline || client == null) {
      await _enqueueBatchOffline(batch: batch, localPhotoPath: photo.filePath);
      return FoodBatchItem(
        id: batch.id,
        sppgId: batch.sppgId,
        sppgName: batch.sppgName,
        batchCode: batch.batchCode,
        menuName: batch.menuName,
        portionCount: batch.portionCount,
        riskCategory: batch.riskCategory,
        sealedAtUtc: batch.sealedAtUtc,
        timestampSource: batch.timestampSource,
        signingKeyId: batch.signingKeyId,
        allergenTags: batch.allergenTags,
        packagingPhotoUrl: batch.packagingPhotoUrl,
        localPhotoPath: batch.localPhotoPath,
        signatureB64: batch.signatureB64,
        createdAtUtc: batch.createdAtUtc,
        isPendingSync: true,
      );
    }

    try {
      await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
            storagePath,
            photo.bytes,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: true,
            ),
          );

      final insertMap = batch.toDbInsertMap();
      try {
        await client.from('food_batches').insert(insertMap);
      } on PostgrestException catch (pgError) {
        if (pgError.code == 'PGRST204' ||
            pgError.message.toLowerCase().contains('signing_key_id') ||
            pgError.message.toLowerCase().contains('allergen_tags')) {
          final legacyMap = Map<String, dynamic>.from(insertMap)
            ..remove('signing_key_id')
            ..remove('allergen_tags');
          await client.from('food_batches').insert(legacyMap);
        } else {
          rethrow;
        }
      }
      return batch;
    } on SocketException {
      await _enqueueBatchOffline(batch: batch, localPhotoPath: photo.filePath);
      return FoodBatchItem(
        id: batch.id,
        sppgId: batch.sppgId,
        sppgName: batch.sppgName,
        batchCode: batch.batchCode,
        menuName: batch.menuName,
        portionCount: batch.portionCount,
        riskCategory: batch.riskCategory,
        sealedAtUtc: batch.sealedAtUtc,
        timestampSource: batch.timestampSource,
        signingKeyId: batch.signingKeyId,
        allergenTags: batch.allergenTags,
        packagingPhotoUrl: batch.packagingPhotoUrl,
        localPhotoPath: batch.localPhotoPath,
        signatureB64: batch.signatureB64,
        createdAtUtc: batch.createdAtUtc,
        isPendingSync: true,
      );
    } on TimeoutException {
      await _enqueueBatchOffline(batch: batch, localPhotoPath: photo.filePath);
      return FoodBatchItem(
        id: batch.id,
        sppgId: batch.sppgId,
        sppgName: batch.sppgName,
        batchCode: batch.batchCode,
        menuName: batch.menuName,
        portionCount: batch.portionCount,
        riskCategory: batch.riskCategory,
        sealedAtUtc: batch.sealedAtUtc,
        timestampSource: batch.timestampSource,
        signingKeyId: batch.signingKeyId,
        allergenTags: batch.allergenTags,
        packagingPhotoUrl: batch.packagingPhotoUrl,
        localPhotoPath: batch.localPhotoPath,
        signatureB64: batch.signatureB64,
        createdAtUtc: batch.createdAtUtc,
        isPendingSync: true,
      );
    } catch (error) {
      throw AuthFriendlyException(AuthErrorMapper.mapException(error));
    }
  }

  @override
  Future<int> syncPendingKitchenBatches({
    required KitchenProfile kitchen,
  }) async {
    final client = _client;
    if (client == null) {
      return 0;
    }

    await _database.recoverStuckSyncingItems();
    final pendingRows = await _database.getPendingSyncItems();
    final batchRows = pendingRows
        .where((row) => row.operationType == 'create_batch')
        .toList(growable: false);
    if (batchRows.isEmpty) {
      return 0;
    }

    await _ed25519Service.ensureKeyPairSynced(
      sppgId: kitchen.id,
      remotePublicKeyB64: kitchen.publicKey,
      legacyUserId: kitchen.ownerUserId,
      onSyncRemotePublicKey: (publicKeyB64) async {
        await client
            .from('sppg_kitchens')
            .update({'public_key': publicKeyB64})
            .eq('id', kitchen.id)
            .eq('owner_user_id', kitchen.ownerUserId);
      },
    );

    var syncedCount = 0;
    for (final row in batchRows) {
      try {
        final rawPayload = Map<String, dynamic>.from(
          jsonDecode(row.payloadJson) as Map,
        );
        if (rawPayload['sppg_id'] != kitchen.id) {
          continue;
        }

        await _database.updateSyncItemStatus(
          id: row.id,
          status: 'syncing',
        );

        final storagePath = rawPayload['packaging_photo_url'] as String?;
        final paths = (jsonDecode(row.localPhotoPathsJson) as List)
            .whereType<String>()
            .toList(growable: false);
        if (storagePath != null && paths.isNotEmpty) {
          final file = File(paths.first);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
                  storagePath,
                  bytes,
                  fileOptions: const FileOptions(
                    contentType: 'image/webp',
                    upsert: true,
                  ),
                );
          }
        }

        rawPayload.remove('sppg_name');
        try {
          await client.from('food_batches').insert(rawPayload);
        } on PostgrestException catch (pgError) {
          // Treat duplicate batch ID/code on retry as already synced.
          if (pgError.code != '23505') {
            rethrow;
          }
        }

        await _database.updateSyncItemStatus(
          id: row.id,
          status: 'synced',
        );
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

  @override
  Future<String?> createSignedPhotoUrl(String storagePath) async {
    final client = _client;
    if (client == null || storagePath.isEmpty) {
      return null;
    }
    try {
      return await client.storage
          .from(AppConstants.auditPhotosBucket)
          .createSignedUrl(storagePath, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _enqueueBatchOffline({
    required FoodBatchItem batch,
    required String localPhotoPath,
  }) async {
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'create_batch',
        entityId: batch.id,
        payloadJson: batch.toOfflineQueuePayloadJson(),
        localPhotoPathsJson: Value(jsonEncode([localPhotoPath])),
        status: const Value('pending'),
        createdAt: batch.createdAtUtc,
        updatedAt: batch.createdAtUtc,
      ),
    );
    try {
      await _backgroundSyncScheduler?.scheduleImmediateConnectedSync();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchDashboardClusterAlerts(
    SupabaseClient client,
    String sppgId,
  ) async {
    try {
      final rows = await client
          .from('cluster_alerts')
          .select(
            'id, batch_id, reporter_school_id, stage, symptom_count, '
            'resolution_status, resolution_note, resolved_at, created_at, '
            'food_batches(batch_code, menu_name), '
            'schools(name)',
          )
          .eq('sppg_id', sppgId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (pgError) {
      if (pgError.code == 'PGRST204' || pgError.code == '42703') {
        final rows = await client
            .from('cluster_alerts')
            .select(
              'id, batch_id, stage, symptom_count, created_at, '
              'food_batches(batch_code, menu_name), '
              'schools(name)',
            )
            .eq('sppg_id', sppgId)
            .order('created_at', ascending: false)
            .limit(20);
        return List<Map<String, dynamic>>.from(rows as List);
      }
      rethrow;
    }
  }

  Future<void> _cachePublicKeyInDrift({
    required KitchenProfile kitchen,
    required String publicKeyB64,
    String? keyId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      await _database.upsertSppgKey(
        LocalSppgKeysCompanion(
          sppgId: Value(kitchen.id),
          sppgName: Value(kitchen.name),
          inviteCode: Value(kitchen.inviteCode),
          publicKeyB64: Value(publicKeyB64),
          updatedAt: Value(now),
        ),
      );
      if (keyId != null && keyId.isNotEmpty) {
        await _database.upsertSigningKey(
          LocalSigningKeysCompanion(
            keyId: Value(keyId),
            sppgId: Value(kitchen.id),
            publicKeyB64: Value(publicKeyB64),
            status: const Value('active'),
            deviceLabel: const Value('Perangkat Dapur SPPG'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    } catch (_) {
      // Do not fail batch creation if local cache upsert fails.
    }
  }

  PlateWasteLogItem _mapWasteLogRow(Map<String, dynamic> row) {
    final schoolMeta = row['schools'] as Map<String, dynamic>?;
    final batchMeta = row['food_batches'] as Map<String, dynamic>?;
    return PlateWasteLogItem(
      id: row['id'] as String,
      batchId: row['batch_id'] as String,
      batchCode: (batchMeta?['batch_code'] as String?) ?? '-',
      menuName: (batchMeta?['menu_name'] as String?) ?? 'Menu SPPG',
      schoolId: row['school_id'] as String,
      schoolName: (schoolMeta?['name'] as String?) ?? 'Sekolah Mitra',
      carbWastePct: (row['carb_waste_pct'] as num).toInt(),
      proteinWastePct: (row['protein_waste_pct'] as num).toInt(),
      vegWastePct: (row['veg_waste_pct'] as num).toInt(),
      aiAssisted: (row['ai_assisted'] as bool?) ?? false,
      createdAtUtc: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }
}

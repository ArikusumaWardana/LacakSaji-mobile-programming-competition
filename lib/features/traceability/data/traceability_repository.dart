import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/batch_qr_payload.dart';
import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/domain/auth_models.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/traceability_models.dart';

abstract class TraceabilityRepository {
  Future<List<IngredientLogItem>> saveIngredientLogsForBatch({
    required KitchenProfile kitchen,
    required FoodBatchItem batch,
    required List<IngredientLogDraft> drafts,
    required bool isOffline,
    String? createdByUserId,
  });

  Future<List<IngredientLogItem>> fetchIngredientLogsByBatch({
    required String sppgId,
    required String batchId,
  });

  Future<List<IngredientLogItem>> fetchIngredientHistoryBySppg({
    required String sppgId,
  });

  Future<List<FoodBatchItem>> fetchRecentKitchenBatches({
    required KitchenProfile kitchen,
    int days = 3,
  });

  Future<List<CourierBatchDeliveryItem>> fetchCourierDeliveries({
    required KitchenProfile kitchen,
  });

  Future<TransitHandoverItem> recordCourierScan({
    required KitchenProfile kitchen,
    required UserProfile actor,
    required BatchQrPayload qrPayload,
    required CourierScanMode mode,
    required bool isOffline,
    String? schoolId,
    String? schoolName,
    double? lat,
    double? lng,
    String? notes,
  });

  Future<SupplyChainTimelineData> fetchSupplyChainTimeline({
    required String sppgId,
    required String batchId,
    required DateTime sealedAtUtc,
    DateTime? schoolScannedAtUtc,
    String? schoolId,
  });

  Future<TrayReturnLogItem> submitSchoolTrayReturn({
    required SchoolProfile school,
    required String batchId,
    required String batchCode,
    required String menuName,
    required int traysSent,
    required int traysReturned,
    required bool isOffline,
    String? notes,
  });

  Future<List<TrayReturnLogItem>> fetchSchoolTrayReturns({
    required String schoolId,
  });

  Future<List<TrayReturnLogItem>> fetchKitchenTrayReturns({
    required String sppgId,
  });

  Future<TrayReturnLogItem> verifyKitchenTrayReturnAndSanitation({
    required String sppgId,
    required TrayReturnLogItem item,
    required int verifiedReturnedCount,
    required TraySanitationChecklist checklist,
    required bool isOffline,
    String? verifierUserId,
    String? notes,
  });

  Future<int> syncPendingTraceabilityQueue({
    String? sppgId,
    String? schoolId,
    Set<String>? operationTypes,
  });
}

class SupabaseTraceabilityRepository implements TraceabilityRepository {
  SupabaseTraceabilityRepository({
    required this._client,
    required this._database,
    this._backgroundSyncScheduler,
    Ed25519Service? ed25519Service,
    Uuid? uuid,
  }) : _ed25519Service = ed25519Service ?? Ed25519Service(),
       _uuid = uuid ?? const Uuid();

  final SupabaseClient? _client;
  final AppDatabase _database;
  final BackgroundSyncScheduler? _backgroundSyncScheduler;
  final Ed25519Service _ed25519Service;
  final Uuid _uuid;

  static const Set<String> _traceabilityOperationTypes = {
    'create_ingredient_log',
    'upsert_transit_handover',
    'create_tray_return',
    'update_tray_return_sanitation',
  };

  @override
  Future<List<IngredientLogItem>> saveIngredientLogsForBatch({
    required KitchenProfile kitchen,
    required FoodBatchItem batch,
    required List<IngredientLogDraft> drafts,
    required bool isOffline,
    String? createdByUserId,
  }) async {
    if (drafts.isEmpty) {
      return const [];
    }
    final nowUtc = DateTime.now().toUtc();
    final saved = <IngredientLogItem>[];

    for (final draft in drafts) {
      final id = _uuid.v4();
      final item = IngredientLogItem(
        id: id,
        batchId: batch.id,
        batchCode: batch.batchCode,
        menuName: batch.menuName,
        sppgId: kitchen.id,
        ingredientName: draft.ingredientName.trim(),
        supplierName: draft.supplierName.trim(),
        supplierBatchNo: draft.supplierBatchNo.trim(),
        expiryDate: DateTime(
          draft.expiryDate.year,
          draft.expiryDate.month,
          draft.expiryDate.day,
        ),
        receivedAtUtc: nowUtc,
        notes: draft.notes?.trim().isEmpty == true ? null : draft.notes?.trim(),
        createdBy: createdByUserId,
        createdAtUtc: nowUtc,
        isPendingSync: isOffline || _client == null,
      );

      var synced = false;
      final client = _client;
      if (!isOffline && client != null) {
        try {
          await client.from('ingredient_logs').insert(item.toDbInsertMap());
          synced = true;
        } on PostgrestException catch (error) {
          if (error.code == '23505') {
            synced = true;
          }
        } catch (_) {
          synced = false;
        }
      }

      await _database.upsertTraceabilityDraft(
        LocalTraceabilityDraftsCompanion(
          id: Value(id),
          recordType: const Value('ingredient_log'),
          institutionId: Value(kitchen.id),
          batchId: Value(batch.id),
          payloadJson: Value(jsonEncode(item.toLocalDraftMap())),
          isSynced: Value(synced),
          createdAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
        ),
      );

      if (!synced) {
        await _database.enqueueSyncItem(
          LocalSyncQueueCompanion(
            entityId: Value(id),
            operationType: const Value('create_ingredient_log'),
            payloadJson: Value(jsonEncode(item.toLocalDraftMap())),
            localPhotoPathsJson: const Value('[]'),
            createdAt: Value(nowUtc),
            updatedAt: Value(nowUtc),
          ),
        );
        await _scheduleSync();
      }

      saved.add(
        synced
            ? IngredientLogItem(
                id: item.id,
                batchId: item.batchId,
                batchCode: item.batchCode,
                menuName: item.menuName,
                sppgId: item.sppgId,
                ingredientName: item.ingredientName,
                supplierName: item.supplierName,
                supplierBatchNo: item.supplierBatchNo,
                expiryDate: item.expiryDate,
                receivedAtUtc: item.receivedAtUtc,
                notes: item.notes,
                createdBy: item.createdBy,
                createdAtUtc: item.createdAtUtc,
                isPendingSync: false,
              )
            : item,
      );
    }

    return saved;
  }

  @override
  Future<List<IngredientLogItem>> fetchIngredientLogsByBatch({
    required String sppgId,
    required String batchId,
  }) async {
    final localRows = await _database.getTraceabilityDrafts(
      recordType: 'ingredient_log',
      batchId: batchId,
    );
    final byId = <String, IngredientLogItem>{};
    for (final row in localRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded != null) {
        final item = IngredientLogItem.fromMap(
          decoded,
          isPendingSync: !row.isSynced,
        );
        if (item.id.isNotEmpty) {
          byId[item.id] = item;
        }
      }
    }

    final client = _client;
    if (client != null) {
      try {
        final remoteRows = await _selectIngredientLogs(
          client: client,
          sppgId: sppgId,
          batchId: batchId,
        );
        for (final row in remoteRows) {
          final remoteItem = IngredientLogItem.fromMap(row);
          if (remoteItem.id.isNotEmpty) {
            final existing = byId[remoteItem.id];
            if (existing == null || !existing.isPendingSync) {
              byId[remoteItem.id] = remoteItem;
            }
          }
        }
      } catch (_) {
        // Fallback silently to local Drift cache when offline or unmigrated.
      }
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return result;
  }

  @override
  Future<List<IngredientLogItem>> fetchIngredientHistoryBySppg({
    required String sppgId,
  }) async {
    final localRows = await _database.getTraceabilityDrafts(
      recordType: 'ingredient_log',
      institutionId: sppgId,
    );
    final byId = <String, IngredientLogItem>{};
    for (final row in localRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded != null) {
        final item = IngredientLogItem.fromMap(
          decoded,
          isPendingSync: !row.isSynced,
        );
        if (item.id.isNotEmpty) {
          byId[item.id] = item;
        }
      }
    }

    final client = _client;
    if (client != null) {
      try {
        final remoteRows = await _selectIngredientLogs(
          client: client,
          sppgId: sppgId,
        );
        for (final row in remoteRows) {
          final remoteItem = IngredientLogItem.fromMap(row);
          if (remoteItem.id.isNotEmpty) {
            final existing = byId[remoteItem.id];
            if (existing == null || !existing.isPendingSync) {
              byId[remoteItem.id] = remoteItem;
            }
          }
        }
      } catch (_) {
        // Preserve offline-cached logs.
      }
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return result;
  }

  Future<List<Map<String, dynamic>>> _selectIngredientLogs({
    required SupabaseClient client,
    required String sppgId,
    String? batchId,
  }) async {
    try {
      var query = client
          .from('ingredient_logs')
          .select('*, food_batches(batch_code, menu_name)')
          .eq('sppg_id', sppgId);
      if (batchId != null) {
        query = query.eq('batch_id', batchId);
      }
      return List<Map<String, dynamic>>.from(
        await query.order('created_at', ascending: false).limit(120) as List,
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST200' || error.code == 'PGRST204') {
        var fallback = client
            .from('ingredient_logs')
            .select()
            .eq('sppg_id', sppgId);
        if (batchId != null) {
          fallback = fallback.eq('batch_id', batchId);
        }
        return List<Map<String, dynamic>>.from(
          await fallback.order('created_at', ascending: false).limit(120)
              as List,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<FoodBatchItem>> fetchRecentKitchenBatches({
    required KitchenProfile kitchen,
    int days = 3,
  }) async {
    final sinceUtc = DateTime.now().toUtc().subtract(Duration(days: days));
    final byId = <String, FoodBatchItem>{};

    final pendingRows = await _database.getPendingSyncItems();
    for (final row in pendingRows) {
      if (row.operationType != 'create_batch') {
        continue;
      }
      final decoded = _decodeMap(row.payloadJson);
      if (decoded == null || decoded['sppg_id'] != kitchen.id) {
        continue;
      }
      final photoPaths = _decodeStringList(row.localPhotoPathsJson);
      final localBatch = FoodBatchItem.fromOfflineQueuePayload(
        row.payloadJson,
        localPhotoPath: photoPaths.isNotEmpty ? photoPaths.first : null,
      );
      byId[localBatch.id] = localBatch;
    }

    final client = _client;
    if (client != null) {
      try {
        List<Map<String, dynamic>> rows;
        try {
          rows = List<Map<String, dynamic>>.from(
            await client
                    .from('food_batches')
                    .select(
                      'id, sppg_id, batch_code, menu_name, portion_count, risk_category, sealed_at, timestamp_source, signing_key_id, allergen_tags, packaging_photo_url, signature_b64, created_at',
                    )
                    .eq('sppg_id', kitchen.id)
                    .gte('sealed_at', sinceUtc.toIso8601String())
                    .order('sealed_at', ascending: false)
                    .limit(60)
                as List,
          );
        } on PostgrestException catch (pgError) {
          if (pgError.code == 'PGRST204' || pgError.code == '42703') {
            rows = List<Map<String, dynamic>>.from(
              await client
                      .from('food_batches')
                      .select(
                        'id, sppg_id, batch_code, menu_name, portion_count, risk_category, sealed_at, timestamp_source, signing_key_id, packaging_photo_url, signature_b64, created_at',
                      )
                      .eq('sppg_id', kitchen.id)
                      .gte('sealed_at', sinceUtc.toIso8601String())
                      .order('sealed_at', ascending: false)
                      .limit(60)
                  as List,
            );
          } else {
            rethrow;
          }
        }
        for (final row in rows) {
          final remoteBatch = FoodBatchItem.fromSupabaseMap(
            row,
            sppgName: kitchen.name,
          );
          byId.putIfAbsent(remoteBatch.id, () => remoteBatch);
        }
      } catch (_) {
        // Offline or unreachable server: keep pending local batches.
      }
    }

    final list = byId.values.toList()
      ..sort((a, b) => b.sealedAtUtc.compareTo(a.sealedAtUtc));
    return list;
  }

  @override
  Future<List<CourierBatchDeliveryItem>> fetchCourierDeliveries({
    required KitchenProfile kitchen,
  }) async {
    final batches = await fetchRecentKitchenBatches(
      kitchen: kitchen,
      days: 3,
    );
    final handoversById = <String, TransitHandoverItem>{};

    final localRows = await _database.getTraceabilityDrafts(
      recordType: 'transit_handover',
      institutionId: kitchen.id,
    );
    for (final row in localRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded == null) {
        continue;
      }
      final item = TransitHandoverItem.fromMap(
        decoded,
        isPendingSync: !row.isSynced,
      );
      if (item.batchId.isNotEmpty && item.id.isNotEmpty) {
        handoversById[item.id] = item;
      }
    }

    final client = _client;
    if (client != null) {
      try {
        final remoteRows = await _selectTransitHandovers(
          client: client,
          sppgId: kitchen.id,
        );
        for (final row in remoteRows) {
          final remoteItem = TransitHandoverItem.fromMap(row);
          if (remoteItem.batchId.isNotEmpty && remoteItem.id.isNotEmpty) {
            final existing = handoversById[remoteItem.id];
            if (existing == null || !existing.isPendingSync) {
              handoversById[remoteItem.id] = remoteItem;
            }
          }
        }
      } catch (_) {
        // Fallback gracefully to local drafts.
      }
    }

    final handoversByBatchId = <String, List<TransitHandoverItem>>{};
    for (final h in handoversById.values) {
      (handoversByBatchId[h.batchId] ??= <TransitHandoverItem>[]).add(h);
    }
    for (final list in handoversByBatchId.values) {
      list.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    }

    // Include one delivery tile per multi-school handover (or one ready tile if none loaded yet).
    final seenBatchIds = <String>{};
    final result = <CourierBatchDeliveryItem>[];
    for (final batch in batches) {
      seenBatchIds.add(batch.id);
      final batchHandovers = handoversByBatchId[batch.id];
      if (batchHandovers == null || batchHandovers.isEmpty) {
        result.add(
          CourierBatchDeliveryItem(
            batch: batch,
            handover: null,
          ),
        );
      } else {
        for (final h in batchHandovers) {
          result.add(
            CourierBatchDeliveryItem(
              batch: batch,
              handover: h,
            ),
          );
        }
      }
    }

    for (final entry in handoversByBatchId.entries) {
      if (seenBatchIds.contains(entry.key)) {
        continue;
      }
      for (final h in entry.value) {
        result.add(
          CourierBatchDeliveryItem(
            batch: FoodBatchItem(
              id: h.batchId,
              sppgId: h.sppgId,
              sppgName: kitchen.name,
              batchCode:
                  h.batchCode ?? h.batchId.substring(0, 8).toUpperCase(),
              menuName: h.menuName ?? 'Batch Pengiriman SPPG',
              portionCount: 0,
              riskCategory: FoodRiskCategory.medium,
              sealedAtUtc: h.loadedAtUtc,
              timestampSource: BatchTimestampSource.offlineUnverified,
              signatureB64: '',
              createdAtUtc: h.createdAtUtc,
              isPendingSync: h.isPendingSync,
            ),
            handover: h,
          ),
        );
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _selectTransitHandovers({
    required SupabaseClient client,
    required String sppgId,
    String? batchId,
  }) async {
    try {
      var query = client
          .from('transit_handovers')
          .select('*, schools(name), food_batches(batch_code, menu_name)')
          .eq('sppg_id', sppgId);
      if (batchId != null) {
        query = query.eq('batch_id', batchId);
      }
      return List<Map<String, dynamic>>.from(
        await query.order('created_at', ascending: false).limit(100) as List,
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST200' || error.code == 'PGRST204') {
        var fallback = client
            .from('transit_handovers')
            .select()
            .eq('sppg_id', sppgId);
        if (batchId != null) {
          fallback = fallback.eq('batch_id', batchId);
        }
        return List<Map<String, dynamic>>.from(
          await fallback.order('created_at', ascending: false).limit(100)
              as List,
        );
      }
      rethrow;
    }
  }

  bool _isValidEd25519PublicKeyB64(String b64) {
    if (b64.trim().isEmpty) {
      return false;
    }
    try {
      return base64Decode(b64.trim()).length == 32;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyCourierQrSignature({
    required KitchenProfile kitchen,
    required BatchQrPayload qrPayload,
  }) async {
    final sealedAtUtc = DateTime.fromMillisecondsSinceEpoch(
      qrPayload.sealedAtEpochSec * 1000,
      isUtc: true,
    );
    String publicKeyB64 = kitchen.publicKey;
    final keyId = qrPayload.keyId;
    if (keyId != null && keyId.isNotEmpty) {
      final keyRecord = await _database.getSigningKeyById(keyId);
      if (keyRecord != null && keyRecord.sppgId == kitchen.id) {
        if (Ed25519Service.isRevokedForSealTime(
          status: keyRecord.status,
          revokedAtUtc: keyRecord.revokedAt,
          sealedAtUtc: sealedAtUtc,
          timestampSource: qrPayload.timestampSource,
        )) {
          throw const FormatException(
            'Kunci segel QR ini telah dicabut oleh Admin SPPG. Hentikan pengantaran dan verifikasi ulang dengan Dapur SPPG.',
          );
        }
        publicKeyB64 = keyRecord.publicKeyB64;
      }
    }

    if (!_isValidEd25519PublicKeyB64(publicKeyB64)) {
      final cachedSppg = await _database.getSppgKey(kitchen.id);
      if (cachedSppg != null &&
          _isValidEd25519PublicKeyB64(cachedSppg.publicKeyB64)) {
        publicKeyB64 = cachedSppg.publicKeyB64;
      }
    }

    if (_isValidEd25519PublicKeyB64(publicKeyB64)) {
      final valid = await _ed25519Service.verifyCanonicalPayload(
        canonicalData: qrPayload.toCanonicalSigningString(),
        signatureB64: qrPayload.signatureB64,
        publicKeyB64: publicKeyB64,
      );
      if (!valid) {
        throw const FormatException(
          'Tanda tangan digital QR segel tidak valid atau data telah diubah. Pastikan QR asli dari Dapur SPPG.',
        );
      }
    }
  }

  @override
  Future<TransitHandoverItem> recordCourierScan({
    required KitchenProfile kitchen,
    required UserProfile actor,
    required BatchQrPayload qrPayload,
    required CourierScanMode mode,
    required bool isOffline,
    String? schoolId,
    String? schoolName,
    double? lat,
    double? lng,
    String? notes,
  }) async {
    if (qrPayload.sppgId != kitchen.id) {
      throw const FormatException(
        'QR Segel ini berasal dari Dapur SPPG lain dan tidak dapat dipindai oleh kurir SPPG ini.',
      );
    }

    await _verifyCourierQrSignature(kitchen: kitchen, qrPayload: qrPayload);

    final existingById = <String, TransitHandoverItem>{};
    final existingList = await _database.getTraceabilityDrafts(
      recordType: 'transit_handover',
      batchId: qrPayload.batchId,
    );
    for (final row in existingList) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded != null) {
        final parsed = TransitHandoverItem.fromMap(
          decoded,
          isPendingSync: !row.isSynced,
        );
        if (parsed.id.isNotEmpty) {
          existingById[parsed.id] = parsed;
        }
      }
    }
    if (!isOffline && _client != null) {
      try {
        final rows = await _selectTransitHandovers(
          client: _client,
          sppgId: kitchen.id,
          batchId: qrPayload.batchId,
        );
        for (final row in rows) {
          final remote = TransitHandoverItem.fromMap(row);
          if (remote.id.isNotEmpty) {
            final local = existingById[remote.id];
            if (local == null || !local.isPendingSync) {
              existingById[remote.id] = remote;
            }
          }
        }
      } catch (_) {
        // Ignore network errors during pre-check.
      }
    }

    final existingHandovers = existingById.values.toList()
      ..sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));

    final nowUtc = DateTime.now().toUtc();
    final cleanSchoolId = schoolId?.trim().isEmpty == true
        ? null
        : schoolId?.trim();
    final cleanSchoolName = schoolName?.trim().isEmpty == true
        ? null
        : schoolName?.trim();

    TransitHandoverItem? targetExisting;
    TransitHandoverItem? loadTemplate;

    if (existingHandovers.isNotEmpty) {
      loadTemplate = existingHandovers.first;
    }

    if (mode == CourierScanMode.loadAtKitchen) {
      // Reuse only an open (not yet arrived) handover; never regress an arrived school handover.
      for (final h in existingHandovers) {
        if (h.schoolId == null && h.arrivedAtUtc == null) {
          targetExisting = h;
          break;
        }
      }
    } else {
      // 1. Update same school handover if courier scans again at the same school.
      if (cleanSchoolId != null) {
        for (final h in existingHandovers) {
          if (h.schoolId == cleanSchoolId) {
            targetExisting = h;
            break;
          }
        }
      }
      // 2. Otherwise claim the open load handover (first school arrival).
      if (targetExisting == null) {
        for (final h in existingHandovers) {
          if (h.schoolId == null && h.arrivedAtUtc == null) {
            targetExisting = h;
            break;
          }
        }
      }
      // 3. Otherwise (2nd+ school arrival for the same batch): allocate a new handover id
      //    while inheriting load metadata from loadTemplate so prior school records stay intact.
    }

    final id = (targetExisting?.id.isNotEmpty ?? false)
        ? targetExisting!.id
        : _uuid.v4();
    final mergedNotes = _mergeHandoverNotes(
      existingNote: targetExisting?.handoverNotes,
      nextNote: notes,
    );

    late final TransitHandoverItem nextItem;
    if (mode == CourierScanMode.loadAtKitchen) {
      nextItem = TransitHandoverItem(
        id: id,
        batchId: qrPayload.batchId,
        batchCode: qrPayload.batchCode,
        menuName: qrPayload.menuName,
        sppgId: kitchen.id,
        schoolId: cleanSchoolId ?? targetExisting?.schoolId,
        schoolName: cleanSchoolName ?? targetExisting?.schoolName,
        courierUserId: actor.id,
        courierName: actor.fullName.trim().isNotEmpty
            ? actor.fullName.trim()
            : 'Kurir SPPG',
        loadedAtUtc: targetExisting?.loadedAtUtc ?? nowUtc,
        departedAtUtc: targetExisting?.departedAtUtc ?? nowUtc,
        arrivedAtUtc: null,
        handedOverAtUtc: null,
        status: TransitHandoverDbStatus.inTransit,
        handoverNotes: mergedNotes,
        loadLat: lat ?? targetExisting?.loadLat,
        loadLng: lng ?? targetExisting?.loadLng,
        arriveLat: null,
        arriveLng: null,
        createdAtUtc: targetExisting?.createdAtUtc ?? nowUtc,
        isPendingSync: true,
      );
    } else {
      final sealedFallback = DateTime.fromMillisecondsSinceEpoch(
        qrPayload.sealedAtEpochSec * 1000,
        isUtc: true,
      );
      final sourceForLoad = targetExisting ?? loadTemplate;
      nextItem = TransitHandoverItem(
        id: id,
        batchId: qrPayload.batchId,
        batchCode: qrPayload.batchCode,
        menuName: qrPayload.menuName,
        sppgId: kitchen.id,
        schoolId: cleanSchoolId ?? targetExisting?.schoolId,
        schoolName: cleanSchoolName ?? targetExisting?.schoolName,
        courierUserId: sourceForLoad?.courierUserId ?? actor.id,
        courierName: sourceForLoad?.courierName ??
            (actor.fullName.trim().isNotEmpty
                ? actor.fullName.trim()
                : 'Kurir SPPG'),
        loadedAtUtc: sourceForLoad?.loadedAtUtc ?? sealedFallback,
        departedAtUtc: sourceForLoad?.departedAtUtc ?? sealedFallback,
        arrivedAtUtc: nowUtc,
        handedOverAtUtc: nowUtc,
        status: TransitHandoverDbStatus.arrived,
        handoverNotes: mergedNotes,
        loadLat: sourceForLoad?.loadLat,
        loadLng: sourceForLoad?.loadLng,
        arriveLat: lat ?? targetExisting?.arriveLat,
        arriveLng: lng ?? targetExisting?.arriveLng,
        createdAtUtc: targetExisting?.createdAtUtc ?? nowUtc,
        isPendingSync: true,
      );
    }

    var synced = false;
    final client = _client;
    if (!isOffline && client != null) {
      synced = await _upsertTransitRemote(client, nextItem.toDbMap());
    }

    await _database.upsertTraceabilityDraft(
      LocalTraceabilityDraftsCompanion(
        id: Value(id),
        recordType: const Value('transit_handover'),
        institutionId: Value(kitchen.id),
        batchId: Value(qrPayload.batchId),
        payloadJson: Value(jsonEncode(nextItem.toLocalDraftMap())),
        isSynced: Value(synced),
        createdAt: Value(nextItem.createdAtUtc),
        updatedAt: Value(nowUtc),
      ),
    );

    if (!synced) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion(
          entityId: Value(id),
          operationType: const Value('upsert_transit_handover'),
          payloadJson: Value(jsonEncode(nextItem.toLocalDraftMap())),
          localPhotoPathsJson: const Value('[]'),
          createdAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
        ),
      );
      await _scheduleSync();
    }

    return TransitHandoverItem(
      id: nextItem.id,
      batchId: nextItem.batchId,
      batchCode: nextItem.batchCode,
      menuName: nextItem.menuName,
      sppgId: nextItem.sppgId,
      schoolId: nextItem.schoolId,
      schoolName: nextItem.schoolName,
      courierUserId: nextItem.courierUserId,
      courierName: nextItem.courierName,
      loadedAtUtc: nextItem.loadedAtUtc,
      departedAtUtc: nextItem.departedAtUtc,
      arrivedAtUtc: nextItem.arrivedAtUtc,
      handedOverAtUtc: nextItem.handedOverAtUtc,
      receivedByUserId: nextItem.receivedByUserId,
      status: nextItem.status,
      handoverNotes: nextItem.handoverNotes,
      loadLat: nextItem.loadLat,
      loadLng: nextItem.loadLng,
      arriveLat: nextItem.arriveLat,
      arriveLng: nextItem.arriveLng,
      createdAtUtc: nextItem.createdAtUtc,
      isPendingSync: !synced,
    );
  }

  Future<bool> _upsertTransitRemote(
    SupabaseClient client,
    Map<String, dynamic> dbMap,
  ) async {
    try {
      await client.from('transit_handovers').upsert(dbMap, onConflict: 'id');
      return true;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST204') {
        final legacy = Map<String, dynamic>.from(dbMap)
          ..remove('load_lat')
          ..remove('load_lng')
          ..remove('arrive_lat')
          ..remove('arrive_lng');
        try {
          await client
              .from('transit_handovers')
              .upsert(legacy, onConflict: 'id');
          return true;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SupplyChainTimelineData> fetchSupplyChainTimeline({
    required String sppgId,
    required String batchId,
    required DateTime sealedAtUtc,
    DateTime? schoolScannedAtUtc,
    String? schoolId,
  }) async {
    final byId = <String, TransitHandoverItem>{};

    final localRows = await _database.getTraceabilityDrafts(
      recordType: 'transit_handover',
      batchId: batchId,
    );
    for (final row in localRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded != null) {
        final item = TransitHandoverItem.fromMap(
          decoded,
          isPendingSync: !row.isSynced,
        );
        if (item.id.isNotEmpty) {
          byId[item.id] = item;
        }
      }
    }

    final client = _client;
    if (client != null) {
      try {
        final remoteRows = await _selectTransitHandovers(
          client: client,
          sppgId: sppgId,
          batchId: batchId,
        );
        for (final row in remoteRows) {
          final remote = TransitHandoverItem.fromMap(row);
          if (remote.id.isNotEmpty) {
            final existing = byId[remote.id];
            if (existing == null || !existing.isPendingSync) {
              byId[remote.id] = remote;
            }
          }
        }
      } catch (_) {
        // Keep local draft when offline.
      }
    }

    TransitHandoverItem? handover;
    final candidates = byId.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    if (candidates.isNotEmpty) {
      if (schoolId != null && schoolId.isNotEmpty) {
        for (final item in candidates) {
          if (item.schoolId == schoolId) {
            handover = item;
            break;
          }
        }
      }
      handover ??= candidates.firstWhere(
        (h) => h.arrivedAtUtc != null,
        orElse: () => candidates.first,
      );
    }

    var resolvedSchoolScan = schoolScannedAtUtc;
    if (resolvedSchoolScan == null && client != null) {
      try {
        final inspectionRows = List<Map<String, dynamic>>.from(
          await client
                  .from('school_inspections')
                  .select('scanned_at')
                  .eq('batch_id', batchId)
                  .order('scanned_at', ascending: true)
                  .limit(1)
              as List,
        );
        if (inspectionRows.isNotEmpty) {
          resolvedSchoolScan = DateTime.tryParse(
            '${inspectionRows.first['scanned_at'] ?? ''}',
          )?.toUtc();
        }
      } catch (_) {
        // Optional lookup.
      }
    }

    return SupplyChainTimelineData(
      batchId: batchId,
      sealedAtUtc: sealedAtUtc.toUtc(),
      handover: handover,
      schoolScannedAtUtc: resolvedSchoolScan?.toUtc(),
    );
  }

  @override
  Future<TrayReturnLogItem> submitSchoolTrayReturn({
    required SchoolProfile school,
    required String batchId,
    required String batchCode,
    required String menuName,
    required int traysSent,
    required int traysReturned,
    required bool isOffline,
    String? notes,
  }) async {
    final sppgId = school.sppgId ?? '';
    if (sppgId.isEmpty) {
      throw const FormatException(
        'Sekolah belum memiliki mitra Dapur SPPG aktif.',
      );
    }

    final existingRows = await _database.getTraceabilityDrafts(
      recordType: 'tray_return',
      batchId: batchId,
    );
    TrayReturnLogItem? existingForSchool;
    for (final row in existingRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded != null && decoded['school_id'] == school.id) {
        existingForSchool = TrayReturnLogItem.fromMap(
          decoded,
          isPendingSync: !row.isSynced,
        );
        break;
      }
    }

    final nowUtc = DateTime.now().toUtc();
    final id = (existingForSchool?.id.isNotEmpty ?? false)
        ? existingForSchool!.id
        : _uuid.v4();
    final cleanSent = traysSent < 0 ? 0 : traysSent;
    final cleanReturned = traysReturned < 0 ? 0 : traysReturned;
    final missing = (cleanSent - cleanReturned) > 0
        ? (cleanSent - cleanReturned)
        : 0;

    final item = TrayReturnLogItem(
      id: id,
      batchId: batchId,
      batchCode: batchCode,
      menuName: menuName,
      sppgId: sppgId,
      schoolId: school.id,
      schoolName: school.name,
      traysSent: cleanSent,
      traysReturned: cleanReturned,
      missingTrays: missing,
      returnStatus: TrayReturnStatus.inReturnTransit,
      sanitizationStatus:
          existingForSchool?.sanitizationStatus ??
          TraySanitizationStatus.pending,
      checklist:
          existingForSchool?.checklist ?? const TraySanitationChecklist(),
      returnedAtUtc: nowUtc,
      sanitizedAtUtc: existingForSchool?.sanitizedAtUtc,
      sanitizedBy: existingForSchool?.sanitizedBy,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAtUtc: existingForSchool?.createdAtUtc ?? nowUtc,
      isPendingSync: true,
    );

    var synced = false;
    final client = _client;
    if (!isOffline && client != null) {
      synced = await _upsertTrayReturnRemote(client, item.toDbMap());
    }

    await _database.upsertTraceabilityDraft(
      LocalTraceabilityDraftsCompanion(
        id: Value(id),
        recordType: const Value('tray_return'),
        institutionId: Value(sppgId),
        batchId: Value(batchId),
        payloadJson: Value(jsonEncode(item.toLocalDraftMap())),
        isSynced: Value(synced),
        createdAt: Value(item.createdAtUtc),
        updatedAt: Value(nowUtc),
      ),
    );

    if (!synced) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion(
          entityId: Value(id),
          operationType: const Value('create_tray_return'),
          payloadJson: Value(jsonEncode(item.toLocalDraftMap())),
          localPhotoPathsJson: const Value('[]'),
          createdAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
        ),
      );
      await _scheduleSync();
    }

    return TrayReturnLogItem(
      id: item.id,
      batchId: item.batchId,
      batchCode: item.batchCode,
      menuName: item.menuName,
      sppgId: item.sppgId,
      schoolId: item.schoolId,
      schoolName: item.schoolName,
      traysSent: item.traysSent,
      traysReturned: item.traysReturned,
      missingTrays: item.missingTrays,
      returnStatus: item.returnStatus,
      sanitizationStatus: item.sanitizationStatus,
      checklist: item.checklist,
      returnedAtUtc: item.returnedAtUtc,
      sanitizedAtUtc: item.sanitizedAtUtc,
      sanitizedBy: item.sanitizedBy,
      notes: item.notes,
      createdAtUtc: item.createdAtUtc,
      isPendingSync: !synced,
    );
  }

  @override
  Future<List<TrayReturnLogItem>> fetchSchoolTrayReturns({
    required String schoolId,
  }) async {
    final localRows = await _database.getTraceabilityDrafts(
      recordType: 'tray_return',
    );
    final byId = <String, TrayReturnLogItem>{};
    for (final row in localRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded == null || decoded['school_id'] != schoolId) {
        continue;
      }
      final item = TrayReturnLogItem.fromMap(
        decoded,
        isPendingSync: !row.isSynced,
      );
      if (item.id.isNotEmpty) {
        byId[item.id] = item;
      }
    }

    final client = _client;
    if (client != null) {
      try {
        final remoteRows = await _selectTrayReturns(
          client: client,
          schoolId: schoolId,
        );
        for (final row in remoteRows) {
          final remoteItem = TrayReturnLogItem.fromMap(row);
          if (remoteItem.id.isNotEmpty) {
            final existing = byId[remoteItem.id];
            if (existing == null || !existing.isPendingSync) {
              byId[remoteItem.id] = remoteItem;
            }
          }
        }
      } catch (_) {
        // Keep local cache when offline.
      }
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return result;
  }

  @override
  Future<List<TrayReturnLogItem>> fetchKitchenTrayReturns({
    required String sppgId,
  }) async {
    final localRows = await _database.getTraceabilityDrafts(
      recordType: 'tray_return',
      institutionId: sppgId,
    );
    final byId = <String, TrayReturnLogItem>{};
    for (final row in localRows) {
      final decoded = _decodeMap(row.payloadJson);
      if (decoded == null) {
        continue;
      }
      final item = TrayReturnLogItem.fromMap(
        decoded,
        isPendingSync: !row.isSynced,
      );
      if (item.id.isNotEmpty) {
        byId[item.id] = item;
      }
    }

    final client = _client;
    if (client != null) {
      try {
        final remoteRows = await _selectTrayReturns(
          client: client,
          sppgId: sppgId,
        );
        for (final row in remoteRows) {
          final remoteItem = TrayReturnLogItem.fromMap(row);
          if (remoteItem.id.isNotEmpty) {
            final existing = byId[remoteItem.id];
            if (existing == null || !existing.isPendingSync) {
              byId[remoteItem.id] = remoteItem;
            }
          }
        }
      } catch (_) {
        // Keep offline drafts when unreachable.
      }
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return result;
  }

  @override
  Future<TrayReturnLogItem> verifyKitchenTrayReturnAndSanitation({
    required String sppgId,
    required TrayReturnLogItem item,
    required int verifiedReturnedCount,
    required TraySanitationChecklist checklist,
    required bool isOffline,
    String? verifierUserId,
    String? notes,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final cleanReturned = verifiedReturnedCount < 0 ? 0 : verifiedReturnedCount;
    final missing = (item.traysSent - cleanReturned) > 0
        ? (item.traysSent - cleanReturned)
        : 0;
    final nextSanitation = checklist.isAllCompleted
        ? TraySanitizationStatus.sanitizedVerified
        : (checklist.completedCount > 0
              ? TraySanitizationStatus.washed
              : TraySanitizationStatus.pending);
    final nextReturnStatus = checklist.isAllCompleted
        ? TrayReturnStatus.sanitized
        : TrayReturnStatus.receivedSppg;

    final updated = TrayReturnLogItem(
      id: item.id,
      batchId: item.batchId,
      batchCode: item.batchCode,
      menuName: item.menuName,
      sppgId: sppgId,
      schoolId: item.schoolId,
      schoolName: item.schoolName,
      traysSent: item.traysSent,
      traysReturned: cleanReturned,
      missingTrays: missing,
      returnStatus: nextReturnStatus,
      sanitizationStatus: nextSanitation,
      checklist: checklist,
      returnedAtUtc: item.returnedAtUtc ?? nowUtc,
      sanitizedAtUtc: checklist.isAllCompleted ? nowUtc : item.sanitizedAtUtc,
      sanitizedBy: checklist.isAllCompleted
          ? (verifierUserId ?? item.sanitizedBy)
          : item.sanitizedBy,
      notes: notes?.trim().isEmpty == true ? item.notes : notes?.trim(),
      createdAtUtc: item.createdAtUtc,
      isPendingSync: true,
    );

    var synced = false;
    final client = _client;
    if (!isOffline && client != null) {
      synced = await _upsertTrayReturnRemote(client, updated.toDbMap());
    }

    await _database.upsertTraceabilityDraft(
      LocalTraceabilityDraftsCompanion(
        id: Value(updated.id),
        recordType: const Value('tray_return'),
        institutionId: Value(sppgId),
        batchId: Value(updated.batchId),
        payloadJson: Value(jsonEncode(updated.toLocalDraftMap())),
        isSynced: Value(synced),
        createdAt: Value(updated.createdAtUtc),
        updatedAt: Value(nowUtc),
      ),
    );

    if (!synced) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion(
          entityId: Value(updated.id),
          operationType: const Value('update_tray_return_sanitation'),
          payloadJson: Value(jsonEncode(updated.toLocalDraftMap())),
          localPhotoPathsJson: const Value('[]'),
          createdAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
        ),
      );
      await _scheduleSync();
    }

    return TrayReturnLogItem(
      id: updated.id,
      batchId: updated.batchId,
      batchCode: updated.batchCode,
      menuName: updated.menuName,
      sppgId: updated.sppgId,
      schoolId: updated.schoolId,
      schoolName: updated.schoolName,
      traysSent: updated.traysSent,
      traysReturned: updated.traysReturned,
      missingTrays: updated.missingTrays,
      returnStatus: updated.returnStatus,
      sanitizationStatus: updated.sanitizationStatus,
      checklist: updated.checklist,
      returnedAtUtc: updated.returnedAtUtc,
      sanitizedAtUtc: updated.sanitizedAtUtc,
      sanitizedBy: updated.sanitizedBy,
      notes: updated.notes,
      createdAtUtc: updated.createdAtUtc,
      isPendingSync: !synced,
    );
  }

  Future<List<Map<String, dynamic>>> _selectTrayReturns({
    required SupabaseClient client,
    String? sppgId,
    String? schoolId,
  }) async {
    try {
      var query = client
          .from('tray_return_logs')
          .select('*, schools(name), food_batches(batch_code, menu_name)');
      if (sppgId != null) {
        query = query.eq('sppg_id', sppgId);
      }
      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }
      return List<Map<String, dynamic>>.from(
        await query.order('created_at', ascending: false).limit(100) as List,
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST200' || error.code == 'PGRST204') {
        var fallback = client.from('tray_return_logs').select();
        if (sppgId != null) {
          fallback = fallback.eq('sppg_id', sppgId);
        }
        if (schoolId != null) {
          fallback = fallback.eq('school_id', schoolId);
        }
        return List<Map<String, dynamic>>.from(
          await fallback.order('created_at', ascending: false).limit(100)
              as List,
        );
      }
      rethrow;
    }
  }

  Future<bool> _upsertTrayReturnRemote(
    SupabaseClient client,
    Map<String, dynamic> dbMap,
  ) async {
    try {
      await client.from('tray_return_logs').upsert(dbMap, onConflict: 'id');
      return true;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST204') {
        final legacy = Map<String, dynamic>.from(dbMap)
          ..remove('sanitization_checklist');
        try {
          await client
              .from('tray_return_logs')
              .upsert(legacy, onConflict: 'id');
          return true;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> syncPendingTraceabilityQueue({
    String? sppgId,
    String? schoolId,
    Set<String>? operationTypes,
  }) async {
    final client = _client;
    if (client == null) {
      return 0;
    }
    final result = await replayDriftSyncQueue(
      database: _database,
      client: client,
      kitchenId: sppgId,
      schoolId: schoolId,
      operationTypes: operationTypes ?? _traceabilityOperationTypes,
    );
    return result.syncedCount;
  }

  Future<void> _scheduleSync() async {
    try {
      await _backgroundSyncScheduler?.scheduleImmediateConnectedSync();
    } catch (_) {
      // Ignore background scheduler errors in unit/offline tests.
    }
  }

  String? _mergeHandoverNotes({String? existingNote, String? nextNote}) {
    final a = existingNote?.trim() ?? '';
    final b = nextNote?.trim() ?? '';
    if (a.isEmpty && b.isEmpty) {
      return null;
    }
    if (a.isEmpty) return b;
    if (b.isEmpty || a == b) return a;
    return '$a | $b';
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }
}

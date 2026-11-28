import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';

class SyncQueueExecutionResult {
  const SyncQueueExecutionResult({
    required this.syncedCount,
    required this.failedCount,
    required this.remainingCount,
  });

  final int syncedCount;
  final int failedCount;
  final int remainingCount;
}

/// Chronological offline-first queue replay engine shared between UI auto-sync and WorkManager.
Future<SyncQueueExecutionResult> replayDriftSyncQueue({
  required AppDatabase database,
  required SupabaseClient client,
  String? kitchenId,
  String? schoolId,
  Set<String>? operationTypes,
}) async {
  await database.recoverStuckSyncingItems();
  final pendingRows = await database.getPendingSyncItems();
  var syncedCount = 0;
  var failedCount = 0;
  final remappedInspectionIds = <String, String>{};

  for (final row in pendingRows) {
    if (operationTypes != null && !operationTypes.contains(row.operationType)) {
      continue;
    }

    try {
      final raw = jsonDecode(row.payloadJson);
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final localPaths = (jsonDecode(row.localPhotoPathsJson) as List)
          .whereType<String>()
          .toList(growable: false);

      final handled = await _processSyncRow(
        database: database,
        client: client,
        row: row,
        map: map,
        localPaths: localPaths,
        kitchenId: kitchenId,
        schoolId: schoolId,
        remappedInspectionIds: remappedInspectionIds,
      );
      if (!handled) {
        continue;
      }

      await database.updateSyncItemStatus(id: row.id, status: 'synced');
      syncedCount++;
    } catch (error) {
      failedCount++;
      await database.updateSyncItemStatus(
        id: row.id,
        status: 'failed',
        retryCount: row.retryCount + 1,
        lastError: error.toString(),
      );
    }
  }

  final remaining = await database.getPendingSyncItems();
  return SyncQueueExecutionResult(
    syncedCount: syncedCount,
    failedCount: failedCount,
    remainingCount: remaining.length,
  );
}

bool _isSyncUniqueViolation(PostgrestException error) {
  final lower = error.message.toLowerCase();
  return error.code == '23505' ||
      lower.contains('23505') ||
      lower.contains('duplicate key');
}

bool _isSyncPermissionDenied(PostgrestException error) {
  final lower = error.message.toLowerCase();
  return error.code == '42501' ||
      error.code == '403' ||
      lower.contains('42501') ||
      lower.contains('permission denied');
}

Future<String> _saveInspectionRemoteForSync(
  SupabaseClient client,
  Map<String, dynamic> dbMap,
) async {
  final fallbackId = dbMap['id'] as String;
  try {
    final insertedRows = List<Map<String, dynamic>>.from(
      await client.from('school_inspections').insert(dbMap).select('id')
          as List,
    );
    if (insertedRows.isNotEmpty && insertedRows.first['id'] is String) {
      return insertedRows.first['id'] as String;
    }
    return fallbackId;
  } on PostgrestException catch (pgError) {
    if (pgError.code == 'PGRST204') {
      final stripped = Map<String, dynamic>.from(dbMap)
        ..remove('actual_temp_celsius')
        ..remove('temp_source');
      return _saveInspectionRemoteForSync(client, stripped);
    }
    if (!_isSyncUniqueViolation(pgError)) {
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
      final updatedRows = List<Map<String, dynamic>>.from(
        await client
                .from('school_inspections')
                .update(updatePayload)
                .eq('batch_id', batchId)
                .eq('school_id', schoolId)
                .select('id')
            as List,
      );
      if (updatedRows.isNotEmpty && updatedRows.first['id'] is String) {
        return updatedRows.first['id'] as String;
      }
    } on PostgrestException catch (updateError) {
      if (updateError.code == 'PGRST204') {
        final strippedUpdate = Map<String, dynamic>.from(updatePayload)
          ..remove('actual_temp_celsius')
          ..remove('temp_source');
        final updatedRows = List<Map<String, dynamic>>.from(
          await client
                  .from('school_inspections')
                  .update(strippedUpdate)
                  .eq('batch_id', batchId)
                  .eq('school_id', schoolId)
                  .select('id')
              as List,
        );
        if (updatedRows.isNotEmpty && updatedRows.first['id'] is String) {
          return updatedRows.first['id'] as String;
        }
      } else if (!_isSyncPermissionDenied(updateError)) {
        rethrow;
      }
    }

    final existingRows = List<Map<String, dynamic>>.from(
      await client
              .from('school_inspections')
              .select('id')
              .eq('batch_id', batchId)
              .eq('school_id', schoolId)
              .limit(1)
          as List,
    );
    if (existingRows.isNotEmpty && existingRows.first['id'] is String) {
      return existingRows.first['id'] as String;
    }
    return fallbackId;
  }
}

Future<bool> _processSyncRow({
  required AppDatabase database,
  required SupabaseClient client,
  required LocalSyncQueueData row,
  required Map<String, dynamic> map,
  required List<String> localPaths,
  required String? kitchenId,
  required String? schoolId,
  required Map<String, String> remappedInspectionIds,
}) async {
  switch (row.operationType) {
    case 'create_batch':
      if (kitchenId != null && map['sppg_id'] != kitchenId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final storagePath = map['packaging_photo_url'] as String?;
      if (storagePath != null && localPaths.isNotEmpty) {
        await _uploadLocalPhotoIfExists(
          client: client,
          storagePath: storagePath,
          localFilePath: localPaths.first,
        );
      }
      map.remove('sppg_name');
      try {
        await client.from('food_batches').insert(map);
      } on PostgrestException catch (pgError) {
        if (pgError.code == 'PGRST204' ||
            pgError.message.toLowerCase().contains('signing_key_id')) {
          final legacyMap = Map<String, dynamic>.from(map)
            ..remove('signing_key_id')
            ..remove('allergen_tags');
          await client.from('food_batches').insert(legacyMap);
        } else if (pgError.code != '23505') {
          rethrow;
        }
      }
      return true;

    case 'create_inspection':
      if (schoolId != null && map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final samplePath = map['sample_photo_url'] as String?;
      if (samplePath != null && localPaths.isNotEmpty) {
        await _uploadLocalPhotoIfExists(
          client: client,
          storagePath: samplePath,
          localFilePath: localPaths.first,
        );
      }
      map.remove('batch_code');
      map.remove('menu_name');
      map.remove('allergen_tags');
      final localInspectionId = map['id'] as String?;
      final persistedId = await _saveInspectionRemoteForSync(client, map);
      if (localInspectionId != null && persistedId != localInspectionId) {
        remappedInspectionIds[localInspectionId] = persistedId;
      }
      return true;

    case 'create_sample':
      if (schoolId != null && map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
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
      await database.updateSampleVaultStatus(
        id: row.entityId,
        status: (map['status'] as String?) ?? 'active',
        isSynced: true,
      );
      return true;

    case 'update_sample_status':
      if (schoolId != null &&
          map['school_id'] != null &&
          map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      await client
          .from('sample_vaults')
          .update({'status': map['status']})
          .eq('id', row.entityId);
      await database.updateSampleVaultStatus(
        id: row.entityId,
        status: (map['status'] as String?) ?? 'disposed',
        isSynced: true,
      );
      return true;

    case 'create_waste_log':
      if (schoolId != null && map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final remotePaths = (map['photo_urls'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false);
      for (var i = 0; i < remotePaths.length && i < localPaths.length; i++) {
        await _uploadLocalPhotoIfExists(
          client: client,
          storagePath: remotePaths[i],
          localFilePath: localPaths[i],
        );
      }
      try {
        await client.from('plate_waste_logs').insert(map);
      } on PostgrestException catch (pgError) {
        if (pgError.code != '23505') {
          rethrow;
        }
      }
      return true;

    case 'create_alert':
      if (schoolId != null && map['reporter_school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      try {
        await client.from('cluster_alerts').insert(map);
      } on PostgrestException catch (pgError) {
        if (pgError.code != '23505') {
          rethrow;
        }
      }
      if ((map['broadcast_enabled'] as bool?) ?? true) {
        try {
          await client.functions.invoke(
            'dispatch-cluster-alert',
            body: {'alert_id': row.entityId},
          );
        } catch (_) {
          // Database trigger already dispatches webhook; ignore fallback invocation errors.
        }
      }
      return true;

    case 'update_alert_pdf_dispatched':
      if (schoolId != null &&
          map['reporter_school_id'] != null &&
          map['reporter_school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      await client
          .from('cluster_alerts')
          .update({'pdf_dispatched': true})
          .eq('id', row.entityId);
      return true;

    case 'ack_alert':
      if (schoolId != null && map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      try {
        await client.from('alert_acknowledgements').insert(map);
      } on PostgrestException catch (pgError) {
        if (pgError.code != '23505') {
          rethrow;
        }
      }
      return true;

    case 'rotate_signing_key':
      if (kitchenId != null && map['sppg_id'] != kitchenId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      await client.rpc(
        'rotate_sppg_signing_key',
        params: {
          'p_sppg_id': map['sppg_id'],
          'p_new_key_id': map['key_id'],
          'p_new_public_key': map['public_key'],
          'p_revoke_previous': (map['revoke_previous'] as bool?) ?? false,
          'p_device_label': map['device_label'],
        },
      );
      return true;

    case 'revoke_signing_key':
      if (kitchenId != null && map['sppg_id'] != kitchenId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      await client.rpc(
        'revoke_sppg_signing_key',
        params: {
          'p_sppg_id': map['sppg_id'],
          'p_key_id': map['key_id'],
        },
      );
      return true;

    case 'upsert_institution_member':
      final instType = map['institution_type'] as String?;
      final instId = map['institution_id'] as String?;
      if (instType == 'sppg' && kitchenId != null && instId != kitchenId) {
        return false;
      }
      if (instType == 'school' && schoolId != null && instId != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      await client.rpc(
        'add_institution_member',
        params: {
          'p_institution_type': instType,
          'p_institution_id': instId,
          'p_member_name': map['member_name'],
          'p_member_email': map['member_email'],
          'p_role': map['role'],
        },
      );
      return true;

    case 'toggle_institution_member':
      final instType = map['institution_type'] as String?;
      final instId = map['institution_id'] as String?;
      if (instType == 'sppg' && kitchenId != null && instId != kitchenId) {
        return false;
      }
      if (instType == 'school' && schoolId != null && instId != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      await client.rpc(
        'set_institution_member_active',
        params: {
          'p_member_id': row.entityId,
          'p_is_active': (map['is_active'] as bool?) ?? false,
        },
      );
      return true;

    case 'create_ingredient_log':
      if (kitchenId != null && map['sppg_id'] != kitchenId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final ingredientMap = Map<String, dynamic>.from(map)
        ..remove('batch_code')
        ..remove('menu_name');
      try {
        await client.from('ingredient_logs').insert(ingredientMap);
      } on PostgrestException catch (pgError) {
        if (pgError.code != '23505') {
          rethrow;
        }
      }
      await database.markTraceabilityDraftSynced(row.entityId);
      return true;

    case 'upsert_transit_handover':
      if (kitchenId != null && map['sppg_id'] != kitchenId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final transitMap = Map<String, dynamic>.from(map)
        ..remove('batch_code')
        ..remove('menu_name')
        ..remove('school_name');
      await _upsertWithColumnFallback(
        client: client,
        table: 'transit_handovers',
        payload: transitMap,
        optionalColumns: const ['load_lat', 'load_lng', 'arrive_lat', 'arrive_lng'],
      );
      await database.markTraceabilityDraftSynced(row.entityId);
      return true;

    case 'create_tray_return':
    case 'update_tray_return_sanitation':
      if (row.operationType == 'create_tray_return') {
        if (schoolId != null && map['school_id'] != schoolId) {
          return false;
        }
        if (kitchenId != null &&
            schoolId == null &&
            map['sppg_id'] != kitchenId) {
          return false;
        }
      } else {
        if (kitchenId != null && map['sppg_id'] != kitchenId) {
          return false;
        }
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final trayMap = Map<String, dynamic>.from(map)
        ..remove('batch_code')
        ..remove('menu_name')
        ..remove('school_name')
        ..remove('missing_trays');
      await _upsertWithColumnFallback(
        client: client,
        table: 'tray_return_logs',
        payload: trayMap,
        optionalColumns: const ['sanitization_checklist'],
      );
      await database.markTraceabilityDraftSynced(row.entityId);
      return true;

    case 'sync_school_allergens':
      if (schoolId != null && map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final rawEntries = (map['entries'] as List?) ?? const [];
      final targetSchoolId = map['school_id'] as String;
      final tags = <String>[];
      final upsertPayloads = <Map<String, dynamic>>[];
      for (final raw in rawEntries) {
        if (raw is Map<String, dynamic>) {
          final tag = raw['allergen_tag'] as String?;
          if (tag != null && tag.isNotEmpty) {
            tags.add(tag);
          }
          upsertPayloads.add(Map<String, dynamic>.from(raw));
        }
      }
      final existingRows = List<Map<String, dynamic>>.from(
        await client
                .from('school_allergen_profiles')
                .select('id, allergen_tag')
                .eq('school_id', targetSchoolId)
            as List,
      );
      final idsToDelete = <String>[];
      for (final existing in existingRows) {
        final existingTag = existing['allergen_tag'] as String?;
        final existingId = existing['id'] as String?;
        if (existingId != null &&
            existingTag != null &&
            !tags.contains(existingTag)) {
          idsToDelete.add(existingId);
        }
      }
      if (idsToDelete.isNotEmpty) {
        await client
            .from('school_allergen_profiles')
            .delete()
            .inFilter('id', idsToDelete);
      }
      if (upsertPayloads.isNotEmpty) {
        await client
            .from('school_allergen_profiles')
            .upsert(upsertPayloads, onConflict: 'school_id,allergen_tag');
      }
      return true;

    case 'resolve_cluster_alert':
      if (kitchenId != null && map['sppg_id'] != kitchenId) {
        return false;
      }
      if (schoolId != null && map['reporter_school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
      final alertId = (map['id'] ?? map['alert_id'] ?? row.entityId) as String;
      final newStatus =
          (map['resolution_status'] ?? map['new_status']) as String;
      final resolutionNote = map['resolution_note'] as String;
      try {
        await client.rpc(
          'resolve_cluster_alert',
          params: {
            'p_alert_id': alertId,
            'p_new_status': newStatus,
            'p_resolution_note': resolutionNote,
          },
        );
      } on PostgrestException catch (pgError) {
        if (pgError.code == 'PGRST202' || pgError.code == '42883') {
          await client
              .from('cluster_alerts')
              .update({
                'resolution_status': newStatus,
                'resolution_note': resolutionNote,
                'resolved_by': map['resolved_by'],
                'resolved_at': map['resolved_at'],
              })
              .eq('id', alertId);
        } else {
          rethrow;
        }
      }
      await database.markTraceabilityDraftSynced('alert_res_$alertId');
      return true;

    default:
      return false;
  }
}

Future<void> _upsertWithColumnFallback({
  required SupabaseClient client,
  required String table,
  required Map<String, dynamic> payload,
  required List<String> optionalColumns,
}) async {
  try {
    await client.from(table).upsert(payload, onConflict: 'id');
  } on PostgrestException catch (pgError) {
    if (pgError.code == 'PGRST204') {
      final fallback = Map<String, dynamic>.from(payload);
      for (final col in optionalColumns) {
        fallback.remove(col);
      }
      await client.from(table).upsert(fallback, onConflict: 'id');
    } else if (pgError.code != '23505') {
      rethrow;
    }
  }
}

Future<void> _uploadLocalPhotoIfExists({
  required SupabaseClient client,
  required String storagePath,
  required String localFilePath,
}) async {
  final file = File(localFilePath);
  if (!file.existsSync()) {
    return;
  }
  await client.storage.from(AppConstants.auditPhotosBucket).uploadBinary(
        storagePath,
        await file.readAsBytes(),
        fileOptions: const FileOptions(
          contentType: 'image/webp',
          upsert: true,
        ),
      );
}

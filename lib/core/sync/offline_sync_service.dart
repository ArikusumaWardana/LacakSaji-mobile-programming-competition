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
  final pendingRows = await database.getPendingSyncItems();
  var syncedCount = 0;
  var failedCount = 0;

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

Future<bool> _processSyncRow({
  required AppDatabase database,
  required SupabaseClient client,
  required LocalSyncQueueData row,
  required Map<String, dynamic> map,
  required List<String> localPaths,
  required String? kitchenId,
  required String? schoolId,
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
        if (pgError.code != '23505') {
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
      await client
          .from('school_inspections')
          .upsert(map, onConflict: 'batch_id,school_id');
      return true;

    case 'create_sample':
      if (schoolId != null && map['school_id'] != schoolId) {
        return false;
      }
      await database.updateSyncItemStatus(id: row.id, status: 'syncing');
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

    default:
      return false;
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

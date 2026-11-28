import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/domain/auth_models.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/cluster_alert_models.dart';

abstract class ClusterAlertRepository {
  Future<String?> findSampleLabelForInspection({
    required String schoolId,
    required String inspectionId,
  });

  Future<ClusterAlertEvent> submitClusterAlert({
    required SchoolProfile school,
    required String sppgId,
    required String sppgName,
    required String batchId,
    required String batchCode,
    required String menuName,
    required String inspectionId,
    required ClusterAlertStage stage,
    required int symptomCount,
    required bool broadcastEnabled,
    required bool isOffline,
    String? notes,
    String? sampleLabelCode,
  });

  Future<void> markPdfDispatched({
    required String alertId,
    required String reporterSchoolId,
    required bool isOffline,
  });

  Future<void> acknowledgeAlert({
    required String alertId,
    required String schoolId,
    required bool isOffline,
  });

  Future<List<ClusterAlertEvent>> fetchUnacknowledgedAlertsForToday({
    required String sppgId,
    String? currentSchoolId,
  });

  Stream<ClusterAlertEvent> watchRealtimeAlerts({
    required String sppgId,
    String? excludeSchoolId,
  });

  Future<ClusterAlertEvent> resolveClusterAlert({
    required ClusterAlertEvent alert,
    required AlertResolutionStatus newStatus,
    required String resolutionNote,
    required String resolverUserId,
    required String resolverName,
    required bool isOffline,
  });

  Future<int> syncPendingAlerts({String? schoolId, String? kitchenId});
}

class SupabaseClusterAlertRepository implements ClusterAlertRepository {
  SupabaseClusterAlertRepository({
    required this._client,
    required this._database,
    this._backgroundSyncScheduler,
    Uuid? uuid,
    DateTime Function()? clockUtc,
  }) : _uuid = uuid ?? const Uuid(),
       _clockUtc = clockUtc ?? (() => DateTime.now().toUtc());

  final SupabaseClient? _client;
  final AppDatabase _database;
  final BackgroundSyncScheduler? _backgroundSyncScheduler;
  final Uuid _uuid;
  final DateTime Function() _clockUtc;

  @override
  Future<String?> findSampleLabelForInspection({
    required String schoolId,
    required String inspectionId,
  }) async {
    final local = await _database.getSampleVaultByInspection(inspectionId);
    if (local != null && local.labelCode.isNotEmpty) {
      return local.labelCode;
    }
    final client = _client;
    if (client == null) {
      return null;
    }
    try {
      final remote = await client
          .from('sample_vaults')
          .select('label_code')
          .eq('inspection_id', inspectionId)
          .eq('school_id', schoolId)
          .maybeSingle();
      return remote?['label_code'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ClusterAlertEvent> submitClusterAlert({
    required SchoolProfile school,
    required String sppgId,
    required String sppgName,
    required String batchId,
    required String batchCode,
    required String menuName,
    required String inspectionId,
    required ClusterAlertStage stage,
    required int symptomCount,
    required bool broadcastEnabled,
    required bool isOffline,
    String? notes,
    String? sampleLabelCode,
  }) async {
    final nowUtc = _clockUtc();
    final alertId = _uuid.v4();
    final resolvedLabel =
        sampleLabelCode ??
        await findSampleLabelForInspection(
          schoolId: school.id,
          inspectionId: inspectionId,
        );
    final sanitizedNotes =
        notes == null || notes.trim().isEmpty
            ? null
            : sanitizeZeroSlopCopy(notes);

    await _markSampleLabSubmittedIfPresent(
      inspectionId: inspectionId,
      isOffline: isOffline,
    );

    final dbMap = <String, dynamic>{
      'id': alertId,
      'sppg_id': sppgId,
      'batch_id': batchId,
      'reporter_school_id': school.id,
      'stage': stage.dbValue,
      'symptom_count': stage == ClusterAlertStage.postConsumption
          ? (symptomCount < 1 ? 1 : symptomCount)
          : 0,
      'notes': sanitizedNotes,
      'broadcast_enabled': broadcastEnabled,
      'sample_label_code': resolvedLabel,
      'pdf_dispatched': false,
      'created_at': nowUtc.toIso8601String(),
    };

    var isPendingSync = true;
    final client = _client;
    if (!isOffline && client != null) {
      try {
        await client.from('cluster_alerts').insert(dbMap);
        if (broadcastEnabled) {
          try {
            await client.functions.invoke(
              'dispatch-cluster-alert',
              body: {'alert_id': alertId},
            );
          } catch (_) {
            // DB trigger or Realtime still delivers foreground alert.
          }
        }
        isPendingSync = false;
      } catch (_) {
        await _enqueueCreateAlert(dbMap: dbMap, nowUtc: nowUtc);
      }
    } else {
      await _enqueueCreateAlert(dbMap: dbMap, nowUtc: nowUtc);
    }

    return ClusterAlertEvent(
      id: alertId,
      sppgId: sppgId,
      sppgName: sanitizeZeroSlopCopy(sppgName),
      batchId: batchId,
      batchCode: sanitizeZeroSlopCopy(batchCode),
      menuName: sanitizeZeroSlopCopy(menuName),
      reporterSchoolId: school.id,
      reporterSchoolName: sanitizeZeroSlopCopy(school.name),
      stage: stage,
      symptomCount: dbMap['symptom_count'] as int,
      notes: sanitizedNotes,
      broadcastEnabled: broadcastEnabled,
      sampleLabelCode: resolvedLabel,
      pdfDispatched: false,
      createdAtUtc: nowUtc,
      activeReporterCount: 1,
      isPendingSync: isPendingSync,
    );
  }

  Future<void> _markSampleLabSubmittedIfPresent({
    required String inspectionId,
    required bool isOffline,
  }) async {
    final vault = await _database.getSampleVaultByInspection(inspectionId);
    if (vault == null || vault.status == 'lab_submitted') {
      return;
    }

    await _database.updateSampleVaultStatus(
      id: vault.id,
      status: 'lab_submitted',
      isSynced: false,
    );

    final client = _client;
    if (!isOffline && client != null) {
      try {
        await client
            .from('sample_vaults')
            .update({'status': 'lab_submitted'})
            .eq('id', vault.id);
        await _database.updateSampleVaultStatus(
          id: vault.id,
          status: 'lab_submitted',
          isSynced: true,
        );
        return;
      } catch (_) {
        // Fallback to sync queue below.
      }
    }

    final nowUtc = _clockUtc();
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'update_sample_status',
        entityId: vault.id,
        payloadJson: jsonEncode({
          'id': vault.id,
          'school_id': vault.schoolId,
          'status': 'lab_submitted',
        }),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  Future<void> _enqueueCreateAlert({
    required Map<String, dynamic> dbMap,
    required DateTime nowUtc,
  }) async {
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'create_alert',
        entityId: dbMap['id'] as String,
        payloadJson: jsonEncode(dbMap),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  @override
  Future<void> markPdfDispatched({
    required String alertId,
    required String reporterSchoolId,
    required bool isOffline,
  }) async {
    final client = _client;
    if (!isOffline && client != null) {
      try {
        await client
            .from('cluster_alerts')
            .update({'pdf_dispatched': true})
            .eq('id', alertId);
        return;
      } catch (_) {
        // Queue update below if network call fails.
      }
    }

    final nowUtc = _clockUtc();
    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'update_alert_pdf_dispatched',
        entityId: alertId,
        payloadJson: jsonEncode({
          'id': alertId,
          'reporter_school_id': reporterSchoolId,
          'pdf_dispatched': true,
        }),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  @override
  Future<void> acknowledgeAlert({
    required String alertId,
    required String schoolId,
    required bool isOffline,
  }) async {
    final nowUtc = _clockUtc();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'alert_id': alertId,
      'school_id': schoolId,
      'acknowledged_at': nowUtc.toIso8601String(),
    };

    final client = _client;
    if (!isOffline && client != null) {
      try {
        await client.from('alert_acknowledgements').insert(payload);
        return;
      } on PostgrestException catch (pgError) {
        if (pgError.code == '23505') {
          return;
        }
      } catch (_) {
        // Queue acknowledgement below.
      }
    }

    await _database.enqueueSyncItem(
      LocalSyncQueueCompanion.insert(
        operationType: 'ack_alert',
        entityId: alertId,
        payloadJson: jsonEncode(payload),
        status: const Value('pending'),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    await _triggerWorkmanagerSafe();
  }

  @override
  Future<List<ClusterAlertEvent>> fetchUnacknowledgedAlertsForToday({
    required String sppgId,
    String? currentSchoolId,
  }) async {
    final client = _client;
    if (client == null) {
      return const [];
    }

    final nowUtc = _clockUtc();
    try {
      final rawAlerts = List<Map<String, dynamic>>.from(
        await client
                .from('cluster_alerts')
                .select('*')
                .eq('sppg_id', sppgId)
                .eq('broadcast_enabled', true)
                .order('created_at', ascending: false)
                .limit(10)
            as List,
      );

      final ackedIds = <String>{};
      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        final rawAcks = List<Map<String, dynamic>>.from(
          await client
                  .from('alert_acknowledgements')
                  .select('alert_id')
                  .eq('school_id', currentSchoolId)
              as List,
        );
        for (final row in rawAcks) {
          final id = row['alert_id'] as String?;
          if (id != null) {
            ackedIds.add(id);
          }
        }
      }

      final result = <ClusterAlertEvent>[];
      for (final row in rawAlerts) {
        final createdAt = DateTime.parse(row['created_at'] as String).toUtc();
        final resolvedAt = DateTime.tryParse(
          '${row['resolved_at'] ?? ''}',
        )?.toUtc();
        final alertId = row['id'] as String;
        final reporterId = row['reporter_school_id'] as String?;
        final rowStatus = AlertResolutionStatus.fromDb(
          row['resolution_status'] as String?,
        );

        if (rowStatus != AlertResolutionStatus.active) {
          // Surface recent clarification/KLB confirmation updates (<= 24h)
          // so schools/couriers that were offline or closed during the Realtime UPDATE
          // still receive "Distribusi Aman Dilanjutkan" / "Terkonfirmasi KLB" once on reconnect.
          final resolutionAnchor = resolvedAt ?? createdAt;
          final within24h =
              nowUtc.difference(resolutionAnchor) <= const Duration(hours: 24);
          final relevantToActor =
              currentSchoolId == null ||
              reporterId == currentSchoolId ||
              ackedIds.contains(alertId) ||
              isSameWibCalendarDay(createdAt, nowUtc);
          if (within24h && relevantToActor) {
            result.add(await _enrichAlertRow(client, row));
          }
          continue;
        }

        if (!isSameWibCalendarDay(createdAt, nowUtc)) {
          continue;
        }
        if (currentSchoolId != null &&
            (reporterId == currentSchoolId || ackedIds.contains(alertId))) {
          continue;
        }
        result.add(await _enrichAlertRow(client, row));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  @override
  Stream<ClusterAlertEvent> watchRealtimeAlerts({
    required String sppgId,
    String? excludeSchoolId,
  }) {
    final client = _client;
    if (client == null || sppgId.isEmpty) {
      return const Stream.empty();
    }

    late final StreamController<ClusterAlertEvent> controller;
    RealtimeChannel? channel;

    controller = StreamController<ClusterAlertEvent>.broadcast(
      onListen: () {
        channel = client.channel('cluster-alerts-sppg-$sppgId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'cluster_alerts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'sppg_id',
              value: sppgId,
            ),
            callback: (payload) async {
              final row = payload.newRecord;
              if (row.isEmpty) {
                return;
              }
              if ((row['broadcast_enabled'] as bool?) == false) {
                return;
              }
              if (row['sppg_id'] != sppgId) {
                return;
              }
              if (excludeSchoolId != null &&
                  row['reporter_school_id'] == excludeSchoolId) {
                return;
              }
              final enriched = await _enrichAlertRow(client, row);
              if (!controller.isClosed) {
                controller.add(enriched);
              }
            },
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'cluster_alerts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'sppg_id',
              value: sppgId,
            ),
            callback: (payload) async {
              final row = payload.newRecord;
              if (row.isEmpty || row['sppg_id'] != sppgId) {
                return;
              }
              final nextStatus = AlertResolutionStatus.fromDb(
                row['resolution_status'] as String?,
              );
              if (nextStatus == AlertResolutionStatus.active) {
                return;
              }
              final enriched = await _enrichAlertRow(client, row);
              if (!controller.isClosed) {
                controller.add(enriched);
              }
            },
          )
          ..subscribe();
      },
      onCancel: () async {
        final activeChannel = channel;
        channel = null;
        if (activeChannel != null) {
          try {
            await client.removeChannel(activeChannel);
          } catch (_) {}
        }
      },
    );

    return controller.stream;
  }

  Future<ClusterAlertEvent> _enrichAlertRow(
    SupabaseClient client,
    Map<String, dynamic> row,
  ) async {
    final alertId = row['id'] as String;
    final rowResolutionStatus = AlertResolutionStatus.fromDb(
      row['resolution_status'] as String?,
    );
    final rowResolutionNote = (row['resolution_note'] as String?)?.trim();
    final rowResolvedBy = row['resolved_by'] as String?;
    final rowResolvedAt = DateTime.tryParse(
      '${row['resolved_at'] ?? ''}',
    )?.toUtc();

    try {
      final rpcV2 = await client.rpc(
        'get_cluster_alert_details_v2',
        params: {'p_alert_id': alertId},
      );
      if (rpcV2 is List && rpcV2.isNotEmpty) {
        final detail = Map<String, dynamic>.from(rpcV2.first as Map);
        return _mapEnrichedDetail(detail);
      }
    } catch (_) {
      // Fall back to v1 RPC if v2 is not installed yet.
    }

    try {
      final rpcResp = await client.rpc(
        'get_cluster_alert_details',
        params: {'p_alert_id': alertId},
      );
      if (rpcResp is List && rpcResp.isNotEmpty) {
        final detail = Map<String, dynamic>.from(rpcResp.first as Map);
        final mapped = _mapEnrichedDetail(detail);
        if (mapped.resolutionStatus == AlertResolutionStatus.active &&
            rowResolutionStatus != AlertResolutionStatus.active) {
          return mapped.copyWith(
            resolutionStatus: rowResolutionStatus,
            resolutionNote: rowResolutionNote,
            resolvedByUserId: rowResolvedBy,
            resolvedAtUtc: rowResolvedAt,
          );
        }
        return mapped;
      }
    } catch (_) {
      // Fall back gracefully when RPC is not yet installed.
    }

    var sppgName = 'Dapur SPPG Mitra';
    var batchCode = '-';
    var menuName = 'Menu Makan Bergizi Gratis';

    try {
      final results = await Future.wait([
        client
            .from('sppg_kitchens')
            .select('name')
            .eq('id', row['sppg_id'])
            .maybeSingle(),
        client
            .from('food_batches')
            .select('batch_code, menu_name')
            .eq('id', row['batch_id'])
            .maybeSingle(),
      ]);
      final kRow = results[0];
      final bRow = results[1];
      if (kRow != null && kRow['name'] is String) {
        sppgName = kRow['name'] as String;
      }
      if (bRow != null) {
        batchCode = (bRow['batch_code'] as String?) ?? '-';
        menuName = (bRow['menu_name'] as String?) ?? menuName;
      }
    } catch (_) {}

    return ClusterAlertEvent(
      id: alertId,
      sppgId: (row['sppg_id'] as String?) ?? '',
      sppgName: sanitizeZeroSlopCopy(sppgName),
      batchId: (row['batch_id'] as String?) ?? '',
      batchCode: sanitizeZeroSlopCopy(batchCode),
      menuName: sanitizeZeroSlopCopy(menuName),
      reporterSchoolId: (row['reporter_school_id'] as String?) ?? '',
      reporterSchoolName: 'Sekolah Mitra SPPG',
      stage: ClusterAlertStage.fromDb(row['stage'] as String?),
      symptomCount: (row['symptom_count'] as num?)?.toInt() ?? 0,
      notes: (row['notes'] as String?) == null
          ? null
          : sanitizeZeroSlopCopy(row['notes'] as String),
      broadcastEnabled: (row['broadcast_enabled'] as bool?) ?? true,
      sampleLabelCode: row['sample_label_code'] as String?,
      pdfDispatched: (row['pdf_dispatched'] as bool?) ?? false,
      createdAtUtc:
          DateTime.tryParse('${row['created_at'] ?? ''}')?.toUtc() ??
          _clockUtc(),
      activeReporterCount: 1,
      resolutionStatus: rowResolutionStatus,
      resolutionNote: (rowResolutionNote != null && rowResolutionNote.isNotEmpty)
          ? sanitizeZeroSlopCopy(rowResolutionNote)
          : null,
      resolvedByUserId: rowResolvedBy,
      resolvedAtUtc: rowResolvedAt,
    );
  }

  ClusterAlertEvent _mapEnrichedDetail(Map<String, dynamic> detail) {
    final rawNote = (detail['resolution_note'] as String?)?.trim();
    final rawResolverName = (detail['resolved_by_name'] as String?)?.trim();
    return ClusterAlertEvent(
      id: detail['id'] as String,
      sppgId: detail['sppg_id'] as String,
      sppgName: sanitizeZeroSlopCopy(
        (detail['sppg_name'] as String?) ?? 'Dapur SPPG Mitra',
      ),
      batchId: detail['batch_id'] as String,
      batchCode: sanitizeZeroSlopCopy(
        (detail['batch_code'] as String?) ?? '-',
      ),
      menuName: sanitizeZeroSlopCopy(
        (detail['menu_name'] as String?) ?? 'Menu Makan Bergizi Gratis',
      ),
      reporterSchoolId: (detail['reporter_school_id'] as String?) ?? '',
      reporterSchoolName: sanitizeZeroSlopCopy(
        (detail['reporter_school_name'] as String?) ?? 'Sekolah Mitra SPPG',
      ),
      stage: ClusterAlertStage.fromDb(detail['stage'] as String?),
      symptomCount: (detail['symptom_count'] as num?)?.toInt() ?? 0,
      notes: (detail['notes'] as String?) == null
          ? null
          : sanitizeZeroSlopCopy(detail['notes'] as String),
      broadcastEnabled: (detail['broadcast_enabled'] as bool?) ?? true,
      sampleLabelCode: detail['sample_label_code'] as String?,
      pdfDispatched: (detail['pdf_dispatched'] as bool?) ?? false,
      createdAtUtc:
          DateTime.tryParse('${detail['created_at'] ?? ''}')?.toUtc() ??
          _clockUtc(),
      activeReporterCount:
          (detail['active_reporter_count'] as num?)?.toInt() ?? 1,
      resolutionStatus: AlertResolutionStatus.fromDb(
        detail['resolution_status'] as String?,
      ),
      resolutionNote: (rawNote != null && rawNote.isNotEmpty)
          ? sanitizeZeroSlopCopy(rawNote)
          : null,
      resolvedByUserId: detail['resolved_by'] as String?,
      resolvedByName: (rawResolverName != null && rawResolverName.isNotEmpty)
          ? sanitizeZeroSlopCopy(rawResolverName)
          : null,
      resolvedAtUtc: DateTime.tryParse(
        '${detail['resolved_at'] ?? ''}',
      )?.toUtc(),
    );
  }

  @override
  Future<ClusterAlertEvent> resolveClusterAlert({
    required ClusterAlertEvent alert,
    required AlertResolutionStatus newStatus,
    required String resolutionNote,
    required String resolverUserId,
    required String resolverName,
    required bool isOffline,
  }) async {
    if (!alert.resolutionStatus.canTransitionTo(newStatus)) {
      throw const FormatException(
        'Transisi status darurat tidak diizinkan untuk laporan ini.',
      );
    }
    final cleanNote = sanitizeZeroSlopCopy(resolutionNote);
    if (cleanNote.length < 10) {
      throw const FormatException(
        'Alasan klarifikasi atau konfirmasi wajib diisi minimal 10 karakter.',
      );
    }
    final cleanResolver = sanitizeZeroSlopCopy(
      resolverName.trim().isEmpty ? 'Admin SPPG / Sekolah Pelapor' : resolverName,
    );
    var resolvedAtUtc = _clockUtc();
    var pendingSync = true;

    final client = _client;
    if (!isOffline && client != null) {
      try {
        final raw = await client.rpc(
          'resolve_cluster_alert',
          params: {
            'p_alert_id': alert.id,
            'p_new_status': newStatus.dbValue,
            'p_resolution_note': cleanNote,
          },
        );
        if (raw is Map && raw['ok'] == true) {
          resolvedAtUtc =
              DateTime.tryParse('${raw['resolved_at'] ?? ''}')?.toUtc() ??
              resolvedAtUtc;
          pendingSync = false;
        } else {
          throw StateError('RPC returned failure');
        }
      } catch (_) {
        try {
          await client
              .from('cluster_alerts')
              .update({
                'resolution_status': newStatus.dbValue,
                'resolution_note': cleanNote,
                'resolved_by': resolverUserId,
                'resolved_at': resolvedAtUtc.toIso8601String(),
              })
              .eq('id', alert.id);
          pendingSync = false;
        } catch (_) {
          pendingSync = true;
        }
      }
    }

    final payload = {
      'id': alert.id,
      'sppg_id': alert.sppgId,
      'reporter_school_id': alert.reporterSchoolId,
      'resolution_status': newStatus.dbValue,
      'resolution_note': cleanNote,
      'resolved_by': resolverUserId,
      'resolved_by_name': cleanResolver,
      'resolved_at': resolvedAtUtc.toIso8601String(),
    };

    await _database.upsertTraceabilityDraft(
      LocalTraceabilityDraftsCompanion(
        id: Value('alert_res_${alert.id}'),
        recordType: const Value('alert_resolution'),
        institutionId: Value(alert.sppgId),
        batchId: Value(alert.batchId),
        payloadJson: Value(jsonEncode(payload)),
        isSynced: Value(!pendingSync),
        createdAt: Value(resolvedAtUtc),
        updatedAt: Value(resolvedAtUtc),
      ),
    );

    if (pendingSync) {
      await _database.enqueueSyncItem(
        LocalSyncQueueCompanion.insert(
          operationType: 'resolve_cluster_alert',
          entityId: alert.id,
          payloadJson: jsonEncode(payload),
          status: const Value('pending'),
          createdAt: resolvedAtUtc,
          updatedAt: resolvedAtUtc,
        ),
      );
      await _triggerWorkmanagerSafe();
    }

    return alert.copyWith(
      resolutionStatus: newStatus,
      resolutionNote: cleanNote,
      resolvedByUserId: resolverUserId,
      resolvedByName: cleanResolver,
      resolvedAtUtc: resolvedAtUtc,
      isPendingSync: pendingSync,
    );
  }

  @override
  Future<int> syncPendingAlerts({String? schoolId, String? kitchenId}) async {
    final client = _client;
    if (client == null) {
      return 0;
    }
    if (kitchenId != null && schoolId == null) {
      final result = await replayDriftSyncQueue(
        database: _database,
        client: client,
        kitchenId: kitchenId,
        operationTypes: const {'resolve_cluster_alert'},
      );
      return result.syncedCount;
    }
    final result = await replayDriftSyncQueue(
      database: _database,
      client: client,
      schoolId: schoolId,
      operationTypes: const {
        'create_alert',
        'update_alert_pdf_dispatched',
        'ack_alert',
        'resolve_cluster_alert',
      },
    );
    return result.syncedCount;
  }

  Future<void> _triggerWorkmanagerSafe() async {
    try {
      await _backgroundSyncScheduler?.scheduleImmediateConnectedSync();
    } catch (_) {
      // Non-fatal; foreground OfflineSyncController also retries automatically.
    }
  }
}

final clusterAlertRepositoryProvider = Provider<ClusterAlertRepository>((ref) {
  return SupabaseClusterAlertRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    backgroundSyncScheduler: ref.watch(backgroundSyncSchedulerProvider),
  );
});

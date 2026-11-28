import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/alerts/data/cluster_alert_repository.dart';
import '../../features/allergens/presentation/allergen_providers.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/kitchen/presentation/kitchen_providers.dart';
import '../../features/school/presentation/school_providers.dart';
import '../../features/settings/presentation/team_security_providers.dart';
import '../../features/traceability/presentation/traceability_providers.dart';
import '../database/database_provider.dart';
import '../network/connectivity_provider.dart';
import 'sync_queue_presenter.dart';

class OfflineSyncState {
  const OfflineSyncState({
    this.isSyncing = false,
    this.lastSyncedCount = 0,
    this.lastSyncedAtUtc,
    this.lastError,
    this.lastReport,
  });

  final bool isSyncing;
  final int lastSyncedCount;
  final DateTime? lastSyncedAtUtc;
  final String? lastError;
  final OfflineSyncRunReport? lastReport;

  OfflineSyncState copyWith({
    bool? isSyncing,
    int? lastSyncedCount,
    DateTime? lastSyncedAtUtc,
    String? lastError,
    bool clearError = false,
    OfflineSyncRunReport? lastReport,
  }) {
    return OfflineSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastReport: lastReport ?? this.lastReport,
    );
  }
}

/// Watches connectivity + Drift queue count and automatically replays offline data when network returns.
class OfflineSyncController extends Notifier<OfflineSyncState> {
  DateTime? _lastAutoAttemptUtc;

  @override
  OfflineSyncState build() {
    ref.listen<AsyncValue<bool>>(isOfflineProvider, (prev, next) {
      final wasOffline = prev?.value ?? true;
      final isNowOffline = next.value ?? false;
      if (!isNowOffline && wasOffline) {
        _scheduleAutoSyncIfNeeded(force: true);
      } else if (!isNowOffline) {
        _scheduleAutoSyncIfNeeded();
      }
    });

    ref.listen<AsyncValue<int>>(pendingSyncCountProvider, (prev, next) {
      final count = next.value ?? 0;
      if (count > 0) {
        _scheduleAutoSyncIfNeeded();
      }
    });

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        _scheduleAutoSyncIfNeeded();
      }
    });

    return const OfflineSyncState();
  }

  void _scheduleAutoSyncIfNeeded({bool force = false}) {
    if (state.isSyncing) {
      return;
    }
    final isOffline = ref.read(isOfflineProvider).value ?? false;
    final pendingCount = ref.read(pendingSyncCountProvider).value ?? 0;
    final auth = ref.read(authControllerProvider);
    if (isOffline ||
        pendingCount <= 0 ||
        auth.status != AuthStatus.authenticated) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    if (!force &&
        _lastAutoAttemptUtc != null &&
        nowUtc.difference(_lastAutoAttemptUtc!) < const Duration(seconds: 5)) {
      return;
    }
    _lastAutoAttemptUtc = nowUtc;
    Future.microtask(() {
      if (ref.mounted) {
        unawaited(syncNow(silent: true));
      }
    });
  }

  Future<int> syncNow({bool silent = false}) async {
    final report = await syncNowWithReport(silent: silent);
    return report.syncedCount;
  }

  Future<OfflineSyncRunReport> syncNowWithReport({bool silent = false}) async {
    if (!ref.mounted) {
      return const OfflineSyncRunReport();
    }
    if (state.isSyncing) {
      return state.lastReport ??
          OfflineSyncRunReport(
            remainingCount: ref.read(pendingSyncCountProvider).value ?? 0,
          );
    }
    final auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) {
      return OfflineSyncRunReport(
        remainingCount: ref.read(pendingSyncCountProvider).value ?? 0,
        firstFailureReason: 'Silakan masuk ke akun Anda terlebih dahulu.',
      );
    }
    final isOffline = ref.read(isOfflineProvider).value ?? false;
    if (isOffline) {
      return OfflineSyncRunReport(
        isOffline: true,
        remainingCount: ref.read(pendingSyncCountProvider).value ?? 0,
      );
    }

    final kitchen = auth.kitchen;
    final school = auth.school;
    if (kitchen == null && school == null) {
      return OfflineSyncRunReport(
        remainingCount: ref.read(pendingSyncCountProvider).value ?? 0,
        firstFailureReason:
            'Profil dapur atau sekolah belum terhubung pada akun ini.',
      );
    }

    state = state.copyWith(isSyncing: true, clearError: true);
    var totalSynced = 0;

    final isCourier = auth.profile?.role == UserRole.courier;

    try {
      if (kitchen != null && !isCourier) {
        final count = await ref
            .read(kitchenRepositoryProvider)
            .syncPendingKitchenBatches(kitchen: kitchen);
        if (!ref.mounted) {
          return OfflineSyncRunReport(syncedCount: totalSynced);
        }
        totalSynced += count;
        if (count > 0) {
          ref.invalidate(kitchenDashboardProvider);
          ref.invalidate(kitchenHistoryProvider);
        }
        final kitchenAlertCount = await ref
            .read(clusterAlertRepositoryProvider)
            .syncPendingAlerts(kitchenId: kitchen.id);
        if (!ref.mounted) {
          return OfflineSyncRunReport(syncedCount: totalSynced);
        }
        totalSynced += kitchenAlertCount;
        if (kitchenAlertCount > 0) {
          ref.invalidate(kitchenDashboardProvider);
        }
      }

      if (school != null) {
        final schoolCount = await ref
            .read(schoolRepositoryProvider)
            .syncPendingSchoolQueue(school: school);
        if (!ref.mounted) {
          return OfflineSyncRunReport(syncedCount: totalSynced);
        }
        final alertCount = await ref
            .read(clusterAlertRepositoryProvider)
            .syncPendingAlerts(schoolId: school.id);
        if (!ref.mounted) {
          return OfflineSyncRunReport(syncedCount: totalSynced);
        }
        final allergenCount = await ref
            .read(allergenRepositoryProvider)
            .syncPendingAllergenProfiles(schoolId: school.id);
        if (!ref.mounted) {
          return OfflineSyncRunReport(syncedCount: totalSynced);
        }
        final combined = schoolCount + alertCount + allergenCount;
        totalSynced += combined;
        if (combined > 0) {
          ref.invalidate(schoolDashboardProvider);
          ref.invalidate(selectableWasteBatchesProvider);
          ref.invalidate(schoolAllergensProvider);
        }
      }

      if (!isCourier && (kitchen != null || school != null)) {
        final teamSecurityCount = await ref
            .read(teamSecurityRepositoryProvider)
            .syncPendingTeamAndKeyQueue(
              kitchenId: kitchen?.id,
              schoolId: school?.id,
            );
        if (!ref.mounted) {
          return OfflineSyncRunReport(syncedCount: totalSynced);
        }
        totalSynced += teamSecurityCount;
        if (teamSecurityCount > 0) {
          ref.invalidate(teamSecurityOverviewProvider);
        }
      }

      final traceabilityCount = await ref
          .read(traceabilityRepositoryProvider)
          .syncPendingTraceabilityQueue(
            sppgId: kitchen?.id,
            schoolId: school?.id,
            operationTypes: isCourier
                ? const {'upsert_transit_handover'}
                : null,
          );
      if (!ref.mounted) {
        return OfflineSyncRunReport(syncedCount: totalSynced);
      }
      totalSynced += traceabilityCount;
      if (traceabilityCount > 0) {
        ref.invalidate(kitchenIngredientHistoryProvider);
        ref.invalidate(batchIngredientLogsProvider);
        ref.invalidate(recentKitchenBatchesForLogProvider);
        ref.invalidate(courierDeliveriesProvider);
        ref.invalidate(batchSupplyChainTimelineProvider);
        ref.invalidate(schoolTrayReturnsProvider);
        ref.invalidate(kitchenTrayReturnsProvider);
      }

      final report = await _buildRunReport(
        syncedCount: totalSynced,
        kitchen: kitchen,
        school: school,
      );

      if (ref.mounted) {
        state = OfflineSyncState(
          isSyncing: false,
          lastSyncedCount: totalSynced,
          lastSyncedAtUtc: DateTime.now().toUtc(),
          lastError: !silent && report.hasFailure
              ? report.firstFailureReason
              : null,
          lastReport: report,
        );
      }
      return report;
    } catch (error) {
      final friendly = formatFriendlySyncError(error.toString());
      final report = await _buildRunReport(
        syncedCount: totalSynced,
        kitchen: kitchen,
        school: school,
        fallbackError: friendly,
      );
      if (ref.mounted) {
        state = state.copyWith(
          isSyncing: false,
          lastError: silent ? null : (report.firstFailureReason ?? friendly),
          lastReport: report,
        );
      }
      return report;
    }
  }

  Future<OfflineSyncRunReport> _buildRunReport({
    required int syncedCount,
    KitchenProfile? kitchen,
    SchoolProfile? school,
    String? fallbackError,
  }) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final remainingRows = await db.getPendingSyncItems();
      final summaries = summarizePendingSyncItems(
        remainingRows,
        kitchen: kitchen,
        school: school,
      );
      final failedSummaries = summaries.where((item) => item.isFailed).toList();
      final otherAccountCount =
          summaries.where((item) => !item.belongsToCurrentAccount).length;
      final remainingCount = remainingRows.isNotEmpty
          ? remainingRows.length
          : (syncedCount == 0
                ? (ref.read(pendingSyncCountProvider).value ?? 0)
                : 0);
      final firstFailure = failedSummaries.isNotEmpty
          ? failedSummaries.first.friendlyError
          : fallbackError;

      return OfflineSyncRunReport(
        syncedCount: syncedCount,
        remainingCount: remainingCount,
        failedCount: failedSummaries.isNotEmpty || fallbackError == null
            ? failedSummaries.length
            : (remainingCount > 0 ? remainingCount : 1),
        otherAccountCount: otherAccountCount,
        firstFailureReason: firstFailure,
      );
    } catch (_) {
      final remainingCount = ref.read(pendingSyncCountProvider).value ?? 0;
      return OfflineSyncRunReport(
        syncedCount: syncedCount,
        remainingCount: remainingCount,
        failedCount: fallbackError != null ? remainingCount : 0,
        firstFailureReason: fallbackError,
      );
    }
  }

  Future<void> removeQueuedItem(int id) async {
    await ref.read(appDatabaseProvider).deleteSyncItemById(id);
  }

  Future<int> removeOtherAccountItems() async {
    final auth = ref.read(authControllerProvider);
    final db = ref.read(appDatabaseProvider);
    final rows = await db.getPendingSyncItems();
    final summaries = summarizePendingSyncItems(
      rows,
      kitchen: auth.kitchen,
      school: auth.school,
      isAuthenticated: auth.status == AuthStatus.authenticated,
    );
    final idsToDelete = summaries
        .where((item) => !item.belongsToCurrentAccount)
        .map((item) => item.id)
        .toList();
    return db.deleteSyncItemsByIds(idsToDelete);
  }
}

final offlineSyncControllerProvider =
    NotifierProvider<OfflineSyncController, OfflineSyncState>(
      OfflineSyncController.new,
    );

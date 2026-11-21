import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/notifications/fcm_alert_service.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/presentation/kitchen_providers.dart';
import '../data/cluster_alert_repository.dart';
import '../domain/cluster_alert_models.dart';

class ClusterAlertOverlayState {
  const ClusterAlertOverlayState({
    this.activeAlert,
    this.pendingQueue = const [],
    this.isAcknowledging = false,
    this.handledIds = const {},
  });

  final ClusterAlertEvent? activeAlert;
  final List<ClusterAlertEvent> pendingQueue;
  final bool isAcknowledging;
  final Set<String> handledIds;

  ClusterAlertOverlayState copyWith({
    ClusterAlertEvent? activeAlert,
    bool clearActive = false,
    List<ClusterAlertEvent>? pendingQueue,
    bool? isAcknowledging,
    Set<String>? handledIds,
  }) {
    return ClusterAlertOverlayState(
      activeAlert: clearActive ? null : (activeAlert ?? this.activeAlert),
      pendingQueue: pendingQueue ?? this.pendingQueue,
      isAcknowledging: isAcknowledging ?? this.isAcknowledging,
      handledIds: handledIds ?? this.handledIds,
    );
  }
}

/// Manages Realtime + FCM cluster alert intake strictly filtered by active `sppg_id`.
class ClusterAlertController extends Notifier<ClusterAlertOverlayState> {
  StreamSubscription<ClusterAlertEvent>? _realtimeSub;
  StreamSubscription<ClusterAlertEvent>? _fcmSub;
  FcmAlertService? _fcmService;
  String? _boundSessionKey;

  @override
  ClusterAlertOverlayState build() {
    _fcmService = ref.read(fcmAlertServiceProvider);
    ref.onDispose(() {
      unawaited(_unbindListeners());
    });

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      unawaited(_syncBindingWithAuth(next));
    });

    final initialAuth = ref.read(authControllerProvider);
    if (initialAuth.status == AuthStatus.authenticated) {
      Future.microtask(() {
        if (ref.mounted) {
          unawaited(_syncBindingWithAuth(initialAuth));
        }
      });
    }

    return const ClusterAlertOverlayState();
  }

  ({String userId, String sppgId, String? excludeSchoolId})? _resolveScope(
    AuthState auth,
  ) {
    if (auth.status != AuthStatus.authenticated || auth.profile == null) {
      return null;
    }
    if (auth.profile!.role == UserRole.kitchen && auth.kitchen != null) {
      return (
        userId: auth.profile!.id,
        sppgId: auth.kitchen!.id,
        excludeSchoolId: null,
      );
    }
    if (auth.profile!.role == UserRole.school &&
        auth.school != null &&
        auth.school!.verificationStatus == SchoolVerificationStatus.approved &&
        auth.school!.sppgId != null &&
        auth.school!.sppgId!.isNotEmpty) {
      return (
        userId: auth.profile!.id,
        sppgId: auth.school!.sppgId!,
        excludeSchoolId: auth.school!.id,
      );
    }
    return null;
  }

  Future<void> _syncBindingWithAuth(AuthState auth) async {
    if (!ref.mounted) {
      return;
    }
    final scope = _resolveScope(auth);
    if (scope == null) {
      _boundSessionKey = null;
      await _unbindListeners();
      if (ref.mounted) {
        state = const ClusterAlertOverlayState();
      }
      return;
    }

    final nextKey =
        '${scope.userId}:${scope.sppgId}:${scope.excludeSchoolId ?? 'kitchen'}';
    if (_boundSessionKey == nextKey) {
      return;
    }
    _boundSessionKey = nextKey;
    await _unbindListeners();
    if (!ref.mounted) {
      return;
    }
    state = const ClusterAlertOverlayState();

    final repo = ref.read(clusterAlertRepositoryProvider);
    final fcm = ref.read(fcmAlertServiceProvider);
    _fcmService = fcm;
    final client = ref.read(supabaseClientProvider);

    unawaited(
      fcm.initializeAndBind(
        userId: scope.userId,
        sppgId: scope.sppgId,
        excludeSchoolId: scope.excludeSchoolId,
        client: client,
      ),
    );

    _fcmSub = fcm.alertStream.listen(enqueueIncomingAlert);
    _realtimeSub = repo
        .watchRealtimeAlerts(
          sppgId: scope.sppgId,
          excludeSchoolId: scope.excludeSchoolId,
        )
        .listen(enqueueIncomingAlert);

    final pendingToday = await repo.fetchUnacknowledgedAlertsForToday(
      sppgId: scope.sppgId,
      currentSchoolId: scope.excludeSchoolId,
    );
    if (!ref.mounted) {
      return;
    }
    for (final item in pendingToday.reversed) {
      enqueueIncomingAlert(item);
    }
  }

  Future<void> _unbindListeners() async {
    final realtimeSub = _realtimeSub;
    _realtimeSub = null;
    final fcmSub = _fcmSub;
    _fcmSub = null;
    await realtimeSub?.cancel();
    await fcmSub?.cancel();
    try {
      await _fcmService?.clearBinding();
    } catch (_) {
      // Safe when container disposes before async unbind completes.
    }
  }

  void enqueueIncomingAlert(ClusterAlertEvent event) {
    if (!ref.mounted) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    final scope = _resolveScope(auth);
    if (scope == null) {
      return;
    }
    // Hard tenant isolation + self-report + broadcast guards.
    if (!event.broadcastEnabled || event.sppgId != scope.sppgId) {
      return;
    }
    if (scope.excludeSchoolId != null &&
        event.reporterSchoolId == scope.excludeSchoolId) {
      return;
    }

    if (auth.profile?.role == UserRole.kitchen) {
      ref.invalidate(kitchenDashboardProvider);
    }

    if (state.handledIds.contains(event.id) ||
        state.activeAlert?.id == event.id ||
        state.pendingQueue.any((e) => e.id == event.id)) {
      return;
    }

    if (state.activeAlert == null) {
      state = state.copyWith(activeAlert: event);
    } else {
      state = state.copyWith(pendingQueue: [...state.pendingQueue, event]);
    }
  }

  Future<void> acknowledgeActiveAlert() async {
    final active = state.activeAlert;
    if (active == null || state.isAcknowledging) {
      return;
    }

    state = state.copyWith(isAcknowledging: true);
    final auth = ref.read(authControllerProvider);
    final school = auth.school;

    if (school != null) {
      final isOffline = ref.read(isOfflineProvider).value ?? false;
      try {
        await ref.read(clusterAlertRepositoryProvider).acknowledgeAlert(
              alertId: active.id,
              schoolId: school.id,
              isOffline: isOffline,
            );
      } catch (_) {
        // Queue fallback handled inside repository.
      }
    }
    if (!ref.mounted) {
      return;
    }

    final nextHandled = {...state.handledIds, active.id};
    final remaining = state.pendingQueue;
    if (remaining.isEmpty) {
      state = ClusterAlertOverlayState(
        activeAlert: null,
        pendingQueue: const [],
        isAcknowledging: false,
        handledIds: nextHandled,
      );
    } else {
      state = ClusterAlertOverlayState(
        activeAlert: remaining.first,
        pendingQueue: remaining.sublist(1),
        isAcknowledging: false,
        handledIds: nextHandled,
      );
    }
  }
}

final clusterAlertControllerProvider =
    NotifierProvider<ClusterAlertController, ClusterAlertOverlayState>(
      ClusterAlertController.new,
    );

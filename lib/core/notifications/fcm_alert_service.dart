import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/alerts/domain/cluster_alert_models.dart';
import 'local_notification_service.dart';

/// High-priority background handler executed when FCM wakes a locked/terminated device.
@pragma('vm:entry-point')
Future<void> lacakFcmBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Allow graceful exit if Firebase options are not bundled.
  }

  final event = ClusterAlertEvent.fromFcmData(message.data);
  if (event == null || !event.broadcastEnabled) {
    return;
  }

  try {
    await FlutterLocalNotificationService().showClusterAlertNotification(event);
  } catch (_) {
    // Non-fatal in headless background tests.
  }
}

abstract class FcmAlertService {
  Stream<ClusterAlertEvent> get alertStream;

  Future<void> initializeAndBind({
    required String userId,
    required String sppgId,
    String? excludeSchoolId,
    required SupabaseClient? client,
  });

  Future<void> clearBinding();

  void dispose();
}

String sppgFcmTopicName(String sppgId) {
  final sanitized = sppgId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');
  return 'sppg_$sanitized';
}

class FirebaseFcmAlertService implements FcmAlertService {
  FirebaseFcmAlertService({LocalNotificationService? notificationService})
      : _notificationService =
            notificationService ?? FlutterLocalNotificationService();

  final LocalNotificationService _notificationService;
  final StreamController<ClusterAlertEvent> _alertController =
      StreamController<ClusterAlertEvent>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;

  String? _activeSppgId;
  String? _excludeSchoolId;
  String? _subscribedTopic;
  bool _listenersAttached = false;

  bool get _supportsFcm => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Stream<ClusterAlertEvent> get alertStream => _alertController.stream;

  @override
  Future<void> initializeAndBind({
    required String userId,
    required String sppgId,
    String? excludeSchoolId,
    required SupabaseClient? client,
  }) async {
    _activeSppgId = sppgId;
    _excludeSchoolId = excludeSchoolId;

    if (!_supportsFcm) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(lacakFcmBackgroundHandler);

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final nextTopic = sppgFcmTopicName(sppgId);
      if (_subscribedTopic != null && _subscribedTopic != nextTopic) {
        try {
          await messaging.unsubscribeFromTopic(_subscribedTopic!);
        } catch (_) {}
      }
      if (_subscribedTopic != nextTopic) {
        await messaging.subscribeToTopic(nextTopic);
        _subscribedTopic = nextTopic;
      }

      if (client != null) {
        await _tokenRefreshSub?.cancel();
        _tokenRefreshSub = messaging.onRegistered.listen((newToken) async {
          if (newToken.trim().isNotEmpty) {
            await _syncTokenToProfile(
              client: client,
              userId: userId,
              token: newToken,
            );
          }
        });
        await messaging.register();
      }

      if (!_listenersAttached) {
        _listenersAttached = true;
        _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
          _handleRemoteMessage(msg, alsoShowLocalHeadsUp: true);
        });
        _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
          _handleRemoteMessage(msg, alsoShowLocalHeadsUp: false);
        });
        final initialMsg = await messaging.getInitialMessage();
        if (initialMsg != null) {
          _handleRemoteMessage(initialMsg, alsoShowLocalHeadsUp: false);
        }
      }
    } catch (_) {
      // Safe fallback: if google-services.json is absent, Realtime channel still delivers alerts.
    }
  }

  void _handleRemoteMessage(
    RemoteMessage message, {
    required bool alsoShowLocalHeadsUp,
  }) {
    final event = ClusterAlertEvent.fromFcmData(message.data);
    if (event == null || !event.broadcastEnabled) {
      return;
    }
    if (_activeSppgId == null || event.sppgId != _activeSppgId) {
      return;
    }
    if (_excludeSchoolId != null &&
        event.reporterSchoolId == _excludeSchoolId) {
      return;
    }

    if (alsoShowLocalHeadsUp) {
      unawaited(_notificationService.showClusterAlertNotification(event));
    }
    if (!_alertController.isClosed) {
      _alertController.add(event);
    }
  }

  Future<void> _syncTokenToProfile({
    required SupabaseClient client,
    required String userId,
    required String token,
  }) async {
    try {
      await client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (_) {
      // Token refresh retry happens on next session resume.
    }
  }

  @override
  Future<void> clearBinding() async {
    _activeSppgId = null;
    _excludeSchoolId = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (_supportsFcm && _subscribedTopic != null) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_subscribedTopic!);
      } catch (_) {}
      _subscribedTopic = null;
    }
  }

  @override
  void dispose() {
    unawaited(_onMessageSub?.cancel());
    unawaited(_onOpenedSub?.cancel());
    unawaited(_tokenRefreshSub?.cancel());
    if (!_alertController.isClosed) {
      unawaited(_alertController.close());
    }
  }
}

final fcmAlertServiceProvider = Provider<FcmAlertService>((ref) {
  final service = FirebaseFcmAlertService(
    notificationService: ref.watch(localNotificationServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

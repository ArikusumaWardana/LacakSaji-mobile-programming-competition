import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/alerts/domain/cluster_alert_models.dart';

abstract class LocalNotificationService {
  Future<void> initialize();

  Future<void> scheduleSampleVaultReminder({
    required String sampleId,
    required String labelCode,
    required String menuName,
    required DateTime expiresAtUtc,
  });

  Future<void> cancelSampleVaultReminder(String sampleId);

  Future<void> showClusterAlertNotification(ClusterAlertEvent event);
}

class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const String _channelId = 'lacak_sample_vault_48h';
  static const String _channelName = 'Pengingat Bank Sampel 48 Jam';
  static const String _channelDescription =
      'Notifikasi pengingat batas retensi 2x24 jam sampel makanan sekolah sesuai Perbagi No. 4 Tahun 2026.';

  static const String _emergencyChannelId = 'lacak_cluster_alert_emergency';
  static const String _emergencyChannelName = 'Peringatan Darurat Makanan';
  static const String _emergencyChannelDescription =
      'Alarm darurat penahanan distribusi makanan dan dugaan KLB antar sekolah mitra SPPG.';

  static int notificationIdForSample(String sampleId) {
    return sampleId.hashCode & 0x7fffffff;
  }

  static int notificationIdForAlert(String alertId) {
    return (alertId.hashCode & 0x3fffffff) + 100000;
  }

  bool get _supportsAndroidNotifications => !kIsWeb && Platform.isAndroid;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tzdata.initializeTimeZones();
    if (!_supportsAndroidNotifications) {
      _initialized = true;
      return;
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  @override
  Future<void> scheduleSampleVaultReminder({
    required String sampleId,
    required String labelCode,
    required String menuName,
    required DateTime expiresAtUtc,
  }) async {
    await initialize();
    if (!_supportsAndroidNotifications) {
      return;
    }

    final scheduled = tz.TZDateTime.from(expiresAtUtc.toUtc(), tz.UTC);
    final id = notificationIdForSample(sampleId);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final title = sanitizeZeroSlopCopy('Batas Simpan Sampel 48 Jam: $labelCode');
    final body = sanitizeZeroSlopCopy(
      'Masa retensi Bank Sampel untuk menu $menuName telah mencapai 48 jam. Periksa status sebelum dimusnahkan.',
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: sampleId,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: sampleId,
      );
    }
  }

  @override
  Future<void> cancelSampleVaultReminder(String sampleId) async {
    if (!_supportsAndroidNotifications) {
      return;
    }
    await _plugin.cancel(id: notificationIdForSample(sampleId));
  }

  @override
  Future<void> showClusterAlertNotification(ClusterAlertEvent event) async {
    await initialize();
    if (!_supportsAndroidNotifications) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _emergencyChannelId,
        _emergencyChannelName,
        channelDescription: _emergencyChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        color: Color(0xFF9B2226),
      ),
    );

    final title = 'PERINGATAN DARURAT MAKANAN';
    final body = event.instructionText;
    await _plugin.show(
      id: notificationIdForAlert(event.id),
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'cluster_alert:${event.id}',
    );
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return FlutterLocalNotificationService();
});

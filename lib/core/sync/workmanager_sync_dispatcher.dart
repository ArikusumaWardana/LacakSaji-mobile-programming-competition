import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env_config.dart';
import '../database/app_database.dart';
import 'offline_sync_service.dart';

const String kLacakSyncPeriodicUniqueName = 'lacak_saji_periodic_offline_sync';
const String kLacakSyncOneOffUniqueName = 'lacak_saji_oneoff_offline_sync';
const String kLacakSyncTaskName = 'lacakSajiOfflineSyncTask';

@pragma('vm:entry-point')
void lacakWorkmanagerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // Proceed if already loaded or unavailable in headless test env.
      }
      if (!EnvConfig.isConfigured) {
        return true;
      }
      SupabaseClient client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: EnvConfig.supabaseUrl,
          publishableKey: EnvConfig.supabaseClientKey,
        );
        client = Supabase.instance.client;
      }
      if (client.auth.currentSession == null || client.auth.currentUser == null) {
        return true;
      }

      final db = AppDatabase();
      try {
        final result = await replayDriftSyncQueue(
          database: db,
          client: client,
        );
        return result.failedCount == 0;
      } finally {
        await db.close();
      }
    } catch (_) {
      return false;
    }
  });
}

abstract class BackgroundSyncScheduler {
  Future<void> initialize();

  Future<void> scheduleImmediateConnectedSync();
}

class AndroidWorkmanagerSyncScheduler implements BackgroundSyncScheduler {
  bool _initialized = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<void> initialize() async {
    if (_initialized || !_supported) {
      return;
    }
    try {
      await Workmanager().initialize(lacakWorkmanagerDispatcher);
      await Workmanager().registerPeriodicTask(
        kLacakSyncPeriodicUniqueName,
        kLacakSyncTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
      _initialized = true;
    } catch (_) {
      // Non-fatal in environments without WorkManager plugin binding.
    }
  }

  @override
  Future<void> scheduleImmediateConnectedSync() async {
    if (!_supported) {
      return;
    }
    try {
      await initialize();
      await Workmanager().registerOneOffTask(
        kLacakSyncOneOffUniqueName,
        kLacakSyncTaskName,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (_) {
      // Foreground controller still retries as soon as network returns.
    }
  }
}

final backgroundSyncSchedulerProvider = Provider<BackgroundSyncScheduler>((
  ref,
) {
  return AndroidWorkmanagerSyncScheduler();
});

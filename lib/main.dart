import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env_config.dart';
import 'core/constants/app_constants.dart';
import 'core/network/supabase_provider.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/sync/workmanager_sync_dispatcher.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/text_scale_provider.dart';
import 'core/widgets/lacak_cluster_alert_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce portrait-only mode across Android phones and tablets.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  try {
    await FlutterLocalNotificationService().initialize();
  } catch (_) {
    // Allow app boot cleanly if notification initialization fails on unsupported targets.
  }

  try {
    await AndroidWorkmanagerSyncScheduler().initialize();
  } catch (_) {
    // Allow app boot cleanly if WorkManager binding is unavailable on host target.
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Allow app boot in offline or test environments without a bundled `.env`.
  }

  final prefs = await SharedPreferences.getInstance();

  var supabaseReady = false;
  if (EnvConfig.isConfigured) {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseClientKey,
    );
    supabaseReady = true;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isSupabaseReadyProvider.overrideWithValue(supabaseReady),
      ],
      child: const LacakSajiApp(),
    ),
  );
}

class LacakSajiApp extends ConsumerWidget {
  const LacakSajiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        return _ComfortableTextScaleHost(
          child: GlobalEmergencySyncHost(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Watches [textScaleProvider] inside [MaterialApp.builder] so changing the
/// scale immediately rebuilds the [MediaQuery] ancestor for all routes.
class _ComfortableTextScaleHost extends ConsumerWidget {
  const _ComfortableTextScaleHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comfortableScale = ref.watch(textScaleProvider);
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: effectiveTextScaler(mediaQuery, comfortableScale),
      ),
      child: child,
    );
  }
}

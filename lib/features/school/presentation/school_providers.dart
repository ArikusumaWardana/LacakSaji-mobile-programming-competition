import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/bmkg_weather_service.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/school_repository.dart';
import '../domain/school_models.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SupabaseSchoolRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    ed25519Service: ref.watch(ed25519ServiceProvider),
    bmkgService: ref.watch(bmkgWeatherServiceProvider),
    notificationService: ref.watch(localNotificationServiceProvider),
    backgroundSyncScheduler: ref.watch(backgroundSyncSchedulerProvider),
  );
});

final schoolDashboardProvider = FutureProvider.autoDispose<SchoolDashboardData>((
  ref,
) async {
  final school = ref.watch(authControllerProvider).school;
  if (school == null) {
    throw StateError('Profil sekolah belum termuat.');
  }
  final isOffline = ref.watch(isOfflineProvider).value ?? false;
  return ref
      .watch(schoolRepositoryProvider)
      .fetchDashboardData(school: school, isOffline: isOffline);
});

final activeSampleVaultsProvider =
    StreamProvider.autoDispose<List<SampleVaultItem>>((ref) {
      final school = ref.watch(authControllerProvider).school;
      if (school == null) {
        return Stream.value(const []);
      }
      return ref.watch(schoolRepositoryProvider).watchActiveSamples(school.id);
    });

final historySampleVaultsProvider =
    StreamProvider.autoDispose<List<SampleVaultItem>>((ref) {
      final school = ref.watch(authControllerProvider).school;
      if (school == null) {
        return Stream.value(const []);
      }
      return ref.watch(schoolRepositoryProvider).watchHistorySamples(school.id);
    });

final selectableWasteBatchesProvider =
    FutureProvider.autoDispose<List<SchoolBatchOption>>((ref) async {
      final school = ref.watch(authControllerProvider).school;
      if (school == null) {
        return const [];
      }
      final isOffline = ref.watch(isOfflineProvider).value ?? false;
      return ref
          .watch(schoolRepositoryProvider)
          .fetchSelectableBatchesForWaste(
            school: school,
            isOffline: isOffline,
          );
    });

void invalidateSchoolProviders(WidgetRef ref) {
  ref.invalidate(schoolDashboardProvider);
  ref.invalidate(selectableWasteBatchesProvider);
}

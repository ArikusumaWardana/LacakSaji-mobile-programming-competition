import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/allergen_repository.dart';
import '../domain/allergen_models.dart';

final allergenRepositoryProvider = Provider<AllergenRepository>((ref) {
  return SupabaseAllergenRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    backgroundSyncScheduler: ref.watch(backgroundSyncSchedulerProvider),
  );
});

final schoolAllergensProvider =
    FutureProvider.autoDispose<List<SchoolAllergenEntry>>((ref) async {
      final school = ref.watch(authControllerProvider).school;
      if (school == null) {
        return const [];
      }
      final isOffline = ref.watch(isOfflineProvider).value ?? false;
      return ref
          .watch(allergenRepositoryProvider)
          .fetchSchoolAllergens(schoolId: school.id, isOffline: isOffline);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) {
  return SupabaseKitchenRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    ed25519Service: ref.watch(ed25519ServiceProvider),
    backgroundSyncScheduler: ref.watch(backgroundSyncSchedulerProvider),
  );
});

class KitchenHistoryRangeNotifier extends Notifier<HistoryTimeRange> {
  @override
  HistoryTimeRange build() => HistoryTimeRange.last7Days;

  void selectRange(HistoryTimeRange next) {
    if (state != next) {
      state = next;
    }
  }
}

final kitchenHistoryRangeProvider =
    NotifierProvider<KitchenHistoryRangeNotifier, HistoryTimeRange>(
      KitchenHistoryRangeNotifier.new,
    );

final kitchenDashboardProvider = FutureProvider.autoDispose<KitchenDashboardData>((
  ref,
) async {
  final kitchen = ref.watch(authControllerProvider).kitchen;
  if (kitchen == null) {
    throw StateError('Profil dapur SPPG belum termuat.');
  }
  return ref.watch(kitchenRepositoryProvider).fetchDashboard(kitchen: kitchen);
});

final kitchenSchoolsProvider =
    FutureProvider.autoDispose<List<PartnerSchoolItem>>((ref) async {
      final kitchen = ref.watch(authControllerProvider).kitchen;
      if (kitchen == null) {
        return const [];
      }
      return ref
          .watch(kitchenRepositoryProvider)
          .fetchPartnerSchools(sppgId: kitchen.id);
    });

final kitchenHistoryProvider = FutureProvider.autoDispose<KitchenHistoryData>((
  ref,
) async {
  final kitchen = ref.watch(authControllerProvider).kitchen;
  if (kitchen == null) {
    return const KitchenHistoryData(
      range: HistoryTimeRange.last7Days,
      batches: [],
      wasteLogs: [],
      wasteSummary: PlateWasteSummary.empty,
    );
  }
  final range = ref.watch(kitchenHistoryRangeProvider);
  return ref
      .watch(kitchenRepositoryProvider)
      .fetchHistoryAndWaste(kitchen: kitchen, range: range);
});

final kitchenBatchDetailProvider =
    FutureProvider.autoDispose.family<FoodBatchItem?, String>((
      ref,
      batchId,
    ) async {
      final kitchen = ref.watch(authControllerProvider).kitchen;
      if (kitchen == null) {
        return null;
      }
      return ref
          .watch(kitchenRepositoryProvider)
          .fetchBatchById(kitchen: kitchen, batchId: batchId);
    });

void invalidateKitchenProviders(WidgetRef ref) {
  ref.invalidate(kitchenDashboardProvider);
  ref.invalidate(kitchenSchoolsProvider);
  ref.invalidate(kitchenHistoryProvider);
}

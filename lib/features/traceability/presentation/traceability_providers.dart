import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/sync/workmanager_sync_dispatcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../data/traceability_repository.dart';
import '../domain/traceability_models.dart';

final traceabilityRepositoryProvider = Provider<TraceabilityRepository>((ref) {
  return SupabaseTraceabilityRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    backgroundSyncScheduler: ref.watch(backgroundSyncSchedulerProvider),
  );
});

final kitchenIngredientHistoryProvider =
    FutureProvider.autoDispose<List<IngredientLogItem>>((ref) async {
      final kitchen = ref.watch(authControllerProvider).kitchen;
      if (kitchen == null) {
        return const [];
      }
      return ref
          .watch(traceabilityRepositoryProvider)
          .fetchIngredientHistoryBySppg(sppgId: kitchen.id);
    });

final batchIngredientLogsProvider = FutureProvider.autoDispose
    .family<List<IngredientLogItem>, ({String sppgId, String batchId})>((
      ref,
      arg,
    ) async {
      if (arg.sppgId.isEmpty || arg.batchId.isEmpty) {
        return const [];
      }
      return ref
          .watch(traceabilityRepositoryProvider)
          .fetchIngredientLogsByBatch(
            sppgId: arg.sppgId,
            batchId: arg.batchId,
          );
    });

final recentKitchenBatchesForLogProvider =
    FutureProvider.autoDispose<List<FoodBatchItem>>((ref) async {
      final kitchen = ref.watch(authControllerProvider).kitchen;
      if (kitchen == null) {
        return const [];
      }
      return ref
          .watch(traceabilityRepositoryProvider)
          .fetchRecentKitchenBatches(kitchen: kitchen, days: 7);
    });

final courierDeliveriesProvider =
    FutureProvider.autoDispose<List<CourierBatchDeliveryItem>>((ref) async {
      final kitchen = ref.watch(authControllerProvider).kitchen;
      if (kitchen == null) {
        return const [];
      }
      return ref
          .watch(traceabilityRepositoryProvider)
          .fetchCourierDeliveries(kitchen: kitchen);
    });

final batchSupplyChainTimelineProvider = FutureProvider.autoDispose.family<
  SupplyChainTimelineData,
  ({
    String sppgId,
    String batchId,
    DateTime sealedAtUtc,
    DateTime? schoolScannedAtUtc,
  })
>((ref, arg) async {
  return ref
      .watch(traceabilityRepositoryProvider)
      .fetchSupplyChainTimeline(
        sppgId: arg.sppgId,
        batchId: arg.batchId,
        sealedAtUtc: arg.sealedAtUtc,
        schoolScannedAtUtc: arg.schoolScannedAtUtc,
      );
});

final schoolTrayReturnsProvider =
    FutureProvider.autoDispose<List<TrayReturnLogItem>>((ref) async {
      final school = ref.watch(authControllerProvider).school;
      if (school == null) {
        return const [];
      }
      return ref
          .watch(traceabilityRepositoryProvider)
          .fetchSchoolTrayReturns(schoolId: school.id);
    });

final kitchenTrayReturnsProvider =
    FutureProvider.autoDispose<List<TrayReturnLogItem>>((ref) async {
      final kitchen = ref.watch(authControllerProvider).kitchen;
      if (kitchen == null) {
        return const [];
      }
      return ref
          .watch(traceabilityRepositoryProvider)
          .fetchKitchenTrayReturns(sppgId: kitchen.id);
    });

void invalidateTraceabilityProviders(WidgetRef ref) {
  ref.invalidate(kitchenIngredientHistoryProvider);
  ref.invalidate(batchIngredientLogsProvider);
  ref.invalidate(recentKitchenBatchesForLogProvider);
  ref.invalidate(courierDeliveriesProvider);
  ref.invalidate(batchSupplyChainTimelineProvider);
  ref.invalidate(schoolTrayReturnsProvider);
  ref.invalidate(kitchenTrayReturnsProvider);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/supervisor_repository.dart';
import '../domain/supervisor_models.dart';

final supervisorRepositoryProvider = Provider<SupervisorRepository>((ref) {
  return SupabaseSupervisorRepository(
    client: ref.watch(supabaseClientProvider),
  );
});

class _SupervisorDateFilterNotifier extends Notifier<SupervisorDateFilter> {
  @override
  SupervisorDateFilter build() => SupervisorDateFilter.last30Days;

  void setFilter(SupervisorDateFilter filter) => state = filter;
}

final supervisorDateFilterProvider =
    NotifierProvider<_SupervisorDateFilterNotifier, SupervisorDateFilter>(
      _SupervisorDateFilterNotifier.new,
    );

class _SupervisorRegionFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Semua Wilayah';

  void setRegion(String region) => state = region;
}

final supervisorRegionFilterProvider =
    NotifierProvider<_SupervisorRegionFilterNotifier, String>(
      _SupervisorRegionFilterNotifier.new,
    );

final supervisorOverviewProvider =
    FutureProvider.autoDispose<SupervisorNationalOverview>((ref) async {
      final profile = ref.watch(authControllerProvider).profile;
      if (profile == null) {
        throw StateError('Sesi pengawas tidak aktif.');
      }
      final dateFilter = ref.watch(supervisorDateFilterProvider);
      final regionFilter = ref.watch(supervisorRegionFilterProvider);
      return ref
          .watch(supervisorRepositoryProvider)
          .fetchNationalOverview(
            dateFilter: dateFilter,
            regionFilter: regionFilter,
          );
    });

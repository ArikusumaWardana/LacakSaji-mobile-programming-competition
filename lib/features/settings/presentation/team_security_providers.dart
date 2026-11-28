import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/ed25519_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/supabase_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/team_security_repository.dart';
import '../domain/team_security_models.dart';

final teamSecurityRepositoryProvider = Provider<TeamSecurityRepository>((ref) {
  return SupabaseTeamSecurityRepository(
    client: ref.watch(supabaseClientProvider),
    database: ref.watch(appDatabaseProvider),
    ed25519Service: ref.watch(ed25519ServiceProvider),
  );
});

final teamSecurityOverviewProvider =
    FutureProvider.autoDispose<TeamSecurityOverview>((ref) {
      final authState = ref.watch(authControllerProvider);
      final isOffline = ref.watch(isOfflineProvider).value ?? false;
      return ref
          .read(teamSecurityRepositoryProvider)
          .fetchOverview(authState: authState, isOffline: isOffline);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_verification_screen.dart';
import '../../features/auth/presentation/register_kitchen_screen.dart';
import '../../features/auth/presentation/register_school_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/courier/presentation/courier_dashboard_screen.dart';
import '../../features/courier/presentation/courier_scan_screen.dart';
import '../../features/kitchen/domain/kitchen_models.dart';
import '../../features/kitchen/presentation/batch_qr_detail_screen.dart';
import '../../features/kitchen/presentation/create_batch_screen.dart';
import '../../features/kitchen/presentation/ingredient_history_screen.dart';
import '../../features/kitchen/presentation/kitchen_dashboard_screen.dart';
import '../../features/kitchen/presentation/kitchen_history_screen.dart';
import '../../features/kitchen/presentation/kitchen_schools_screen.dart';
import '../../features/kitchen/presentation/tray_logistics_screen.dart';
import '../../features/alerts/domain/cluster_alert_models.dart';
import '../../features/school/domain/school_models.dart';
import '../../features/school/presentation/anomaly_report_screen.dart';
import '../../features/school/presentation/danger_zone_gate_screen.dart';
import '../../features/school/presentation/plate_waste_screen.dart';
import '../../features/school/presentation/puskesmas_report_draft_screen.dart';
import '../../features/school/presentation/sample_vault_screen.dart';
import '../../features/school/presentation/scan_qr_screen.dart';
import '../../features/school/presentation/school_dashboard_screen.dart';
import '../../features/school/presentation/visual_audit_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/team_security_screen.dart';
import '../../features/supervisor/presentation/supervisor_home_screen.dart';
import '../../features/traceability/domain/traceability_models.dart';
import '../constants/app_routes.dart';
import '../widgets/lacak_adaptive_shell.dart';

class _RouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable();

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.status != next.status ||
        previous?.profile?.role != next.profile?.role ||
        previous?.school?.verificationStatus !=
            next.school?.verificationStatus ||
        previous?.holdKitchenActivationSummary !=
            next.holdKitchenActivationSummary) {
      refreshListenable.refresh();
    }
  });

  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (authState.status == AuthStatus.initializing) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      const publicAuthRoutes = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.registerKitchen,
        AppRoutes.registerSchool,
      };

      if (authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.awaitingEmailConfirmation) {
        return publicAuthRoutes.contains(location) ? null : AppRoutes.login;
      }

      if (authState.holdKitchenActivationSummary) {
        return null;
      }

      final target = authState.landingRoute;
      if (location == AppRoutes.splash || publicAuthRoutes.contains(location)) {
        return target;
      }

      final role = authState.profile?.role;
      if (role == UserRole.school &&
          authState.school?.verificationStatus !=
              SchoolVerificationStatus.approved) {
        if (location != AppRoutes.pendingVerification &&
            location != AppRoutes.settings) {
          return AppRoutes.pendingVerification;
        }
        return null;
      }

      if (role == UserRole.kitchen &&
          (location.startsWith(AppRoutes.schoolHome) ||
              location.startsWith(AppRoutes.courierHome) ||
              location == AppRoutes.pendingVerification ||
              location.startsWith(AppRoutes.supervisor))) {
        return AppRoutes.kitchenHome;
      }

      if (role == UserRole.courier &&
          (location.startsWith(AppRoutes.kitchenHome) ||
              location.startsWith(AppRoutes.schoolHome) ||
              location == AppRoutes.pendingVerification ||
              location == AppRoutes.settingsTeamSecurity ||
              location.startsWith(AppRoutes.supervisor))) {
        return AppRoutes.courierHome;
      }

      if (role == UserRole.school &&
          (location.startsWith(AppRoutes.kitchenHome) ||
              location.startsWith(AppRoutes.courierHome) ||
              location == AppRoutes.pendingVerification ||
              location.startsWith(AppRoutes.supervisor))) {
        return AppRoutes.schoolHome;
      }

      if (role == UserRole.supervisor &&
          location != AppRoutes.supervisor &&
          location != AppRoutes.supervisorSettings &&
          location != AppRoutes.settings) {
        return AppRoutes.supervisor;
      }

      if (location == AppRoutes.settingsTeamSecurity &&
          !authState.isInstitutionAdmin) {
        return target;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerKitchen,
        builder: (context, state) => const RegisterKitchenScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerSchool,
        builder: (context, state) => const RegisterSchoolScreen(),
      ),
      GoRoute(
        path: AppRoutes.pendingVerification,
        builder: (context, state) => const PendingVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsTeamSecurity,
        builder: (context, state) => const TeamSecurityScreen(),
      ),
      GoRoute(
        path: AppRoutes.kitchenCreateBatch,
        builder: (context, state) => const CreateBatchScreen(),
      ),
      GoRoute(
        path: AppRoutes.kitchenBatchDetail,
        builder: (context, state) {
          final batchId = state.pathParameters['batchId'] ?? '';
          final extra = state.extra;
          return BatchQrDetailScreen(
            batchId: batchId,
            initialBatch: extra is FoodBatchItem ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.courierScan,
        builder: (context, state) {
          final extra = state.extra;
          return CourierScanScreen(
            initialMode: extra is CourierScanMode ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.schoolScanQr,
        builder: (context, state) => const ScanQrScreen(),
      ),
      GoRoute(
        path: AppRoutes.schoolDangerGate,
        builder: (context, state) {
          final extra = state.extra;
          return DangerZoneGateScreen(
            scanContext: extra is VerifiedBatchScanContext ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.schoolVisualAudit,
        builder: (context, state) {
          final extra = state.extra;
          return VisualAuditScreen(
            scanContext: extra is VerifiedBatchScanContext ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.schoolSampleSave,
        builder: (context, state) {
          final extra = state.extra;
          return SampleVaultScreen(
            onboardingArgs: extra is SampleVaultOnboardingArgs ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.schoolReportAlert,
        builder: (context, state) {
          final extra = state.extra;
          return AnomalyReportScreen(
            args: extra is AnomalyHandoffArgs ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.schoolPuskesmasDraft,
        builder: (context, state) {
          final extra = state.extra;
          return PuskesmasReportDraftScreen(
            args: extra is PuskesmasDraftArgs ? extra : null,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => LacakAdaptiveShell(
          navigationShell: navigationShell,
          destinations: LacakShellDestinations.kitchen,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.kitchenHome,
                builder: (context, state) => const KitchenDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.kitchenSchools,
                builder: (context, state) => const KitchenSchoolsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.kitchenIngredients,
                builder: (context, state) => const IngredientHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.kitchenTrays,
                builder: (context, state) => const TrayLogisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.kitchenHistory,
                builder: (context, state) => const KitchenHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.kitchenSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => LacakAdaptiveShell(
          navigationShell: navigationShell,
          destinations: LacakShellDestinations.school,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolHome,
                builder: (context, state) => const SchoolDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolSamples,
                builder: (context, state) => const SampleVaultScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolPlateWaste,
                builder: (context, state) => const PlateWasteScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schoolSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => LacakAdaptiveShell(
          navigationShell: navigationShell,
          destinations: LacakShellDestinations.courier,
        ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.courierHome,
                    builder: (context, state) => const CourierDashboardScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.courierSettings,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => LacakAdaptiveShell(
          navigationShell: navigationShell,
          destinations: LacakShellDestinations.supervisor,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supervisor,
                builder: (context, state) => const SupervisorHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supervisorSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

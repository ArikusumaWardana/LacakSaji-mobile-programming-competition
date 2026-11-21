import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../database/database_provider.dart';
import '../network/connectivity_provider.dart';
import '../sync/offline_sync_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_offline_bar.dart';
import 'lacak_sync_queue_sheet.dart';

class LacakNavDestination {
  const LacakNavDestination({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

abstract final class LacakShellDestinations {
  static const List<LacakNavDestination> kitchen = [
    LacakNavDestination(label: 'Beranda', icon: Icons.home_rounded),
    LacakNavDestination(label: 'Sekolah', icon: Icons.school_rounded),
    LacakNavDestination(label: 'Riwayat', icon: Icons.history_rounded),
    LacakNavDestination(label: 'Profil', icon: Icons.person_rounded),
  ];

  static const List<LacakNavDestination> school = [
    LacakNavDestination(label: 'Beranda', icon: Icons.home_rounded),
    LacakNavDestination(label: 'Sampel', icon: Icons.kitchen_rounded),
    LacakNavDestination(label: 'Sisa Makan', icon: Icons.restaurant_rounded),
    LacakNavDestination(label: 'Profil', icon: Icons.person_rounded),
  ];
}

/// Adaptive primary navigation shell switching between NavigationBar (<600dp) and NavigationRail (>=600dp).
class LacakAdaptiveShell extends ConsumerWidget {
  const LacakAdaptiveShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<LacakNavDestination> destinations;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = AppSpacing.isTablet(width);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingSyncCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);

    final bodyContent = Column(
      children: [
        LacakOfflineBar(
          isOffline: isOffline,
          pendingSyncCount: pendingSyncCount,
          isSyncing: syncState.isSyncing,
          statusErrorMessage: syncState.lastError,
          onSyncTap: () => runInteractiveSyncWithFeedback(context, ref),
          onInspectTap: () => showPendingSyncQueueSheet(context, ref),
        ),
        Expanded(child: navigationShell),
      ],
    );

    if (useRail) {
      return Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: AppColors.surfaceBase,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                minWidth: 92,
                indicatorColor: AppColors.primaryTint,
                selectedIconTheme: const IconThemeData(
                  color: AppColors.onPrimaryTint,
                  size: 24,
                ),
                unselectedIconTheme: const IconThemeData(
                  color: AppColors.textSecondary,
                  size: 24,
                ),
                selectedLabelTextStyle: AppTypography.labelTag.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelTextStyle: AppTypography.labelTag.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                destinations: destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.label,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.borderHairline,
              ),
              Expanded(child: bodyContent),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(top: true, bottom: false, child: bodyContent),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderHairline, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: destinations
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

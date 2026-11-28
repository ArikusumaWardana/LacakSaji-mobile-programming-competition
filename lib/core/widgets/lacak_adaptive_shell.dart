import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_shell.dart';

export 'app_shell.dart';

class LacakNavDestination {
  const LacakNavDestination({
    required this.label,
    required this.icon,
    this.group = AppShellNavGroup.operational,
  });

  final String label;
  final IconData icon;
  final AppShellNavGroup group;
}

abstract final class LacakShellDestinations {
  static const List<LacakNavDestination> kitchen = [
    LacakNavDestination(
      label: 'Beranda',
      icon: Icons.home_rounded,
      group: AppShellNavGroup.primary,
    ),
    LacakNavDestination(
      label: 'Sekolah',
      icon: Icons.school_rounded,
      group: AppShellNavGroup.operational,
    ),
    LacakNavDestination(
      label: 'Bahan Baku',
      icon: Icons.inventory_2_rounded,
      group: AppShellNavGroup.operational,
    ),
    LacakNavDestination(
      label: 'Logistik Wadah',
      icon: Icons.cleaning_services_rounded,
      group: AppShellNavGroup.operational,
    ),
    LacakNavDestination(
      label: 'Riwayat',
      icon: Icons.history_rounded,
      group: AppShellNavGroup.operational,
    ),
    LacakNavDestination(
      label: 'Profil',
      icon: Icons.person_rounded,
      group: AppShellNavGroup.account,
    ),
  ];

  static const List<LacakNavDestination> courier = [
    LacakNavDestination(
      label: 'Pengiriman',
      icon: Icons.local_shipping_rounded,
      group: AppShellNavGroup.primary,
    ),
    LacakNavDestination(
      label: 'Profil',
      icon: Icons.person_rounded,
      group: AppShellNavGroup.account,
    ),
  ];

  static const List<LacakNavDestination> school = [
    LacakNavDestination(
      label: 'Beranda',
      icon: Icons.home_rounded,
      group: AppShellNavGroup.primary,
    ),
    LacakNavDestination(
      label: 'Sampel',
      icon: Icons.kitchen_rounded,
      group: AppShellNavGroup.operational,
    ),
    LacakNavDestination(
      label: 'Sisa Makan',
      icon: Icons.restaurant_rounded,
      group: AppShellNavGroup.operational,
    ),
    LacakNavDestination(
      label: 'Profil',
      icon: Icons.person_rounded,
      group: AppShellNavGroup.account,
    ),
  ];

  static const List<LacakNavDestination> supervisor = [
    LacakNavDestination(
      label: 'Ringkasan Wilayah',
      icon: Icons.analytics_rounded,
      group: AppShellNavGroup.primary,
    ),
    LacakNavDestination(
      label: 'Profil',
      icon: Icons.person_rounded,
      group: AppShellNavGroup.account,
    ),
  ];
}

/// Compatibility wrapper delegating primary navigation to [AppShell] (Slide-Out Zoom Drawer & Tablet Sidebar).
class LacakAdaptiveShell extends ConsumerWidget {
  const LacakAdaptiveShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
    this.roleLabel,
    this.useEmbeddedHeader = false,
    this.embeddedHeaderBranches,
  });

  final StatefulNavigationShell navigationShell;
  final List<LacakNavDestination> destinations;
  final String? roleLabel;
  final bool useEmbeddedHeader;
  final Set<int>? embeddedHeaderBranches;

  String? _inferRoleLabel() {
    if (roleLabel != null) {
      return roleLabel;
    }
    if (identical(destinations, LacakShellDestinations.kitchen)) {
      return 'Dapur SPPG';
    }
    if (identical(destinations, LacakShellDestinations.courier)) {
      return 'Kurir Pengantar';
    }
    if (identical(destinations, LacakShellDestinations.school)) {
      return 'Sekolah Binaan';
    }
    if (identical(destinations, LacakShellDestinations.supervisor)) {
      return 'Pengawas BGN';
    }
    return null;
  }

  Set<int> _resolveEmbeddedHeaderBranches() {
    if (embeddedHeaderBranches != null) {
      return embeddedHeaderBranches!;
    }
    if (identical(destinations, LacakShellDestinations.kitchen)) {
      return const {0, 1, 2, 3, 4, 5};
    }
    if (identical(destinations, LacakShellDestinations.school)) {
      return const {0, 1, 2, 3};
    }
    if (identical(destinations, LacakShellDestinations.courier)) {
      return const {0, 1};
    }
    if (identical(destinations, LacakShellDestinations.supervisor)) {
      return const {0, 1};
    }
    return const <int>{};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      navigationShell: navigationShell,
      roleLabel: _inferRoleLabel(),
      showSignOutAction: true,
      useEmbeddedHeader: useEmbeddedHeader,
      embeddedHeaderBranches: _resolveEmbeddedHeaderBranches(),
      destinations: destinations
          .map(
            (item) => AppShellDestination(
              label: item.label,
              icon: item.icon,
              group: item.group,
            ),
          )
          .toList(growable: false),
    );
  }
}

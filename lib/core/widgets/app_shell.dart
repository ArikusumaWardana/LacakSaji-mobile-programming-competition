import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../database/database_provider.dart';
import '../network/connectivity_provider.dart';
import '../sync/offline_sync_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lacak_confirm_dialog.dart';
import 'lacak_logo.dart';
import 'lacak_offline_bar.dart';
import 'lacak_sync_queue_sheet.dart';

/// Navigation drawer item grouping shown with subtle dividers.
enum AppShellNavGroup {
  primary,
  operational,
  account,
}

/// Destination entry rendered inside [AppShell].
class AppShellDestination {
  const AppShellDestination({
    required this.label,
    required this.icon,
    IconData? selectedIcon,
    this.group = AppShellNavGroup.operational,
    this.badgeCount = 0,
  }) : selectedIcon = selectedIcon ?? icon;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final AppShellNavGroup group;
  final int badgeCount;
}

/// Descendant scope exposing drawer state and controls to headers such as [MinimalTopHeader].
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.isDrawerOpen,
    required this.isPermanentSidebar,
    required this.openDrawer,
    required this.closeDrawer,
    required this.toggleDrawer,
    required super.child,
  });

  final bool isDrawerOpen;
  final bool isPermanentSidebar;
  final VoidCallback openDrawer;
  final VoidCallback closeDrawer;
  final VoidCallback toggleDrawer;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  static AppShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppShellScope was not found in the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return isDrawerOpen != oldWidget.isDrawerOpen ||
        isPermanentSidebar != oldWidget.isPermanentSidebar;
  }
}

/// Responsive editorial navigation shell:
/// - Mobile (< 600dp): full-screen #234B3E slide-out zoom drawer (content shifts right & scales to 0.86 with 24dp radius).
/// - Tablet / Landscape (>= 600dp): permanent 260dp #234B3E left sidebar beside main content.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
    this.roleLabel,
    this.showSignOutAction = false,
    this.onSignOut,
    this.useEmbeddedHeader = false,
    this.embeddedHeaderBranches = const <int>{},
  });

  final StatefulNavigationShell navigationShell;
  final List<AppShellDestination> destinations;
  final String? roleLabel;
  final bool showSignOutAction;
  final Future<void> Function(BuildContext context)? onSignOut;

  /// Set to true once all branches render their own [MinimalTopHeader] drawer trigger.
  final bool useEmbeddedHeader;

  /// Branch indices that already embed their own [MinimalTopHeader] on mobile.
  final Set<int> embeddedHeaderBranches;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;
  bool _isSigningOut = false;

  bool get _isDrawerOpen => _controller.value > 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void openDrawer() {
    if (_reduceMotion(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
    setState(() {});
  }

  void closeDrawer() {
    if (_reduceMotion(context)) {
      _controller.value = 0.0;
    } else {
      _controller.reverse();
    }
    setState(() {});
  }

  void toggleDrawer() {
    if (_controller.value >= 0.5) {
      closeDrawer();
    } else {
      openDrawer();
    }
  }

  void _selectBranch(int index, {required bool closeAfter}) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (closeAfter) {
      closeDrawer();
    }
  }

  Future<void> _handleSignOut({required bool closeFirst}) async {
    if (_isSigningOut) {
      return;
    }
    if (closeFirst) {
      closeDrawer();
    }
    if (widget.onSignOut != null) {
      await widget.onSignOut!(context);
      return;
    }
    final confirmed = await showLacakConfirmDialog(
      context: context,
      title: 'Keluar dari Akun?',
      message:
          'Data pemeriksaan lokal yang belum tersinkronisasi tetap aman di HP ini sampai Anda masuk kembali.',
      confirmLabel: 'Ya, Keluar Akun',
      isDanger: true,
      confirmIcon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPermanentSidebar = AppSpacing.isTablet(screenWidth);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final pendingSyncCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final syncState = ref.watch(offlineSyncControllerProvider);

    final offlineBar = LacakOfflineBar(
      isOffline: isOffline,
      pendingSyncCount: pendingSyncCount,
      isSyncing: syncState.isSyncing,
      statusErrorMessage: syncState.lastError,
      onSyncTap: () => runInteractiveSyncWithFeedback(context, ref),
      onInspectTap: () => showPendingSyncQueueSheet(context, ref),
    );

    if (isPermanentSidebar) {
      final tabletContent = Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: Row(
          children: [
            SizedBox(
              width: AppSpacing.drawerWidthTablet,
              child: _DrawerMenuPanel(
                destinations: widget.destinations,
                selectedIndex: widget.navigationShell.currentIndex,
                roleLabel: widget.roleLabel,
                showSignOutAction: widget.showSignOutAction,
                isSigningOut: _isSigningOut,
                onSelectDestination: (index) =>
                    _selectBranch(index, closeAfter: false),
                onSignOutTap: () => _handleSignOut(closeFirst: false),
              ),
            ),
            Expanded(
              child: SafeArea(
                left: false,
                child: Column(
                  children: [
                    offlineBar,
                    Expanded(child: widget.navigationShell),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      return AppShellScope(
        isDrawerOpen: true,
        isPermanentSidebar: true,
        openDrawer: openDrawer,
        closeDrawer: closeDrawer,
        toggleDrawer: toggleDrawer,
        child: tabletContent,
      );
    }

    final drawerWidth = (screenWidth * 0.68).clamp(224.0, 292.0);
    final currentIndex = widget.navigationShell.currentIndex;
    final hasEmbeddedHeader = widget.useEmbeddedHeader ||
        widget.embeddedHeaderBranches.contains(currentIndex);
    final showOfflineBar =
        isOffline || syncState.isSyncing || pendingSyncCount > 0;
    final currentLabel =
        (currentIndex >= 0 && currentIndex < widget.destinations.length)
            ? widget.destinations[currentIndex].label
            : '';

    final mobileMainBody = ColoredBox(
      color: AppColors.bgCanvas,
      child: Column(
        children: [
          if (!hasEmbeddedHeader)
            _MobileStageOneTriggerBar(
              currentLabel: currentLabel,
              onMenuTap: toggleDrawer,
            ),
          if (hasEmbeddedHeader && showOfflineBar)
            SafeArea(bottom: false, child: offlineBar)
          else if (!hasEmbeddedHeader)
            offlineBar,
          Expanded(
            child: (hasEmbeddedHeader && !showOfflineBar)
                ? widget.navigationShell
                : MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.navigationShell,
                  ),
          ),
        ],
      ),
    );

    return AppShellScope(
      isDrawerOpen: _isDrawerOpen,
      isPermanentSidebar: false,
      openDrawer: openDrawer,
      closeDrawer: closeDrawer,
      toggleDrawer: toggleDrawer,
      child: PopScope(
        canPop: !_isDrawerOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isDrawerOpen) {
            closeDrawer();
          }
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_isDrawerOpen) {
                closeDrawer();
              }
            },
          },
          child: Scaffold(
            backgroundColor: AppColors.drawerSurface,
            body: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _curvedAnimation,
                    builder: (context, child) {
                      final active = _curvedAnimation.value > 0.02;
                      return IgnorePointer(
                        ignoring: !active,
                        child: Semantics(
                          hidden: !active,
                          child: child,
                        ),
                      );
                    },
                    child: ColoredBox(
                      color: AppColors.drawerSurface,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: drawerWidth,
                          child: _DrawerMenuPanel(
                            destinations: widget.destinations,
                            selectedIndex: currentIndex,
                            roleLabel: widget.roleLabel,
                            showSignOutAction: widget.showSignOutAction,
                            isSigningOut: _isSigningOut,
                            onSelectDestination: (index) =>
                                _selectBranch(index, closeAfter: true),
                            onSignOutTap: () => _handleSignOut(closeFirst: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _curvedAnimation,
                  builder: (context, child) {
                    final t = _curvedAnimation.value;
                    final scale = lerpDouble(
                      1.0,
                      AppSpacing.drawerOpenScale,
                      t,
                    )!;
                    final slideX = drawerWidth * t;
                    final cornerRadius = AppSpacing.radiusDrawerSurface * t;
                    final isOpenVisual = t > 0.02;

                    return Transform.translate(
                      offset: Offset(slideX, 0),
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cornerRadius),
                            boxShadow: isOpenVisual
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF0E211A)
                                          .withValues(alpha: 0.24 * t),
                                      blurRadius: 28 * t,
                                      offset: Offset(-8 * t, 12 * t),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(cornerRadius),
                            child: Stack(
                              children: [
                                IgnorePointer(
                                  ignoring: isOpenVisual,
                                  child: child!,
                                ),
                                if (isOpenVisual)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: closeDrawer,
                                      onHorizontalDragUpdate: (details) {
                                        final delta =
                                            details.primaryDelta ?? 0;
                                        _controller.value = (_controller.value +
                                                delta / drawerWidth)
                                            .clamp(0.0, 1.0);
                                      },
                                      onHorizontalDragEnd: (details) {
                                        final vx =
                                            details.primaryVelocity ?? 0;
                                        if (vx < -250 ||
                                            _controller.value < 0.5) {
                                          closeDrawer();
                                        } else {
                                          openDrawer();
                                        }
                                      },
                                    ),
                                  )
                                else
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: 22,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragUpdate: (details) {
                                        final delta =
                                            details.primaryDelta ?? 0;
                                        _controller.value = (_controller.value +
                                                delta / drawerWidth)
                                            .clamp(0.0, 1.0);
                                      },
                                      onHorizontalDragEnd: (details) {
                                        final vx =
                                            details.primaryVelocity ?? 0;
                                        if (vx > 250 ||
                                            _controller.value > 0.35) {
                                          openDrawer();
                                        } else {
                                          closeDrawer();
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: mobileMainBody,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileStageOneTriggerBar extends StatelessWidget {
  const _MobileStageOneTriggerBar({
    required this.currentLabel,
    required this.onMenuTap,
  });

  final String currentLabel;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCanvas,
      child: SafeArea(
        bottom: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderHairline, width: 1),
            ),
          ),
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey<String>('app_shell_menu_button'),
                onPressed: onMenuTap,
                tooltip: 'Buka menu navigasi',
                icon: const Icon(
                  Icons.menu_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  currentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelTag.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'LacakSaji',
                style: AppTypography.labelTag.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerMenuPanel extends StatelessWidget {
  const _DrawerMenuPanel({
    required this.destinations,
    required this.selectedIndex,
    required this.roleLabel,
    required this.showSignOutAction,
    required this.isSigningOut,
    required this.onSelectDestination,
    required this.onSignOutTap,
  });

  final List<AppShellDestination> destinations;
  final int selectedIndex;
  final String? roleLabel;
  final bool showSignOutAction;
  final bool isSigningOut;
  final ValueChanged<int> onSelectDestination;
  final VoidCallback onSignOutTap;

  @override
  Widget build(BuildContext context) {
    final groupedIndices = <AppShellNavGroup, List<int>>{
      for (final group in AppShellNavGroup.values) group: <int>[],
    };
    for (var i = 0; i < destinations.length; i++) {
      groupedIndices[destinations[i].group]!.add(i);
    }

    final primaryIndices = groupedIndices[AppShellNavGroup.primary]!;
    final operationalIndices = groupedIndices[AppShellNavGroup.operational]!;
    final accountIndices = groupedIndices[AppShellNavGroup.account]!;

    final hasOperational = operationalIndices.isNotEmpty;
    final hasAccount = accountIndices.isNotEmpty || showSignOutAction;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.xl * 2)
                    .clamp(0.0, double.infinity),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    child: Row(
                      children: [
                        const LacakLogoMark(size: 36, inverted: true),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'LacakSaji',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleSection.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (roleLabel != null &&
                                  roleLabel!.trim().isNotEmpty)
                                Text(
                                  roleLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.captionLegal.copyWith(
                                    color: AppColors.drawerInactiveFg,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final index in primaryIndices)
                    _DrawerNavItemTile(
                      label: destinations[index].label,
                      icon: index == selectedIndex
                          ? destinations[index].selectedIcon
                          : destinations[index].icon,
                      selected: index == selectedIndex,
                      badgeCount: destinations[index].badgeCount,
                      onTap: () => onSelectDestination(index),
                    ),
                  if (primaryIndices.isNotEmpty && hasOperational)
                    const _DrawerGroupDivider(),
                  for (final index in operationalIndices)
                    _DrawerNavItemTile(
                      label: destinations[index].label,
                      icon: index == selectedIndex
                          ? destinations[index].selectedIcon
                          : destinations[index].icon,
                      selected: index == selectedIndex,
                      badgeCount: destinations[index].badgeCount,
                      onTap: () => onSelectDestination(index),
                    ),
                  if ((primaryIndices.isNotEmpty || hasOperational) &&
                      hasAccount)
                    const _DrawerGroupDivider(),
                  for (final index in accountIndices)
                    _DrawerNavItemTile(
                      label: destinations[index].label,
                      icon: index == selectedIndex
                          ? destinations[index].selectedIcon
                          : destinations[index].icon,
                      selected: index == selectedIndex,
                      badgeCount: destinations[index].badgeCount,
                      onTap: () => onSelectDestination(index),
                    ),
                  if (showSignOutAction)
                    _DrawerNavItemTile(
                      label: isSigningOut ? 'Keluar...' : 'Keluar Akun',
                      icon: Icons.logout_rounded,
                      selected: false,
                      onTap: isSigningOut ? null : onSignOutTap,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DrawerGroupDivider extends StatelessWidget {
  const _DrawerGroupDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      color: AppColors.drawerDivider,
    );
  }
}

class _DrawerNavItemTile extends StatelessWidget {
  const _DrawerNavItemTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.surfaceBase : Colors.transparent;
    final fgColor = selected ? AppColors.primary : AppColors.drawerInactiveFg;
    final splashColor = selected
        ? AppColors.primaryTint
        : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg, top: 2, bottom: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: bgColor,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(AppSpacing.radiusDrawerPill),
          ),
          child: InkWell(
            onTap: onTap,
            splashColor: splashColor,
            highlightColor: splashColor,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(AppSpacing.radiusDrawerPill),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: fgColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleItem.copyWith(
                          color: fgColor,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryTint
                              : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: AppTypography.tabular(
                            AppTypography.captionLegal.copyWith(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

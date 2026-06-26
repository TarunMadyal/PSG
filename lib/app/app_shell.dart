import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../shared/widgets/app_logo.dart';
import '../shared/widgets/sync_status_chip.dart';
import 'nav_destination.dart';

/// Responsive application shell.
///
/// On wide layouts (tablet, the primary device) it shows a persistent
/// [NavigationRail]; on narrow layouts (phone) it switches to a bottom
/// [NavigationBar]. The active feature is rendered via the [navigationShell]
/// so each tab keeps its own state.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Tablet/desktop breakpoint — POS runs landscape on a tablet by default.
  static const double _wideBreakpoint = 720;

  void _goBranch(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return isWide ? _buildWide(context) : _buildNarrow(context);
  }

  Widget _buildWide(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = navigationShell.currentIndex;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1080,
            minExtendedWidth: 220,
            selectedIndex: selected,
            onDestinationSelected: _goBranch,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppLogo(size: 44),
            ),
            destinations: [
              for (final d in kPosDestinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: kPosDestinations[selected].label),
                Divider(height: 1, color: scheme.outlineVariant),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final selected = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Row(
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: AppSpacing.md),
            Text(kPosDestinations[selected].label),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.lg),
            child: Center(child: SyncStatusChip()),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: _goBranch,
        destinations: [
          for (final d in kPosDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          const SyncStatusChip(),
        ],
      ),
    );
  }
}

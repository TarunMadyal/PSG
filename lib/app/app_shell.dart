import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../features/auth/application/auth_controller.dart';
import '../shared/widgets/app_logo.dart';
import '../shared/widgets/sync_status_chip.dart';
import 'nav_destination.dart';

/// Responsive application shell.
///
/// On wide layouts (tablet, the primary device) it shows a persistent
/// [NavigationRail]; on narrow layouts (phone) it switches to a bottom
/// [NavigationBar]. Destinations are filtered by the signed-in user's
/// capabilities, and selection is mapped back to the full branch index so the
/// underlying [navigationShell] branches stay stable.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _wideBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitiesProvider);

    // (branchIndex, destination) pairs the current user may see.
    final visible = <(int, PosDestination)>[
      for (var i = 0; i < kPosDestinations.length; i++)
        if (capabilities.contains(kPosDestinations[i].requiredCapability))
          (i, kPosDestinations[i]),
    ];

    // Selected position within the visible list (fallback to first).
    var selectedPos =
        visible.indexWhere((e) => e.$1 == navigationShell.currentIndex);
    if (selectedPos < 0) selectedPos = 0;

    void goPos(int pos) {
      final branchIndex = visible[pos].$1;
      navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell.currentIndex,
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return isWide
        ? _buildWide(context, ref, visible, selectedPos, goPos)
        : _buildNarrow(context, ref, visible, selectedPos, goPos);
  }

  Widget _buildWide(
    BuildContext context,
    WidgetRef ref,
    List<(int, PosDestination)> visible,
    int selectedPos,
    void Function(int) goPos,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1080,
            minExtendedWidth: 220,
            selectedIndex: selectedPos,
            onDestinationSelected: goPos,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppLogo(size: 44),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _UserMenu(ref: ref),
                ),
              ),
            ),
            destinations: [
              for (final (_, d) in visible)
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
                _TopBar(title: visible[selectedPos].$2.label),
                Divider(height: 1, color: scheme.outlineVariant),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrow(
    BuildContext context,
    WidgetRef ref,
    List<(int, PosDestination)> visible,
    int selectedPos,
    void Function(int) goPos,
  ) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Row(
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: AppSpacing.md),
            Text(visible[selectedPos].$2.label),
          ],
        ),
        actions: [
          const Center(child: SyncStatusChip()),
          const SizedBox(width: AppSpacing.sm),
          _UserMenu(ref: ref),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedPos,
        onDestinationSelected: goPos,
        destinations: [
          for (final (_, d) in visible)
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

/// Avatar + popup with the current user's name/role and a logout action.
class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: user.name,
      onSelected: (value) {
        if (value == 'logout') {
          ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: scheme.primary,
              child: Text(
                user.initials,
                style: TextStyle(color: scheme.onPrimary, fontSize: 13),
              ),
            ),
            title: Text(user.name),
            subtitle: Text(user.isOwner ? 'Owner' : 'Cashier'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Log out'),
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.primary,
        child: Text(
          user.initials,
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/billing/presentation/billing_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';

/// Central app router. Uses an indexed stateful shell so each top-level tab
/// keeps its own navigation state — important for a POS where the cashier
/// jumps between billing and lookups without losing context.
///
/// Auth-gated redirects are added in Phase 3.
final GoRouter appRouter = GoRouter(
  initialLocation: '/billing',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        _branch('/billing', const BillingScreen()),
        _branch('/products', const ProductsScreen()),
        _branch('/inventory', const InventoryScreen()),
        _branch('/customers', const CustomersScreen()),
        _branch('/reports', const ReportsScreen()),
        _branch('/settings', const SettingsScreen()),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, Widget child) => StatefulShellBranch(
      routes: [
        GoRoute(path: path, builder: (context, state) => child),
      ],
    );

import 'package:flutter/material.dart';

import '../features/auth/domain/capability.dart';

/// A top-level navigation destination in the POS shell.
class PosDestination {
  const PosDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.requiredCapability,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Capability a user must hold for this destination to be visible/reachable.
  final Capability requiredCapability;
}

/// The primary navigation, ordered by daily frequency of use — Billing first.
/// Visibility is filtered per-user by [requiredCapability] (see `AppShell`).
const List<PosDestination> kPosDestinations = [
  PosDestination(
    path: '/billing',
    label: 'Billing',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
    requiredCapability: Capability.createBill,
  ),
  PosDestination(
    path: '/categories',
    label: 'Categories',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    requiredCapability: Capability.searchProducts,
  ),
  PosDestination(
    path: '/products',
    label: 'Products',
    icon: Icons.checkroom_outlined,
    selectedIcon: Icons.checkroom,
    requiredCapability: Capability.manageProducts,
  ),
  PosDestination(
    path: '/customers',
    label: 'Customers',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt,
    requiredCapability: Capability.createBill,
  ),
  PosDestination(
    path: '/reports',
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    requiredCapability: Capability.viewReports,
  ),
  PosDestination(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    requiredCapability: Capability.manageSettings,
  ),
];

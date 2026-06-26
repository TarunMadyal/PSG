import 'package:flutter/material.dart';

/// A top-level navigation destination in the POS shell.
class PosDestination {
  const PosDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The primary navigation, ordered by daily frequency of use — Billing first.
const List<PosDestination> kPosDestinations = [
  PosDestination(
    path: '/billing',
    label: 'Billing',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  ),
  PosDestination(
    path: '/products',
    label: 'Products',
    icon: Icons.checkroom_outlined,
    selectedIcon: Icons.checkroom,
  ),
  PosDestination(
    path: '/inventory',
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  PosDestination(
    path: '/customers',
    label: 'Customers',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt,
  ),
  PosDestination(
    path: '/reports',
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
  PosDestination(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

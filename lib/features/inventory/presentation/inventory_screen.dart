import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Inventory & stock management. Implemented in Phase 4/5.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  static const String title = 'Inventory';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.inventory_2_outlined,
      title: 'Inventory',
      description:
          'Track stock levels with an append-only ledger, see low-stock alerts '
          'and make adjustments — stock updates automatically on every sale.',
      phaseLabel: 'Arriving in Phase 4–5 · Inventory',
    );
  }
}

import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Billing home — the shop's most-used screen. Implemented in Phase 5.
class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  static const String title = 'Billing';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.point_of_sale_outlined,
      title: 'Fast Billing',
      description:
          'Search products, build a cart, apply discounts and generate a bill '
          'in seconds — fully offline.',
      phaseLabel: 'Arriving in Phase 5 · Billing',
    );
  }
}

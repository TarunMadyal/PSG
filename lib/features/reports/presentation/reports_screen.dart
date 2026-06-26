import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Sales & inventory reports. Implemented in Phase 7.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const String title = 'Reports';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.bar_chart_outlined,
      title: 'Reports',
      description:
          'Daily, weekly, monthly and yearly sales, best sellers, low stock '
          'and inventory value — all computed from your data.',
      phaseLabel: 'Arriving in Phase 7 · Reports',
    );
  }
}

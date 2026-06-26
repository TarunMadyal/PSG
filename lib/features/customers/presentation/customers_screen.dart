import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Optional customer directory & purchase history. Implemented in Phase 5+.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  static const String title = 'Customers';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.people_alt_outlined,
      title: 'Customers',
      description:
          'Optional — capture a phone number to keep purchase history, or bill '
          'anonymously. Powers loyalty and reports later.',
      phaseLabel: 'Arriving in Phase 5+ · Customers',
    );
  }
}

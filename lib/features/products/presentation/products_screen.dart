import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Product catalog management. Implemented in Phase 4.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  static const String title = 'Products';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.checkroom_outlined,
      title: 'Product Catalog',
      description:
          'Manage thousands of products — name, brand, size, colour, SKU, '
          'barcode, price, stock and images.',
      phaseLabel: 'Arriving in Phase 4 · Products',
    );
  }
}

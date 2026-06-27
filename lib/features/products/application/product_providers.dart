import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/product_repository_impl.dart';
import '../domain/product_item.dart';
import '../domain/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductRepositoryImpl(productsDao: db.productsDao);
});

/// Live catalog.
final catalogProvider = StreamProvider<List<ProductItem>>(
  (ref) => ref.watch(productRepositoryProvider).watchCatalog(),
);

/// Current search text in the products screen.
final productSearchQueryProvider = StateProvider<String>((ref) => '');

/// Catalog filtered by the search query (name / brand / category / size /
/// colour).
final filteredCatalogProvider = Provider<List<ProductItem>>((ref) {
  final items = ref.watch(catalogProvider).valueOrNull ?? const [];
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return items;

  return items.where((p) {
    return p.name.toLowerCase().contains(query) ||
        (p.brand?.toLowerCase().contains(query) ?? false) ||
        (p.category?.toLowerCase().contains(query) ?? false) ||
        (p.size?.toLowerCase().contains(query) ?? false) ||
        (p.color?.toLowerCase().contains(query) ?? false);
  }).toList();
});

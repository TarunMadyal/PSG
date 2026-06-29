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

/// Selected category filter on the billing screen (null = all categories).
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// All distinct, non-empty categories present in the catalog, sorted.
final catalogCategoriesProvider = Provider<List<String>>((ref) {
  final items = ref.watch(catalogProvider).valueOrNull ?? const [];
  final set = <String>{};
  for (final p in items) {
    final c = p.category?.trim();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  final list = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
});

/// Catalog filtered by the search query (name / brand / category / size /
/// colour) and the selected category chip.
final filteredCatalogProvider = Provider<List<ProductItem>>((ref) {
  final items = ref.watch(catalogProvider).valueOrNull ?? const [];
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryProvider);

  return items.where((p) {
    if (category != null &&
        (p.category?.trim().toLowerCase() ?? '') != category.toLowerCase()) {
      return false;
    }
    if (query.isEmpty) return true;
    return p.name.toLowerCase().contains(query) ||
        (p.brand?.toLowerCase().contains(query) ?? false) ||
        (p.category?.toLowerCase().contains(query) ?? false) ||
        (p.size?.toLowerCase().contains(query) ?? false) ||
        (p.color?.toLowerCase().contains(query) ?? false);
  }).toList();
});

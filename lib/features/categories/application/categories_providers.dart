import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/application/product_providers.dart';
import '../../products/domain/product_item.dart';

/// A category together with how many products it contains.
class CategoryCount {
  const CategoryCount(this.name, this.count);

  final String name;
  final int count;
}

/// Bucket label for products that have no category set.
const String kUncategorised = 'Uncategorised';

/// Categories present in the catalog with product counts, sorted by name.
final categoryCountsProvider = Provider<List<CategoryCount>>((ref) {
  final items = ref.watch(catalogProvider).valueOrNull ?? const <ProductItem>[];
  final map = <String, int>{};
  for (final p in items) {
    final c = p.category?.trim();
    final key = (c == null || c.isEmpty) ? kUncategorised : c;
    map[key] = (map[key] ?? 0) + 1;
  }
  final list = map.entries.map((e) => CategoryCount(e.key, e.value)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

/// Products belonging to [category] (pass [kUncategorised] for the no-category
/// bucket).
final productsInCategoryProvider =
    Provider.family<List<ProductItem>, String>((ref, category) {
  final items = ref.watch(catalogProvider).valueOrNull ?? const <ProductItem>[];
  final wanted = category.toLowerCase();
  return items.where((p) {
    final c = p.category?.trim();
    final key = (c == null || c.isEmpty) ? kUncategorised : c;
    return key.toLowerCase() == wanted;
  }).toList();
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/category_colors.dart';
import '../../products/domain/product_item.dart';
import '../application/categories_providers.dart';

/// Browse the catalog by category. Each category is a coloured tile; tapping it
/// lists every product in that category. Colours are consistent everywhere so
/// staff can recognise categories at a glance.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const String title = 'Categories';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryCountsProvider);
    final scheme = Theme.of(context).colorScheme;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No categories yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add a category to your products to group them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 110,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) => _CategoryTile(category: categories[i]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryCount category;

  @override
  Widget build(BuildContext context) {
    final bg = CategoryColors.background(category.name);
    final accent = CategoryColors.accent(category.name);

    return Card(
      color: bg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _CategoryProductsScreen(category: category.name),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.checkroom, size: 18, color: Colors.black54),
                ],
              ),
              const Spacer(),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${category.count} item${category.count == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The products inside one category, shown as a coloured list.
class _CategoryProductsScreen extends ConsumerWidget {
  const _CategoryProductsScreen({required this.category});

  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsInCategoryProvider(category));
    final accent = CategoryColors.accent(category);

    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: CategoryColors.background(category),
        foregroundColor: Colors.black87,
      ),
      body: products.isEmpty
          ? const Center(child: Text('No products in this category.'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final ProductItem p = products[i];
                return ListTile(
                  leading: Container(
                    width: 12,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: p.attributesLabel.isEmpty
                      ? null
                      : Text(p.attributesLabel),
                  trailing: Text(
                    p.price.formatted,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
    );
  }
}

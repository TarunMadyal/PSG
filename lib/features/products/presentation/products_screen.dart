import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/category_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/capability.dart';
import '../application/product_providers.dart';
import '../domain/product_item.dart';
import 'widgets/product_form_sheet.dart';

/// Product catalog management (owner). Implemented in Phase 4.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  static const String title = 'Products';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final canManage = ref.watch(canProvider(Capability.manageProducts));

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => showProductFormSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            )
          : null,
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
        data: (_) => _CatalogBody(canManage: canManage),
      ),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  const _CatalogBody({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredCatalogProvider);
    final total = ref.watch(catalogProvider).valueOrNull?.length ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: TextField(
            onChanged: (v) =>
                ref.read(productSearchQueryProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Search by name, brand, size or colour',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (items.isEmpty)
          Expanded(child: _EmptyState(hasProducts: total > 0))
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 124,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _ProductCard(
                item: items[i],
                canManage: canManage,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.item, required this.canManage});

  final ProductItem item;
  final bool canManage;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${item.name}" will be removed from the catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(productRepositoryProvider).delete(item.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = CategoryColors.accent(item.category);

    return Card(
      color: CategoryColors.background(item.category),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canManage
            ? () => showProductFormSheet(context, existing: item)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (canManage)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'edit') {
                          showProductFormSheet(context, existing: item);
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              if (item.attributesLabel.isNotEmpty)
                Text(
                  item.attributesLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              const Spacer(),
              Text(
                item.price.formatted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasProducts});

  final bool hasProducts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasProducts ? Icons.search_off : Icons.checkroom_outlined,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasProducts ? 'No matching products' : 'No products yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasProducts
                ? 'Try a different search.'
                : 'Tap "Add product" to build your catalog.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/category_colors.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product_item.dart';
import '../application/cart_controller.dart';
import 'widgets/cart_panel.dart';

/// Billing home — the shop's most-used screen. Catalog on the left, the live
/// cart on the right (tablet); on a phone the cart opens as a sheet.
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  static const String title = 'Billing';
  static const double _wideBreakpoint = 760;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Row(
        children: [
          const Expanded(child: _CatalogPane()),
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(width: 400, child: CartPanel()),
        ],
      );
    }

    return const Scaffold(
      body: _CatalogPane(),
      bottomNavigationBar: _CartBar(),
    );
  }
}

class _CatalogPane extends ConsumerWidget {
  const _CatalogPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: TextField(
            onChanged: (v) =>
                ref.read(productSearchQueryProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Search products to add',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const _CategoryFilterBar(),
        Expanded(
          child: catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load products: $e')),
            data: (_) => const _ProductGrid(),
          ),
        ),
      ],
    );
  }
}

/// Horizontal, colour-coded category chips. Tapping "Shirts" shows only shirts —
/// a fast, visual way for staff to find what to bill.
class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(catalogCategoriesProvider);
    final selected = ref.watch(selectedCategoryProvider);
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _Chip(
            label: 'All',
            color: Theme.of(context).colorScheme.primary,
            selected: selected == null,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = null,
          ),
          for (final c in categories)
            _Chip(
              label: c,
              color: CategoryColors.accent(c),
              selected: selected == c,
              onTap: () =>
                  ref.read(selectedCategoryProvider.notifier).state = c,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredCatalogProvider);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No products found',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 116,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ProductTile(item: items[i]),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.item});

  final ProductItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = CategoryColors.accent(item.category);

    return Card(
      color: CategoryColors.background(item.category),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(cartProvider.notifier).addProduct(item),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
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
                style: TextStyle(
                  fontWeight: FontWeight.w800,
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

/// Phone-only: bottom bar summarising the cart; opens the full cart as a sheet.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary,
      child: InkWell(
        onTap: cart.isEmpty
            ? null
            : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.9,
                    child: const CartPanel(),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: scheme.onPrimary),
              const SizedBox(width: AppSpacing.md),
              Text(
                cart.isEmpty ? 'Cart empty' : '${cart.itemCount} item(s)',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                cart.grandTotal.formatted,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

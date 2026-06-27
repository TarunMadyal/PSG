import '../../../core/utils/money.dart';

/// A catalog product: a name (+ optional descriptors) and a single selling
/// price. Decoupled from Drift types for the UI and use-cases.
class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    this.category,
    this.brand,
    this.size,
    this.color,
    this.isActive = true,
  });

  final String id;
  final String name;
  final Money price;
  final String? category;
  final String? brand;
  final String? size;
  final String? color;
  final bool isActive;

  /// "Brand · Size · Colour" — the populated attributes, for compact subtitles.
  String get attributesLabel => [brand, size, color]
      .where((e) => e != null && e.isNotEmpty)
      .join(' · ');
}

/// Form input for creating or editing a product (no identity/audit fields).
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.price,
    this.category,
    this.brand,
    this.size,
    this.color,
  });

  final String name;
  final Money price;
  final String? category;
  final String? brand;
  final String? size;
  final String? color;

  /// Pre-fills a draft from an existing item, for the edit form.
  factory ProductDraft.fromItem(ProductItem item) => ProductDraft(
        name: item.name,
        price: item.price,
        category: item.category,
        brand: item.brand,
        size: item.size,
        color: item.color,
      );
}

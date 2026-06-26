import '../../../core/utils/money.dart';

/// A catalog product with its current stock, decoupled from Drift types for the
/// UI and use-cases.
class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.reorderLevel = 0,
    this.category,
    this.brand,
    this.size,
    this.color,
    this.sku,
    this.barcode,
    this.cost,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final Money price;
  final int stock;
  final int reorderLevel;
  final String? category;
  final String? brand;
  final String? size;
  final String? color;
  final String? sku;
  final String? barcode;
  final Money? cost;
  final String? imageUrl;
  final bool isActive;

  bool get isLowStock => stock <= reorderLevel;

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
    required this.stock,
    this.reorderLevel = 0,
    this.category,
    this.brand,
    this.size,
    this.color,
    this.sku,
    this.barcode,
    this.cost,
    this.imageUrl,
  });

  final String name;
  final Money price;
  final int stock;
  final int reorderLevel;
  final String? category;
  final String? brand;
  final String? size;
  final String? color;
  final String? sku;
  final String? barcode;
  final Money? cost;
  final String? imageUrl;

  /// Pre-fills a draft from an existing item, for the edit form.
  factory ProductDraft.fromItem(ProductItem item) => ProductDraft(
        name: item.name,
        price: item.price,
        stock: item.stock,
        reorderLevel: item.reorderLevel,
        category: item.category,
        brand: item.brand,
        size: item.size,
        color: item.color,
        sku: item.sku,
        barcode: item.barcode,
        cost: item.cost,
        imageUrl: item.imageUrl,
      );
}

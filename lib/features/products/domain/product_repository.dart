import '../../../core/error/result.dart';
import 'product_item.dart';

/// Contract for catalog management (products + their stock).
abstract interface class ProductRepository {
  /// Live catalog stream for the UI.
  Stream<List<ProductItem>> watchCatalog();

  /// One-off search across name/SKU/barcode.
  Future<List<ProductItem>> search(String query);

  /// Creates ([id] null) or updates a product, keeping stock in step via the
  /// inventory ledger — all in one transaction.
  Future<Result<void>> save(ProductDraft draft, {String? id});

  /// Soft-deletes a product (recoverable; queued for sync).
  Future<Result<void>> delete(String id);
}

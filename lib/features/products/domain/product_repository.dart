import '../../../core/error/result.dart';
import 'product_item.dart';

/// Contract for catalog management.
abstract interface class ProductRepository {
  /// Live catalog stream for the UI.
  Stream<List<ProductItem>> watchCatalog();

  /// One-off search across name and descriptors.
  Future<List<ProductItem>> search(String query);

  /// Creates ([id] null) or updates a product in one transaction.
  Future<Result<void>> save(ProductDraft draft, {String? id});

  /// Soft-deletes a product (recoverable; queued for sync).
  Future<Result<void>> delete(String id);
}

import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/daos/inventory_dao.dart';
import '../../../data/local/daos/products_dao.dart';
import '../domain/product_item.dart';
import '../domain/product_repository.dart';

/// Local implementation: orchestrates the products and inventory DAOs so a
/// single save persists the product and reconciles stock atomically.
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({
    required AppDatabase db,
    required ProductsDao productsDao,
    required InventoryDao inventoryDao,
  })  : _db = db,
        _productsDao = productsDao,
        _inventoryDao = inventoryDao;

  final AppDatabase _db;
  final ProductsDao _productsDao;
  final InventoryDao _inventoryDao;

  @override
  Stream<List<ProductItem>> watchCatalog() {
    return _productsDao.watchCatalog().map(
          (rows) => rows.map(_toItem).toList(),
        );
  }

  @override
  Future<List<ProductItem>> search(String query) async {
    final products = await _productsDao.search(query);
    return Future.wait(
      products.map((p) async {
        final stock = await _inventoryDao.qtyFor(p.id);
        return _toItemFromProduct(p, stock, 0);
      }),
    );
  }

  @override
  Future<Result<void>> save(ProductDraft draft, {String? id}) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      return const Result.failure(ValidationFailure('Product name is required.'));
    }
    if (draft.price.isNegative) {
      return const Result.failure(ValidationFailure('Price cannot be negative.'));
    }
    if (draft.stock < 0) {
      return const Result.failure(ValidationFailure('Stock cannot be negative.'));
    }

    try {
      await _db.transaction(() async {
        final product = await _productsDao.save(
          ProductsCompanion(
            id: id == null ? const Value.absent() : Value(id),
            name: Value(name),
            category: Value(draft.category),
            brand: Value(draft.brand),
            size: Value(draft.size),
            color: Value(draft.color),
            sku: Value(draft.sku),
            barcode: Value(draft.barcode),
            pricePaise: Value(draft.price.paise),
            costPaise: Value(draft.cost?.paise),
            imageUrl: Value(draft.imageUrl),
          ),
        );

        // Reconcile stock to the requested amount; the inventory ledger records
        // the difference (initial stock on create, adjustment on edit).
        await _inventoryDao.setStock(
          productId: product.id,
          targetQty: draft.stock,
          reorderLevel: draft.reorderLevel,
          note: id == null ? 'Initial stock' : 'Manual adjustment',
        );
      });
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Save product failed', error: e, stackTrace: st);
      return const Result.failure(
        StorageFailure('Could not save the product.'),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _productsDao.softDelete(id);
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Delete product failed', error: e, stackTrace: st);
      return const Result.failure(
        StorageFailure('Could not delete the product.'),
      );
    }
  }

  ProductItem _toItem(CatalogRow row) =>
      _toItemFromProduct(row.product, row.stock, row.reorderLevel);

  ProductItem _toItemFromProduct(Product p, int stock, int reorderLevel) =>
      ProductItem(
        id: p.id,
        name: p.name,
        price: Money(p.pricePaise),
        stock: stock,
        reorderLevel: reorderLevel,
        category: p.category,
        brand: p.brand,
        size: p.size,
        color: p.color,
        sku: p.sku,
        barcode: p.barcode,
        cost: p.costPaise == null ? null : Money(p.costPaise!),
        imageUrl: p.imageUrl,
        isActive: p.isActive,
      );
}

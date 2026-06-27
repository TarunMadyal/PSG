import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/daos/products_dao.dart';
import '../domain/product_item.dart';
import '../domain/product_repository.dart';

/// Local implementation backed by [ProductsDao]. A product is just a name,
/// optional descriptors and a single selling price.
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({required ProductsDao productsDao})
      : _productsDao = productsDao;

  final ProductsDao _productsDao;

  @override
  Stream<List<ProductItem>> watchCatalog() {
    return _productsDao.watchActive().map(
          (rows) => rows.map(_toItem).toList(),
        );
  }

  @override
  Future<List<ProductItem>> search(String query) async {
    final products = await _productsDao.search(query);
    return products.map(_toItem).toList();
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

    try {
      await _productsDao.save(
        ProductsCompanion(
          id: id == null ? const Value.absent() : Value(id),
          name: Value(name),
          category: Value(draft.category),
          brand: Value(draft.brand),
          size: Value(draft.size),
          color: Value(draft.color),
          pricePaise: Value(draft.price.paise),
        ),
      );
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

  ProductItem _toItem(Product p) => ProductItem(
        id: p.id,
        name: p.name,
        price: Money(p.pricePaise),
        category: p.category,
        brand: p.brand,
        size: p.size,
        color: p.color,
        isActive: p.isActive,
      );
}

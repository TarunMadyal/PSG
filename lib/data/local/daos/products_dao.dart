import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'products_dao.g.dart';

/// A catalog row: a product joined with its current stock level.
typedef CatalogRow = ({Product product, int stock, int reorderLevel});

/// Data access for [Products], including the offline-first write pattern:
/// every save atomically persists the product **and** enqueues a sync outbox
/// entry in a single transaction.
@DriftAccessor(tables: [Products, Inventory, Outbox])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  /// Live catalog: active products left-joined with their stock, name-sorted.
  Stream<List<CatalogRow>> watchCatalog() {
    final query = select(products).join([
      leftOuterJoin(
        inventory,
        inventory.productId.equalsExp(products.id) &
            inventory.isDeleted.equals(false),
      ),
    ])
      ..where(products.isDeleted.equals(false) & products.isActive.equals(true))
      ..orderBy([OrderingTerm.asc(products.name)]);

    return query.watch().map(
          (rows) => rows.map((r) {
            final p = r.readTable(products);
            final inv = r.readTableOrNull(inventory);
            return (
              product: p,
              stock: inv?.qtyOnHand ?? 0,
              reorderLevel: inv?.reorderLevel ?? 0,
            );
          }).toList(),
        );
  }

  /// Active (non-deleted, in-stock-eligible) products, name-sorted, as a live
  /// stream so the UI updates instantly on any change.
  Stream<List<Product>> watchActive() {
    return (select(products)
          ..where((t) => t.isDeleted.equals(false) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Product>> getAll({bool includeDeleted = false}) {
    final query = select(products);
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<Product?> getById(String id) {
    return (select(products)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Case-insensitive search across name, SKU and barcode.
  Future<List<Product>> search(String query) {
    final like = '%${query.trim()}%';
    return (select(products)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                (t.name.like(like) |
                    t.sku.like(like) |
                    t.barcode.like(like)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Inserts or updates a product and enqueues it for sync, atomically.
  ///
  /// On update, [updatedAt] is refreshed and [version] bumped so delta sync and
  /// conflict resolution work correctly.
  /// Returns the persisted row (with generated id/defaults).
  Future<Product> save(ProductsCompanion product) {
    return transaction(() async {
      final existing = product.id.present
          ? await getById(product.id.value)
          : null;

      final toWrite = existing == null
          ? product
          : product.copyWith(
              updatedAt: Value(DateTime.now().toUtc()),
              version: Value(existing.version + 1),
            );

      final written = await into(products)
          .insertReturning(toWrite, mode: InsertMode.insertOrReplace);

      await into(outbox).insert(
        OutboxCompanion.insert(
          entityTable: products.actualTableName,
          rowId: written.id,
          op: OutboxOp.upsert,
          payload: Value(jsonEncode(written.toJson())),
        ),
      );

      return written;
    });
  }

  /// Soft-deletes a product (recoverable) and enqueues the deletion for sync.
  Future<void> softDelete(String id) {
    return transaction(() async {
      final existing = await getById(id);
      if (existing == null) return;

      await (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now().toUtc()),
          version: Value(existing.version + 1),
        ),
      );

      await into(outbox).insert(
        OutboxCompanion.insert(
          entityTable: products.actualTableName,
          rowId: id,
          op: OutboxOp.delete,
        ),
      );
    });
  }
}

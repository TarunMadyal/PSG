import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'inventory_dao.g.dart';

/// Data access for stock levels and the append-only movement ledger.
///
/// Stock is never set destructively: every change is recorded as a signed
/// movement, and the cached `qty_on_hand` is updated in the same transaction.
@DriftAccessor(tables: [Inventory, InventoryMovements, Outbox])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Future<InventoryData?> forProduct(String productId) {
    return (select(inventory)
          ..where(
            (t) => t.productId.equals(productId) & t.isDeleted.equals(false),
          ))
        .getSingleOrNull();
  }

  Future<int> qtyFor(String productId) async {
    final row = await forProduct(productId);
    return row?.qtyOnHand ?? 0;
  }

  /// Sets the absolute stock for a product to [targetQty], recording the
  /// difference as a ledger movement. Creates the inventory row on first use.
  /// Also (optionally) updates the reorder level.
  Future<void> setStock({
    required String productId,
    required int targetQty,
    int? reorderLevel,
    MovementReason reason = MovementReason.adjust,
    String? note,
  }) {
    return transaction(() async {
      final existing = await forProduct(productId);
      final current = existing?.qtyOnHand ?? 0;
      final delta = targetQty - current;

      if (existing == null) {
        final row = await into(inventory).insertReturning(
          InventoryCompanion.insert(
            productId: productId,
            qtyOnHand: Value(targetQty),
            reorderLevel: Value(reorderLevel ?? 0),
          ),
        );
        await _enqueue(inventory.actualTableName, row.id, row.toJson());
      } else {
        await (update(inventory)..where((t) => t.id.equals(existing.id))).write(
          InventoryCompanion(
            qtyOnHand: Value(targetQty),
            reorderLevel: reorderLevel == null
                ? const Value.absent()
                : Value(reorderLevel),
            updatedAt: Value(DateTime.now().toUtc()),
            version: Value(existing.version + 1),
          ),
        );
        final updated = await forProduct(productId);
        if (updated != null) {
          await _enqueue(inventory.actualTableName, updated.id, updated.toJson());
        }
      }

      if (delta != 0) {
        await _recordMovement(
          productId: productId,
          changeQty: delta,
          reason: existing == null ? MovementReason.restock : reason,
          note: note,
        );
      }
    });
  }

  /// Applies a relative [changeQty] (e.g. -1 for a sale) and records it.
  Future<void> adjust({
    required String productId,
    required int changeQty,
    required MovementReason reason,
    String? refBillId,
    String? note,
  }) {
    return transaction(() async {
      final existing = await forProduct(productId);
      final newQty = (existing?.qtyOnHand ?? 0) + changeQty;

      if (existing == null) {
        final row = await into(inventory).insertReturning(
          InventoryCompanion.insert(
            productId: productId,
            qtyOnHand: Value(newQty),
          ),
        );
        await _enqueue(inventory.actualTableName, row.id, row.toJson());
      } else {
        await (update(inventory)..where((t) => t.id.equals(existing.id))).write(
          InventoryCompanion(
            qtyOnHand: Value(newQty),
            updatedAt: Value(DateTime.now().toUtc()),
            version: Value(existing.version + 1),
          ),
        );
        final updated = await forProduct(productId);
        if (updated != null) {
          await _enqueue(inventory.actualTableName, updated.id, updated.toJson());
        }
      }

      await _recordMovement(
        productId: productId,
        changeQty: changeQty,
        reason: reason,
        refBillId: refBillId,
        note: note,
      );
    });
  }

  Future<void> _recordMovement({
    required String productId,
    required int changeQty,
    required MovementReason reason,
    String? refBillId,
    String? note,
  }) async {
    final move = await into(inventoryMovements).insertReturning(
      InventoryMovementsCompanion.insert(
        productId: productId,
        changeQty: changeQty,
        reason: reason,
        refBillId: Value(refBillId),
        note: Value(note),
      ),
    );
    await _enqueue(
      inventoryMovements.actualTableName,
      move.id,
      move.toJson(),
    );
  }

  Future<void> _enqueue(
    String table,
    String rowId,
    Map<String, dynamic> payload,
  ) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        entityTable: table,
        rowId: rowId,
        op: OutboxOp.upsert,
        payload: Value(jsonEncode(payload)),
      ),
    );
  }
}

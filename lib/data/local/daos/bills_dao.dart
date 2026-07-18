import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'bills_dao.g.dart';

/// A bill with its line items, for receipts and history.
typedef BillWithItems = ({Bill bill, List<BillItem> items});

/// Data access for bills (invoices) and their line items.
@DriftAccessor(tables: [Bills, BillItems, Outbox])
class BillsDao extends DatabaseAccessor<AppDatabase> with _$BillsDaoMixin {
  BillsDao(super.db);

  /// Generates the next invoice number for the given bill type. GST bills use a
  /// separate "GST-" series and plain bills an "INV-" series, each counted and
  /// numbered independently so the two ledgers stay cleanly separated.
  Future<String> nextInvoiceNo({required bool isGst}) async {
    final countExp = bills.id.count();
    final row = await (selectOnly(bills)
          ..addColumns([countExp])
          ..where(bills.isGst.equals(isGst)))
        .getSingle();
    final next = (row.read(countExp) ?? 0) + 1;
    final prefix = isGst ? 'GST' : 'INV';
    return '$prefix-${next.toString().padLeft(5, '0')}';
  }

  Future<Bill> insertBill(BillsCompanion bill) async {
    final written = await into(bills).insertReturning(bill);
    await _enqueue(bills.actualTableName, written.id, written.toJson());
    return written;
  }

  Future<void> insertItem(BillItemsCompanion item) async {
    final written = await into(billItems).insertReturning(item);
    await _enqueue(billItems.actualTableName, written.id, written.toJson());
  }

  /// Most recent non-deleted bills, newest first.
  Stream<List<Bill>> watchRecent({int limit = 25}) {
    return (select(bills)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.billedAt)])
          ..limit(limit))
        .watch();
  }

  /// A customer's bills, newest first (for the customer history screen).
  Stream<List<Bill>> watchForCustomer(String customerId) {
    return (select(bills)
          ..where(
            (t) => t.customerId.equals(customerId) & t.isDeleted.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.billedAt)]))
        .watch();
  }

  Future<List<BillItem>> itemsFor(String billId) {
    return (select(billItems)..where((t) => t.billId.equals(billId))).get();
  }

  Future<BillWithItems?> getWithItems(String billId) async {
    final bill =
        await (select(bills)..where((t) => t.id.equals(billId))).getSingleOrNull();
    if (bill == null) return null;
    return (bill: bill, items: await itemsFor(billId));
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

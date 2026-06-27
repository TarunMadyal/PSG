import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'reports_dao.g.dart';

/// Aggregated read models for the sales summary.
typedef SalesAggregate = ({int totalPaise, int discountPaise, int billCount});

/// A top-selling product over a period.
typedef BestSellerRow = ({String name, int qtySold, int revenuePaise});

/// A product at or below its reorder level.
typedef LowStockRow = ({String name, int stock, int reorderLevel});

/// Inventory valuation across the active catalog.
typedef InventoryValueRow = ({
  int retailPaise,
  int costPaise,
  int productCount,
  int totalUnits,
});

/// Read-only aggregate queries that power the Reports screen. Date filters use
/// a half-open `[from, to)` range on `billed_at`; only completed, non-deleted
/// bills count toward sales.
@DriftAccessor(tables: [Bills, BillItems, Products, Inventory])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.db);

  Expression<bool> _completedInRange(DateTime from, DateTime to) {
    return bills.isDeleted.equals(false) &
        bills.status.equalsValue(BillStatus.completed) &
        bills.billedAt.isBiggerOrEqualValue(from) &
        bills.billedAt.isSmallerThanValue(to);
  }

  /// Total sales, total discount and number of bills in the range.
  Future<SalesAggregate> salesSummary(DateTime from, DateTime to) async {
    final total = bills.grandTotalPaise.sum();
    final discount = bills.discountPaise.sum();
    final count = bills.id.count();

    final row = await (selectOnly(bills)
          ..addColumns([total, discount, count])
          ..where(_completedInRange(from, to)))
        .getSingle();

    return (
      totalPaise: row.read(total) ?? 0,
      discountPaise: row.read(discount) ?? 0,
      billCount: row.read(count) ?? 0,
    );
  }

  /// Number of individual units sold in the range.
  Future<int> itemsSold(DateTime from, DateTime to) async {
    final qty = billItems.qty.sum();
    final query = selectOnly(billItems).join([
      innerJoin(bills, bills.id.equalsExp(billItems.billId)),
    ])
      ..addColumns([qty])
      ..where(_completedInRange(from, to));

    final row = await query.getSingle();
    return row.read(qty) ?? 0;
  }

  /// Best-selling products in the range, by units sold.
  Future<List<BestSellerRow>> bestSellers(
    DateTime from,
    DateTime to, {
    int limit = 10,
  }) async {
    final qty = billItems.qty.sum();
    final revenue = billItems.amountPaise.sum();

    final query = selectOnly(billItems).join([
      innerJoin(bills, bills.id.equalsExp(billItems.billId)),
    ])
      ..addColumns([billItems.nameSnapshot, qty, revenue])
      ..where(_completedInRange(from, to))
      ..groupBy([billItems.nameSnapshot])
      ..orderBy([OrderingTerm.desc(qty)])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (r) => (
            name: r.read(billItems.nameSnapshot)!,
            qtySold: r.read(qty) ?? 0,
            revenuePaise: r.read(revenue) ?? 0,
          ),
        )
        .toList();
  }

  /// Active products at or below their reorder level, lowest first.
  Future<List<LowStockRow>> lowStock({int limit = 50}) async {
    final query = select(products).join([
      innerJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(
        products.isDeleted.equals(false) &
            products.isActive.equals(true) &
            inventory.isDeleted.equals(false) &
            inventory.qtyOnHand.isSmallerOrEqual(inventory.reorderLevel),
      )
      ..orderBy([OrderingTerm.asc(inventory.qtyOnHand)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map((r) {
      final p = r.readTable(products);
      final inv = r.readTable(inventory);
      return (name: p.name, stock: inv.qtyOnHand, reorderLevel: inv.reorderLevel);
    }).toList();
  }

  /// Inventory valuation at retail and cost across the active catalog.
  Future<InventoryValueRow> inventoryValue() async {
    final retail =
        (inventory.qtyOnHand * products.pricePaise).sum();
    final cost =
        (inventory.qtyOnHand * products.costPaise).sum();
    final units = inventory.qtyOnHand.sum();
    final count = products.id.count();

    final query = selectOnly(products).join([
      innerJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..addColumns([retail, cost, units, count])
      ..where(
        products.isDeleted.equals(false) &
            products.isActive.equals(true) &
            inventory.isDeleted.equals(false),
      );

    final row = await query.getSingle();
    return (
      retailPaise: row.read(retail) ?? 0,
      costPaise: row.read(cost) ?? 0,
      productCount: row.read(count) ?? 0,
      totalUnits: row.read(units) ?? 0,
    );
  }
}

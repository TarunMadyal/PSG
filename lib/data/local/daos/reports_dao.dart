import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'reports_dao.g.dart';

/// Aggregated read models for the sales summary.
typedef SalesAggregate = ({int totalPaise, int discountPaise, int billCount});

/// A top-selling product over a period.
typedef BestSellerRow = ({String name, int qtySold, int revenuePaise});

/// Read-only aggregate queries that power the Reports screen. Date filters use
/// a half-open `[from, to)` range on `billed_at`; only completed, non-deleted
/// bills count toward sales.
@DriftAccessor(tables: [Bills, BillItems])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.db);

  Expression<bool> _completedInRange(DateTime from, DateTime to, bool? isGst) {
    var expr = bills.isDeleted.equals(false) &
        bills.status.equalsValue(BillStatus.completed) &
        bills.billedAt.isBiggerOrEqualValue(from) &
        bills.billedAt.isSmallerThanValue(to);
    if (isGst != null) expr = expr & bills.isGst.equals(isGst);
    return expr;
  }

  /// Total sales, total discount and number of bills in the range.
  Future<SalesAggregate> salesSummary(
    DateTime from,
    DateTime to, {
    bool? isGst,
  }) async {
    final total = bills.grandTotalPaise.sum();
    final discount = bills.discountPaise.sum();
    final count = bills.id.count();

    final row = await (selectOnly(bills)
          ..addColumns([total, discount, count])
          ..where(_completedInRange(from, to, isGst)))
        .getSingle();

    return (
      totalPaise: row.read(total) ?? 0,
      discountPaise: row.read(discount) ?? 0,
      billCount: row.read(count) ?? 0,
    );
  }

  /// All completed bills in the range (newest last), for a detailed listing.
  Future<List<Bill>> billsInRange(
    DateTime from,
    DateTime to, {
    bool? isGst,
  }) {
    return (select(bills)
          ..where((t) => _completedInRange(from, to, isGst))
          ..orderBy([(t) => OrderingTerm.asc(t.billedAt)]))
        .get();
  }

  /// Number of individual units sold in the range.
  Future<int> itemsSold(DateTime from, DateTime to, {bool? isGst}) async {
    final qty = billItems.qty.sum();
    final query = selectOnly(billItems).join([
      innerJoin(bills, bills.id.equalsExp(billItems.billId)),
    ])
      ..addColumns([qty])
      ..where(_completedInRange(from, to, isGst));

    final row = await query.getSingle();
    return row.read(qty) ?? 0;
  }

  /// Best-selling products in the range, by units sold.
  Future<List<BestSellerRow>> bestSellers(
    DateTime from,
    DateTime to, {
    int limit = 10,
    bool? isGst,
  }) async {
    final qty = billItems.qty.sum();
    final revenue = billItems.amountPaise.sum();

    final query = selectOnly(billItems).join([
      innerJoin(bills, bills.id.equalsExp(billItems.billId)),
    ])
      ..addColumns([billItems.nameSnapshot, qty, revenue])
      ..where(_completedInRange(from, to, isGst))
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
}

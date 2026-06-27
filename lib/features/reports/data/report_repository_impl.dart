import '../../../core/utils/money.dart';
import '../../../data/local/daos/reports_dao.dart';
import '../domain/report_models.dart';
import '../domain/report_range.dart';
import '../domain/report_repository.dart';

/// Local implementation backed by [ReportsDao] aggregate queries.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._dao);

  final ReportsDao _dao;

  @override
  Future<SalesSummary> salesSummary(ReportRange range) async {
    final (from, to) = range.bounds();
    final agg = await _dao.salesSummary(from, to);
    final items = await _dao.itemsSold(from, to);
    return SalesSummary(
      totalSales: Money(agg.totalPaise),
      totalDiscount: Money(agg.discountPaise),
      billCount: agg.billCount,
      itemsSold: items,
    );
  }

  @override
  Future<List<BestSeller>> bestSellers(ReportRange range, {int limit = 10}) async {
    final (from, to) = range.bounds();
    final rows = await _dao.bestSellers(from, to, limit: limit);
    return rows
        .map(
          (r) => BestSeller(
            name: r.name,
            qtySold: r.qtySold,
            revenue: Money(r.revenuePaise),
          ),
        )
        .toList();
  }

  @override
  Future<List<LowStockItem>> lowStock({int limit = 50}) async {
    final rows = await _dao.lowStock(limit: limit);
    return rows
        .map(
          (r) => LowStockItem(
            name: r.name,
            stock: r.stock,
            reorderLevel: r.reorderLevel,
          ),
        )
        .toList();
  }

  @override
  Future<InventorySnapshot> inventoryValue() async {
    final v = await _dao.inventoryValue();
    return InventorySnapshot(
      retailValue: Money(v.retailPaise),
      costValue: Money(v.costPaise),
      productCount: v.productCount,
      totalUnits: v.totalUnits,
    );
  }

  @override
  Future<ReportDashboard> dashboard(ReportRange range) async {
    final results = await Future.wait([
      salesSummary(range),
      bestSellers(range),
      lowStock(),
      inventoryValue(),
    ]);
    return ReportDashboard(
      sales: results[0] as SalesSummary,
      bestSellers: results[1] as List<BestSeller>,
      lowStock: results[2] as List<LowStockItem>,
      inventory: results[3] as InventorySnapshot,
    );
  }
}

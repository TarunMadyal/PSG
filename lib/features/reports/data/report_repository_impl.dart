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
  Future<ReportDashboard> dashboard(ReportRange range) async {
    final sales = await salesSummary(range);
    final best = await bestSellers(range);
    return ReportDashboard(sales: sales, bestSellers: best);
  }
}

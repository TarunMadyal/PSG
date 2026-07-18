import '../../../core/utils/money.dart';
import '../../../data/local/daos/reports_dao.dart';
import '../domain/report_filter.dart';
import '../domain/report_models.dart';
import '../domain/report_range.dart';
import '../domain/report_repository.dart';

/// Local implementation backed by [ReportsDao] aggregate queries.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._dao);

  final ReportsDao _dao;

  @override
  Future<SalesSummary> salesSummary(
    ReportRange range, {
    GstFilter filter = GstFilter.all,
  }) async {
    final (from, to) = range.bounds();
    final isGst = filter.isGstValue;
    final agg = await _dao.salesSummary(from, to, isGst: isGst);
    final items = await _dao.itemsSold(from, to, isGst: isGst);
    return SalesSummary(
      totalSales: Money(agg.totalPaise),
      totalDiscount: Money(agg.discountPaise),
      billCount: agg.billCount,
      itemsSold: items,
    );
  }

  @override
  Future<List<BestSeller>> bestSellers(
    ReportRange range, {
    int limit = 10,
    GstFilter filter = GstFilter.all,
  }) async {
    final (from, to) = range.bounds();
    final rows =
        await _dao.bestSellers(from, to, limit: limit, isGst: filter.isGstValue);
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
  Future<List<ReportBillRow>> billsInRange(
    ReportRange range, {
    GstFilter filter = GstFilter.all,
  }) async {
    final (from, to) = range.bounds();
    final rows = await _dao.billsInRange(from, to, isGst: filter.isGstValue);
    return rows
        .map(
          (b) => ReportBillRow(
            invoiceNo: b.invoiceNo,
            billedAt: b.billedAt,
            paymentMethod: b.paymentMethod,
            total: Money(b.grandTotalPaise),
            isGst: b.isGst,
          ),
        )
        .toList();
  }

  @override
  Future<ReportDashboard> dashboard(
    ReportRange range, {
    GstFilter filter = GstFilter.all,
  }) async {
    final sales = await salesSummary(range, filter: filter);
    final best = await bestSellers(range, filter: filter);
    return ReportDashboard(sales: sales, bestSellers: best);
  }
}

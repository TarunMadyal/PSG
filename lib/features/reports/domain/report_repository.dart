import 'report_filter.dart';
import 'report_models.dart';
import 'report_range.dart';

/// Contract for the reporting/analytics read models.
abstract interface class ReportRepository {
  Future<SalesSummary> salesSummary(
    ReportRange range, {
    GstFilter filter,
    DateTime? date,
  });
  Future<List<BestSeller>> bestSellers(
    ReportRange range, {
    int limit,
    GstFilter filter,
    DateTime? date,
  });

  /// Individual bills in the range (for the detailed report listing).
  Future<List<ReportBillRow>> billsInRange(
    ReportRange range, {
    GstFilter filter,
    DateTime? date,
  });

  /// Convenience: fetches the full dashboard for [range] in one call.
  Future<ReportDashboard> dashboard(
    ReportRange range, {
    GstFilter filter,
    DateTime? date,
  });
}

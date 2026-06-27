import 'report_models.dart';
import 'report_range.dart';

/// Contract for the reporting/analytics read models.
abstract interface class ReportRepository {
  Future<SalesSummary> salesSummary(ReportRange range);
  Future<List<BestSeller>> bestSellers(ReportRange range, {int limit});
  Future<List<LowStockItem>> lowStock({int limit});
  Future<InventorySnapshot> inventoryValue();

  /// Convenience: fetches the full dashboard for [range] in one call.
  Future<ReportDashboard> dashboard(ReportRange range);
}

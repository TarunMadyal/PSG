import '../../../core/utils/money.dart';

/// Sales totals for a period.
class SalesSummary {
  const SalesSummary({
    required this.totalSales,
    required this.totalDiscount,
    required this.billCount,
    required this.itemsSold,
  });

  final Money totalSales;
  final Money totalDiscount;
  final int billCount;
  final int itemsSold;

  /// Average bill value (zero when there are no bills).
  Money get averageBill =>
      billCount == 0 ? Money.zero : Money((totalSales.paise / billCount).round());

  static const SalesSummary empty = SalesSummary(
    totalSales: Money.zero,
    totalDiscount: Money.zero,
    billCount: 0,
    itemsSold: 0,
  );
}

/// A top-selling product over a period.
class BestSeller {
  const BestSeller({
    required this.name,
    required this.qtySold,
    required this.revenue,
  });

  final String name;
  final int qtySold;
  final Money revenue;
}

/// A product at or below its reorder level.
class LowStockItem {
  const LowStockItem({
    required this.name,
    required this.stock,
    required this.reorderLevel,
  });

  final String name;
  final int stock;
  final int reorderLevel;
}

/// Inventory valuation snapshot.
class InventorySnapshot {
  const InventorySnapshot({
    required this.retailValue,
    required this.costValue,
    required this.productCount,
    required this.totalUnits,
  });

  final Money retailValue;
  final Money costValue;
  final int productCount;
  final int totalUnits;

  /// Potential gross margin if everything in stock sold at current prices.
  Money get potentialMargin => retailValue - costValue;

  static const InventorySnapshot empty = InventorySnapshot(
    retailValue: Money.zero,
    costValue: Money.zero,
    productCount: 0,
    totalUnits: 0,
  );
}

/// Everything the Reports dashboard shows for a selected range, fetched together.
class ReportDashboard {
  const ReportDashboard({
    required this.sales,
    required this.bestSellers,
    required this.lowStock,
    required this.inventory,
  });

  final SalesSummary sales;
  final List<BestSeller> bestSellers;
  final List<LowStockItem> lowStock;
  final InventorySnapshot inventory;
}

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

/// Everything the Reports dashboard shows for a selected range, fetched together.
class ReportDashboard {
  const ReportDashboard({
    required this.sales,
    required this.bestSellers,
  });

  final SalesSummary sales;
  final List<BestSeller> bestSellers;
}

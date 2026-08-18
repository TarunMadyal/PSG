/// The period a report covers. Bounds are computed as a half-open `[from, to)`
/// range in UTC (matching how `billed_at` is stored), spanning from the start
/// of the period up to the end of today.
enum ReportRange {
  today,
  custom,
  month,
  quarter,
  year;

  String get label => switch (this) {
        ReportRange.today => 'Today',
        ReportRange.custom => 'Custom Date',
        ReportRange.month => 'This Month',
        ReportRange.quarter => 'This Quarter',
        ReportRange.year => 'This Year',
      };

  /// Returns the `[from, to)` UTC bounds for this range relative to [now]
  /// (defaults to the current local time).
  (DateTime from, DateTime to) bounds([DateTime? now]) {
    final n = now ?? DateTime.now();
    final startOfDay = DateTime(n.year, n.month, n.day);

    final from = switch (this) {
      ReportRange.today => startOfDay,
      ReportRange.custom => startOfDay,
      ReportRange.month => DateTime(n.year, n.month),
      // Quarter starts on the first day of the current 3-month block
      // (Jan/Apr/Jul/Oct).
      ReportRange.quarter => DateTime(n.year, ((n.month - 1) ~/ 3) * 3 + 1),
      ReportRange.year => DateTime(n.year),
    };

    final to = startOfDay.add(const Duration(days: 1));
    return (from.toUtc(), to.toUtc());
  }
}

/// The period a report covers. Bounds are computed as a half-open `[from, to)`
/// range in UTC (matching how `billed_at` is stored), spanning from the start
/// of the period up to the end of today.
enum ReportRange {
  today,
  week,
  month,
  year;

  String get label => switch (this) {
        ReportRange.today => 'Today',
        ReportRange.week => 'This Week',
        ReportRange.month => 'This Month',
        ReportRange.year => 'This Year',
      };

  /// Returns the `[from, to)` UTC bounds for this range relative to [now]
  /// (defaults to the current local time).
  (DateTime from, DateTime to) bounds([DateTime? now]) {
    final n = now ?? DateTime.now();
    final startOfDay = DateTime(n.year, n.month, n.day);

    final from = switch (this) {
      ReportRange.today => startOfDay,
      // Week starts Monday.
      ReportRange.week => startOfDay.subtract(Duration(days: n.weekday - 1)),
      ReportRange.month => DateTime(n.year, n.month),
      ReportRange.year => DateTime(n.year),
    };

    final to = startOfDay.add(const Duration(days: 1));
    return (from.toUtc(), to.toUtc());
  }
}

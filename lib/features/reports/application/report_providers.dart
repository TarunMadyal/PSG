import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/report_repository_impl.dart';
import '../domain/report_filter.dart';
import '../domain/report_models.dart';
import '../domain/report_range.dart';
import '../domain/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ReportRepositoryImpl(db.reportsDao);
});

/// The range currently selected on the Reports screen.
final selectedRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.today,
);

/// Date used when the owner selects the custom single-day report.
final selectedReportDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

/// The GST scope currently selected on the Reports screen.
final selectedGstFilterProvider = StateProvider<GstFilter>(
  (ref) => GstFilter.all,
);

/// The dashboard for the selected range + GST scope. Re-fetches when either
/// changes.
final reportDashboardProvider = FutureProvider<ReportDashboard>((ref) {
  final range = ref.watch(selectedRangeProvider);
  final filter = ref.watch(selectedGstFilterProvider);
  final date = ref.watch(selectedReportDateProvider);
  return ref
      .watch(reportRepositoryProvider)
      .dashboard(range, filter: filter, date: date);
});

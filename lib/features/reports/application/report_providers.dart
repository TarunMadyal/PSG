import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/report_repository_impl.dart';
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

/// The dashboard for the selected range. Re-fetches when the range changes.
final reportDashboardProvider = FutureProvider<ReportDashboard>((ref) {
  final range = ref.watch(selectedRangeProvider);
  return ref.watch(reportRepositoryProvider).dashboard(range);
});

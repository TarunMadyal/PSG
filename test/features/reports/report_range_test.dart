import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/features/reports/domain/report_range.dart';

void main() {
  group('ReportRange.quarter bounds', () {
    test('a July date starts the quarter on 1 July', () {
      final (from, _) = ReportRange.quarter.bounds(DateTime(2026, 7, 17));
      expect(from, DateTime(2026, 7).toUtc());
    });

    test('a February date starts the quarter on 1 January', () {
      final (from, _) = ReportRange.quarter.bounds(DateTime(2026, 2, 15));
      expect(from, DateTime(2026, 1).toUtc());
    });

    test('a December date starts the quarter on 1 October', () {
      final (from, _) = ReportRange.quarter.bounds(DateTime(2026, 12, 31));
      expect(from, DateTime(2026, 10).toUtc());
    });
  });

  test('week is no longer a report range', () {
    expect(
      ReportRange.values.map((r) => r.name),
      ['today', 'month', 'quarter', 'year'],
    );
  });
}

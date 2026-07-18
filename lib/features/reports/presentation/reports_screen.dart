import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/file_share.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../printing/application/printing_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../application/report_providers.dart';
import '../data/report_pdf.dart';
import '../domain/report_filter.dart';
import '../domain/report_models.dart';
import '../domain/report_range.dart';

/// Sales & inventory reports (owner). Implemented in Phase 7.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  static const String title = 'Reports';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(selectedRangeProvider);
    final gstFilter = ref.watch(selectedGstFilterProvider);
    final dashboard = ref.watch(reportDashboardProvider);

    return Scaffold(
      floatingActionButton: dashboard.hasValue
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'reportPdf',
                  onPressed: () => _downloadPdf(context, ref),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download PDF'),
                ),
                const SizedBox(height: AppSpacing.md),
                FloatingActionButton.extended(
                  heroTag: 'reportPrint',
                  onPressed: () => _printReport(context, ref),
                  icon: const Icon(Icons.print_outlined),
                  label: Text('Print ${range.label.toLowerCase()} report'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ReportRange>(
                segments: [
                  for (final r in ReportRange.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {range},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(selectedRangeProvider.notifier).state = s.first,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SegmentedButton<GstFilter>(
              segments: [
                for (final f in GstFilter.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {gstFilter},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(selectedGstFilterProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: dashboard.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load reports: $e')),
              data: (data) => _DashboardView(data: data, range: range),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport(BuildContext context, WidgetRef ref) async {
    final range = ref.read(selectedRangeProvider);
    final data = ref.read(reportDashboardProvider).valueOrNull;
    final messenger = ScaffoldMessenger.of(context);
    if (data == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Report is still loading.')),
      );
      return;
    }
    final filter = ref.read(selectedGstFilterProvider);
    final ok = await confirmDialog(
      context,
      title: 'Print report?',
      message: 'Print the ${range.label.toLowerCase()} report '
          '(${filter.label.toLowerCase()}) to the printer?',
    );
    if (!ok) return;
    final shop = await ref.read(settingsRepositoryProvider).get();
    final result = await ref
        .read(printerServiceProvider)
        .printReport(data, range, shop, filter: filter);
    result.fold(
      (_) => messenger.showSnackBar(
        const SnackBar(content: Text('Report sent to printer.')),
      ),
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    final range = ref.read(selectedRangeProvider);
    final data = ref.read(reportDashboardProvider).valueOrNull;
    final messenger = ScaffoldMessenger.of(context);
    if (data == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Report is still loading.')),
      );
      return;
    }
    try {
      final filter = ref.read(selectedGstFilterProvider);
      final shop = await ref.read(settingsRepositoryProvider).get();
      final bills = await ref
          .read(reportRepositoryProvider)
          .billsInRange(range, filter: filter);
      final bytes = await buildReportPdf(
        data,
        range,
        shop,
        DateTime.now(),
        bills: bills,
      );
      final stamp = range.label.toLowerCase().replaceAll(' ', '-');
      await shareBytes(
        bytes,
        filename: 'psg-$stamp-report.pdf',
        subject: '${shop.shopName} — ${range.label} sales report',
        text: 'Sales report attached.',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create the PDF: $e')),
      );
    }
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.data, required this.range});

  final ReportDashboard data;
  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    final s = data.sales;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _KpiCard(
              label: '${range.label} sales',
              value: s.totalSales.formatted,
              icon: Icons.payments_outlined,
              accent: AppColors.success,
            ),
            _KpiCard(
              label: 'Bills',
              value: '${s.billCount}',
              icon: Icons.receipt_long_outlined,
            ),
            _KpiCard(
              label: 'Items sold',
              value: '${s.itemsSold}',
              icon: Icons.shopping_bag_outlined,
            ),
            _KpiCard(
              label: 'Avg. bill',
              value: s.averageBill.formatted,
              icon: Icons.trending_up,
            ),
            _KpiCard(
              label: 'Discounts given',
              value: s.totalDiscount.formatted,
              icon: Icons.percent,
              accent: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionCard(
          title: 'Best sellers',
          icon: Icons.star_outline,
          child: data.bestSellers.isEmpty
              ? const _EmptyRow('No sales in this period yet.')
              : Column(
                  children: [
                    for (final b in data.bestSellers)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(b.name),
                        subtitle: Text('${b.qtySold} sold'),
                        trailing: Text(
                          b.revenue.formatted,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

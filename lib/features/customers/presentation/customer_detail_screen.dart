import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/app_database.dart';
import '../../billing/application/billing_providers.dart';
import '../../billing/presentation/widgets/receipt_dialog.dart';
import '../application/customers_providers.dart';

/// One customer's profile and their full bill history. Tapping a bill reopens
/// the receipt so it can be viewed or reprinted.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(customerBillsProvider(customer.id));
    final scheme = Theme.of(context).colorScheme;
    final name = (customer.name == null || customer.name!.isEmpty)
        ? 'Customer'
        : customer.name!;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (customer.phone != null && customer.phone!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14),
                            const SizedBox(width: 4),
                            Text(customer.phone!),
                          ],
                        ),
                      Text(
                        'Since ${Formatters.date(customer.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Purchase history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: bills.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load bills: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No bills yet for this customer.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = list[i];
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(b.invoiceNo),
                      subtitle: Text(
                        '${Formatters.dateTime(b.billedAt)}  ·  '
                        '${_payLabel(b.paymentMethod)}',
                      ),
                      trailing: Text(
                        b.grandTotal.formatted,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => _openReceipt(context, ref, b.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReceipt(
    BuildContext context,
    WidgetRef ref,
    String billId,
  ) async {
    final receipt = await ref.read(billRepositoryProvider).receiptFor(billId);
    if (!context.mounted) return;
    if (receipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load that bill.')),
      );
      return;
    }
    await showReceiptDialog(context, receipt);
  }

  String _payLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.other => 'Other',
      };
}

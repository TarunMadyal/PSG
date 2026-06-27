import 'package:flutter/material.dart';

import '../../../../core/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/bill_receipt.dart';

/// Shows a post-sale confirmation with the invoice details. Printing is wired
/// up in Phase 6 (the button is present but disabled for now).
Future<void> showReceiptDialog(BuildContext context, BillReceipt receipt) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 56,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sale complete',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${receipt.invoiceNo} · ${Formatters.dateTime(receipt.billedAt)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              ...receipt.lines.map(
                (l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text('${l.name}  ×${l.qty}')),
                      Text(l.amount.formatted),
                    ],
                  ),
                ),
              ),
              const Divider(),
              _totalRow(
                context,
                'Grand total',
                receipt.grandTotal.formatted,
                bold: true,
              ),
              _metaRow(context, 'Payment', _paymentLabel(receipt.paymentMethod)),
              if (receipt.customerPhone != null)
                _metaRow(context, 'Customer', receipt.customerPhone!),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // Enabled in Phase 6 (printing).
                      onPressed: null,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('New sale'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _totalRow(
  BuildContext context,
  String label,
  String value, {
  bool bold = false,
}) {
  final style = Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    ),
  );
}

Widget _metaRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value),
      ],
    ),
  );
}

String _paymentLabel(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.card => 'Card',
      PaymentMethod.upi => 'UPI',
      PaymentMethod.other => 'Other',
    };

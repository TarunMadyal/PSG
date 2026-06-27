import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../printing/application/printing_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../settings/domain/shop_profile.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../domain/bill_receipt.dart';

/// Shows a post-sale confirmation laid out like the printed bill — logo + shop
/// details on top, the items in the middle, and a thank-you footer — with a
/// working Print button for the Bluetooth thermal printer.
Future<void> showReceiptDialog(BuildContext context, BillReceipt receipt) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _ReceiptView(receipt: receipt),
      ),
    ),
  );
}

class _ReceiptView extends ConsumerStatefulWidget {
  const _ReceiptView({required this.receipt});

  final BillReceipt receipt;

  @override
  ConsumerState<_ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends ConsumerState<_ReceiptView> {
  bool _printing = false;

  Future<void> _print(ShopProfile shop) async {
    setState(() => _printing = true);
    final result =
        await ref.read(printerServiceProvider).printReceipt(widget.receipt, shop);
    if (!mounted) return;
    setState(() => _printing = false);
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill sent to printer.')),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    final shop = ref.watch(shopProfileProvider).valueOrNull ?? ShopProfile.defaults;
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo + shop header ──────────────────────────────
          const Center(child: AppLogo(size: 56)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            shop.shopName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (_has(shop.address))
            Text(shop.address!, textAlign: TextAlign.center, style: muted),
          if (_has(shop.phone))
            Text('Ph: ${shop.phone}', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: AppSpacing.md),
          const Divider(),

          // ── Bill meta ───────────────────────────────────────
          _meta(context, 'Invoice', r.invoiceNo),
          _meta(context, 'Date', Formatters.dateTime(r.billedAt)),
          _meta(context, 'Cashier', r.cashierName),
          if (_has(r.customerPhone)) _meta(context, 'Customer', r.customerPhone!),
          const Divider(),

          // ── Items ───────────────────────────────────────────
          ...r.lines.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${l.name}  ×${l.qty}'),
                        if (!l.discount.isZero)
                          Text('  less ${l.discount.formatted}', style: muted),
                      ],
                    ),
                  ),
                  Text(l.amount.formatted),
                ],
              ),
            ),
          ),
          const Divider(),

          // ── Totals ──────────────────────────────────────────
          _total(context, 'Subtotal', r.subtotal.formatted),
          if (!r.discount.isZero)
            _total(context, 'Discount', '-${r.discount.formatted}'),
          _total(context, 'Grand total', r.grandTotal.formatted, bold: true),
          _meta(context, 'Payment', _paymentLabel(r.paymentMethod)),

          if (_has(shop.footerText)) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              shop.footerText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _printing ? null : () => _print(shop),
                  icon: _printing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
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
    );
  }

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  Widget _meta(BuildContext context, String label, String value) {
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

  Widget _total(
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
}

String _paymentLabel(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.card => 'Card',
      PaymentMethod.upi => 'UPI',
      PaymentMethod.other => 'Other',
    };

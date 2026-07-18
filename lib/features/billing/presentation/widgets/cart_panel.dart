import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/billing_providers.dart';
import '../../application/cart_controller.dart';
import '../../domain/cart.dart';
import 'amount_dialog.dart';
import 'receipt_dialog.dart';
import 'upi_qr_dialog.dart';

/// The right-hand "current sale" panel: line items, discounts, payment method,
/// optional customer, totals and the charge button.
class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  bool _charging = false;

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    final user = ref.read(currentUserProvider);
    if (cart.isEmpty || user == null || _charging) return;

    setState(() => _charging = true);
    final result = await ref.read(billRepositoryProvider).checkout(
          cart: cart,
          cashierId: user.id,
          cashierName: user.name,
          isGst: cart.isGst,
        );
    if (!mounted) return;
    setState(() => _charging = false);

    result.fold(
      (receipt) {
        ref.read(cartProvider.notifier).clear();
        showReceiptDialog(context, receipt);
      },
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                'Current sale',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton.icon(
                  onPressed: () => ref.read(cartProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: cart.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _CartLineTile(line: cart.lines[i]),
                ),
        ),
        if (cart.isNotEmpty) ...[
          const Divider(height: 1),
          _CustomerField(cart: cart),
          _PaymentSelector(selected: cart.paymentMethod),
          if (cart.paymentMethod == PaymentMethod.cashPlusUpi)
            _SplitCashField(cart: cart),
          _GstToggle(isGst: cart.isGst),
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _totalRow(context, 'Subtotal', cart.subtotal),
                InkWell(
                  onTap: () async {
                    final value = await promptAmount(
                      context,
                      title: 'Bill discount',
                      initial: cart.billDiscount,
                    );
                    if (value != null) {
                      ref.read(cartProvider.notifier).setBillDiscount(value);
                    }
                  },
                  child: _totalRow(
                    context,
                    'Discount',
                    cart.totalDiscount,
                    actionable: true,
                    negative: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _totalRow(context, 'Total', cart.grandTotal, emphasize: true),
                const SizedBox(height: AppSpacing.md),
                _UpiPayButton(amount: cart.upiPortion),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _charging ? null : _checkout,
                    child: _charging
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Charge ${cart.grandTotal.formatted}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Roboto',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('No items yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap a product to add it to the bill.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    Money value, {
    bool emphasize = false,
    bool actionable = false,
    bool negative = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: style),
              if (actionable) Icon(Icons.edit, size: 14, color: scheme.primary),
            ],
          ),
          Text(
            '${negative && !value.isZero ? '-' : ''}${value.formatted}',
            style: style,
          ),
        ],
      ),
    );
  }
}

/// "Pay by UPI" — shows a scannable QR for the current cart total so the
/// customer can pay BEFORE the bill is finalised. Only appears once a UPI ID is
/// configured in Settings.
class _UpiPayButton extends ConsumerWidget {
  const _UpiPayButton({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProfileProvider).valueOrNull;
    if (shop == null || !shop.hasUpi || amount.isZero) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () =>
              showUpiQrDialog(context, shop: shop, amount: amount, note: 'Sale'),
          icon: const Icon(Icons.qr_code_2),
          label: Text('Pay by UPI  ${amount.formatted}'),
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  line.discount.isZero
                      ? line.unitPrice.formatted
                      : '${line.unitPrice.formatted}  ·  -${line.discount.formatted}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          _QtyStepper(line: line),
          SizedBox(
            width: 84,
            child: Text(
              line.amount.formatted,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'discount') {
                final value = await promptAmount(
                  context,
                  title: 'Line discount',
                  initial: line.discount,
                );
                if (value != null) {
                  notifier.setLineDiscount(line.productId, value);
                }
              } else if (v == 'remove') {
                notifier.removeLine(line.productId);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'discount', child: Text('Set discount')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends ConsumerWidget {
  const _QtyStepper({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => notifier.decrement(line.productId),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${line.qty}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => notifier.increment(line.productId),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _PaymentSelector extends ConsumerWidget {
  const _PaymentSelector({required this.selected});

  final PaymentMethod selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: SegmentedButton<PaymentMethod>(
        segments: [
          for (final m in kSelectablePaymentMethods)
            ButtonSegment(value: m, label: Text(m.label)),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (s) {
          final notifier = ref.read(cartProvider.notifier);
          notifier.setPaymentMethod(s.first);
          // Suggest a GST default for the chosen method (UPI/Cash+UPI on;
          // cash follows the "Print GST on cash" setting). The cashier can
          // still flip the GST toggle for any individual sale.
          final shop = ref.read(shopProfileProvider).valueOrNull;
          notifier.setGst(shop?.shouldPrintGst(s.first) ?? false);
        },
      ),
    );
  }
}

/// Per-sale switch marking the bill as a GST tax invoice or a plain bill.
class _GstToggle extends ConsumerWidget {
  const _GstToggle({required this.isGst});

  final bool isGst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProfileProvider).valueOrNull;
    // No GST number configured → nothing to toggle.
    if (shop == null || !shop.hasGst) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SwitchListTile(
        dense: true,
        value: isGst,
        onChanged: (v) => ref.read(cartProvider.notifier).setGst(v),
        title: const Text('GST bill (tax invoice)'),
        subtitle: Text(
          isGst
              ? 'Prints GSTIN · GST- invoice series'
              : 'Plain bill · INV- series',
        ),
      ),
    );
  }
}

/// Cash-received input for a Cash + UPI split. The UPI balance is computed and
/// shown live; the "Pay by UPI" button and the bill use that balance.
class _SplitCashField extends ConsumerStatefulWidget {
  const _SplitCashField({required this.cart});

  final Cart cart;

  @override
  ConsumerState<_SplitCashField> createState() => _SplitCashFieldState();
}

class _SplitCashFieldState extends ConsumerState<_SplitCashField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final cash = widget.cart.cashPaid;
    _controller = TextEditingController(
      text: (cash == null || cash.isZero) ? '' : '${cash.rupeesCeil}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.cart.upiPortion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Cash received',
              prefixText: '₹ ',
              isDense: true,
            ),
            onChanged: (v) => ref
                .read(cartProvider.notifier)
                .setCashPaid(Money.fromRupees(double.tryParse(v) ?? 0)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Balance via UPI: ${balance.formatted}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerField extends ConsumerStatefulWidget {
  const _CustomerField({required this.cart});

  final Cart cart;

  @override
  ConsumerState<_CustomerField> createState() => _CustomerFieldState();
}

class _CustomerFieldState extends ConsumerState<_CustomerField> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasCustomer = widget.cart.customerPhone != null ||
        widget.cart.customerName != null;

    if (!_expanded && !hasCustomer) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Add customer (optional)'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        children: [
          TextField(
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer name',
              isDense: true,
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: (v) => ref.read(cartProvider.notifier).setCustomer(
                  name: v,
                  phone: widget.cart.customerPhone,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              isDense: true,
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            onChanged: (v) => ref.read(cartProvider.notifier).setCustomer(
                  name: widget.cart.customerName,
                  phone: v,
                ),
          ),
        ],
      ),
    );
  }
}

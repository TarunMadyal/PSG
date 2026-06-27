import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/billing_providers.dart';
import '../../application/cart_controller.dart';
import '../../domain/cart.dart';
import 'amount_dialog.dart';
import 'receipt_dialog.dart';

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
        segments: const [
          ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
          ButtonSegment(value: PaymentMethod.upi, label: Text('UPI')),
          ButtonSegment(value: PaymentMethod.card, label: Text('Card')),
          ButtonSegment(value: PaymentMethod.other, label: Text('Other')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (s) =>
            ref.read(cartProvider.notifier).setPaymentMethod(s.first),
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
    if (!_expanded && widget.cart.customerPhone == null) {
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Customer phone',
                isDense: true,
              ),
              onChanged: (v) => ref
                  .read(cartProvider.notifier)
                  .setCustomer(phone: v, name: widget.cart.customerName),
            ),
          ),
        ],
      ),
    );
  }
}

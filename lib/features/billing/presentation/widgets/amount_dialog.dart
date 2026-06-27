import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';

/// Prompts for a rupee amount (e.g. a discount) and returns it as [Money].
Future<Money?> promptAmount(
  BuildContext context, {
  required String title,
  Money initial = Money.zero,
}) {
  final controller = TextEditingController(
    text: initial.isZero ? '' : initial.rupees.toStringAsFixed(2),
  );
  return showDialog<Money>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration:
            const InputDecoration(prefixText: '₹ ', labelText: 'Amount'),
        onSubmitted: (_) => Navigator.pop(
          context,
          Money.fromRupees(double.tryParse(controller.text) ?? 0),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, Money.zero),
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            Money.fromRupees(double.tryParse(controller.text) ?? 0),
          ),
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}

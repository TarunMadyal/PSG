import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/upi.dart';
import '../../../settings/domain/shop_profile.dart';

/// Shows a full-screen-ish dialog with a UPI QR the customer can scan to pay
/// the given [amount]. The exact amount is encoded, so their UPI app pre-fills
/// it — useful for taking payment BEFORE finalising the bill.
Future<void> showUpiQrDialog(
  BuildContext context, {
  required ShopProfile shop,
  required Money amount,
  String? note,
}) {
  final uri = buildUpiUri(
    vpa: shop.upiId!.trim(),
    payeeName: shop.upiPayeeName,
    amount: amount,
    note: note,
  );
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan to Pay',
              style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              amount.formatted,
              style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: QrImageView(
                data: uri,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              shop.upiId!.trim(),
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Google Pay · PhonePe · Paytm · any UPI app',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

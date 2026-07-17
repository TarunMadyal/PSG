import 'money.dart';

/// Builds a UPI "dynamic QR" deep link. When a customer scans the encoded QR
/// with any UPI app (Google Pay, PhonePe, Paytm, bank apps), the payee and the
/// exact amount are pre-filled — they just approve the payment.
///
/// Spec: `upi://pay?pa=<vpa>&pn=<name>&am=<amount>&cu=INR&tn=<note>`
/// - `pa` payee address (VPA / UPI ID), e.g. `8123426350@okbizaxis`
/// - `pn` payee name
/// - `am` amount in rupees with 2 decimals (omitted when zero → open amount)
/// - `cu` currency, always INR
/// - `tn` transaction note (we use the invoice number)
String buildUpiUri({
  required String vpa,
  String? payeeName,
  Money amount = Money.zero,
  String? note,
}) {
  final params = <String, String>{
    'pa': vpa.trim(),
    if (payeeName != null && payeeName.trim().isNotEmpty)
      'pn': payeeName.trim(),
    if (!amount.isZero) 'am': amount.rupees.toStringAsFixed(2),
    'cu': 'INR',
    if (note != null && note.trim().isNotEmpty) 'tn': note.trim(),
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'upi://pay?$query';
}

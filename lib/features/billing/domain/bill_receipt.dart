import '../../../core/enums.dart';
import '../../../core/utils/money.dart';

/// A frozen line on a completed bill (used for confirmation and printing).
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    required this.amount,
  });

  final String name;
  final int qty;
  final Money unitPrice;
  final Money discount;
  final Money amount;
}

/// The result of a completed sale — everything needed to show a confirmation
/// and (in Phase 6) print a receipt.
class BillReceipt {
  const BillReceipt({
    required this.id,
    required this.invoiceNo,
    required this.billedAt,
    required this.cashierName,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.gst,
    required this.grandTotal,
    required this.paymentMethod,
    required this.cashPaid,
    required this.upiPaid,
    this.customerName,
    this.customerPhone,
  });

  final String id;
  final String invoiceNo;
  final DateTime billedAt;
  final String cashierName;
  final List<ReceiptLine> lines;
  final Money subtotal;
  final Money discount;
  final Money gst;
  final Money grandTotal;
  final PaymentMethod paymentMethod;

  /// Amount paid in cash and via UPI. For pure cash/UPI these are the whole
  /// total and zero (or vice-versa); for a split they hold the breakdown.
  final Money cashPaid;
  final Money upiPaid;

  final String? customerName;
  final String? customerPhone;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  /// Whether this bill was paid as a Cash + UPI split (both parts non-zero).
  bool get isSplit => paymentMethod == PaymentMethod.cashPlusUpi;
}

/// Lightweight summary for the recent-transactions list.
class BillSummary {
  const BillSummary({
    required this.id,
    required this.invoiceNo,
    required this.billedAt,
    required this.grandTotal,
    required this.paymentMethod,
    required this.status,
  });

  final String id;
  final String invoiceNo;
  final DateTime billedAt;
  final Money grandTotal;
  final PaymentMethod paymentMethod;
  final BillStatus status;
}

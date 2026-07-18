import '../../../core/enums.dart';
import '../../../core/utils/money.dart';

/// A single line in the in-progress sale.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    this.qty = 1,
    this.discount = Money.zero,
  });

  final String productId;
  final String name;
  final Money unitPrice;
  final int qty;

  /// Per-line discount amount.
  final Money discount;

  /// Price × quantity, before the line discount.
  Money get gross => unitPrice * qty;

  /// Line total after its discount (never negative).
  Money get amount {
    final net = gross - discount;
    return net.isNegative ? Money.zero : net;
  }

  CartLine copyWith({int? qty, Money? discount}) => CartLine(
        productId: productId,
        name: name,
        unitPrice: unitPrice,
        qty: qty ?? this.qty,
        discount: discount ?? this.discount,
      );
}

/// The complete in-progress sale: lines plus bill-level options.
class Cart {
  const Cart({
    this.lines = const [],
    this.billDiscount = Money.zero,
    this.paymentMethod = PaymentMethod.cash,
    this.cashPaid,
    this.customerName,
    this.customerPhone,
  });

  final List<CartLine> lines;
  final Money billDiscount;
  final PaymentMethod paymentMethod;

  /// For a Cash + UPI split: how much the customer pays in cash. The rest is
  /// collected via UPI. Null for pure cash / pure UPI sales.
  final Money? cashPaid;

  final String? customerName;
  final String? customerPhone;

  static const Cart empty = Cart();

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  /// Sum of line grosses (price × qty).
  Money get subtotal => lines.fold(Money.zero, (sum, l) => sum + l.gross);

  /// All per-line discounts combined.
  Money get lineDiscountTotal =>
      lines.fold(Money.zero, (sum, l) => sum + l.discount);

  /// Line discounts + the bill-level discount.
  Money get totalDiscount => lineDiscountTotal + billDiscount;

  /// GST — currently zero; becomes settings-driven in a later phase.
  Money get gst => Money.zero;

  /// Final payable amount (never negative).
  Money get grandTotal {
    final total = subtotal - totalDiscount + gst;
    return total.isNegative ? Money.zero : total;
  }

  /// How much of [grandTotal] is collected in cash, given [paymentMethod].
  Money get cashPortion => switch (paymentMethod) {
        PaymentMethod.upi => Money.zero,
        PaymentMethod.cashPlusUpi => _clampedCash,
        _ => grandTotal, // cash (and legacy card/other)
      };

  /// How much of [grandTotal] is collected via UPI, given [paymentMethod].
  Money get upiPortion => switch (paymentMethod) {
        PaymentMethod.upi => grandTotal,
        PaymentMethod.cashPlusUpi => grandTotal - _clampedCash,
        _ => Money.zero,
      };

  /// Cash entered for a split, clamped to [0, grandTotal].
  Money get _clampedCash {
    final c = cashPaid ?? Money.zero;
    if (c.isNegative) return Money.zero;
    if (c > grandTotal) return grandTotal;
    return c;
  }

  Cart copyWith({
    List<CartLine>? lines,
    Money? billDiscount,
    PaymentMethod? paymentMethod,
    Object? cashPaid = _sentinel,
    Object? customerName = _sentinel,
    Object? customerPhone = _sentinel,
  }) {
    return Cart(
      lines: lines ?? this.lines,
      billDiscount: billDiscount ?? this.billDiscount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashPaid: cashPaid == _sentinel ? this.cashPaid : cashPaid as Money?,
      customerName: customerName == _sentinel
          ? this.customerName
          : customerName as String?,
      customerPhone: customerPhone == _sentinel
          ? this.customerPhone
          : customerPhone as String?,
    );
  }
}

const Object _sentinel = Object();

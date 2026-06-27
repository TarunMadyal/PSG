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
    this.availableStock,
  });

  final String productId;
  final String name;
  final Money unitPrice;
  final int qty;

  /// Per-line discount amount.
  final Money discount;

  /// Stock available when added, used to cap quantity in the UI (nullable when
  /// stock isn't tracked for this line).
  final int? availableStock;

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
        availableStock: availableStock,
      );
}

/// The complete in-progress sale: lines plus bill-level options.
class Cart {
  const Cart({
    this.lines = const [],
    this.billDiscount = Money.zero,
    this.paymentMethod = PaymentMethod.cash,
    this.customerName,
    this.customerPhone,
  });

  final List<CartLine> lines;
  final Money billDiscount;
  final PaymentMethod paymentMethod;
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

  Cart copyWith({
    List<CartLine>? lines,
    Money? billDiscount,
    PaymentMethod? paymentMethod,
    Object? customerName = _sentinel,
    Object? customerPhone = _sentinel,
  }) {
    return Cart(
      lines: lines ?? this.lines,
      billDiscount: billDiscount ?? this.billDiscount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
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

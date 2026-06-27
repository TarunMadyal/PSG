import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../core/utils/money.dart';
import '../../products/domain/product_item.dart';
import '../domain/cart.dart';

/// Holds the in-progress sale. Pure, synchronous state mutations — the cart is
/// rebuilt immutably so the UI updates reactively and totals stay consistent.
final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

class CartController extends Notifier<Cart> {
  @override
  Cart build() => Cart.empty;

  int _indexOf(String productId) =>
      state.lines.indexWhere((l) => l.productId == productId);

  /// Adds a product, or increments it if already in the cart.
  void addProduct(ProductItem product) {
    final i = _indexOf(product.id);
    if (i >= 0) {
      increment(product.id);
      return;
    }
    final line = CartLine(
      productId: product.id,
      name: product.name,
      unitPrice: product.price,
    );
    state = state.copyWith(lines: [...state.lines, line]);
  }

  void increment(String productId) {
    _updateLine(productId, (l) => l.copyWith(qty: l.qty + 1));
  }

  void decrement(String productId) {
    final i = _indexOf(productId);
    if (i < 0) return;
    final line = state.lines[i];
    if (line.qty <= 1) {
      removeLine(productId);
    } else {
      _updateLine(productId, (l) => l.copyWith(qty: l.qty - 1));
    }
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      removeLine(productId);
      return;
    }
    _updateLine(productId, (l) => l.copyWith(qty: qty));
  }

  void setLineDiscount(String productId, Money discount) {
    _updateLine(
      productId,
      (l) => l.copyWith(discount: discount.isNegative ? Money.zero : discount),
    );
  }

  void removeLine(String productId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.productId != productId).toList(),
    );
  }

  void setBillDiscount(Money discount) {
    state = state.copyWith(
      billDiscount: discount.isNegative ? Money.zero : discount,
    );
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setCustomer({String? name, String? phone}) {
    state = state.copyWith(customerName: name, customerPhone: phone);
  }

  void clear() => state = Cart.empty;

  void _updateLine(String productId, CartLine Function(CartLine) transform) {
    final i = _indexOf(productId);
    if (i < 0) return;
    final updated = [...state.lines];
    updated[i] = transform(updated[i]);
    state = state.copyWith(lines: updated);
  }
}

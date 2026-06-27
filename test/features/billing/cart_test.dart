import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/features/billing/application/cart_controller.dart';
import 'package:psg_pos/features/billing/domain/cart.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';

ProductItem product(String id, {double price = 100, int stock = 10}) =>
    ProductItem(
      id: id,
      name: 'P-$id',
      price: Money.fromRupees(price),
      stock: stock,
    );

void main() {
  group('Cart math', () {
    test('line amount = price × qty − discount (clamped at zero)', () {
      const line = CartLine(
        productId: 'a',
        name: 'A',
        unitPrice: Money(10000), // ₹100
        qty: 3,
        discount: Money(5000), // ₹50
      );
      expect(line.gross, const Money(30000));
      expect(line.amount, const Money(25000));

      const overDiscounted = CartLine(
        productId: 'b',
        name: 'B',
        unitPrice: Money(10000),
        discount: Money(20000),
      );
      expect(overDiscounted.amount, Money.zero); // never negative
    });

    test('cart totals aggregate lines, discounts and stay non-negative', () {
      const cart = Cart(
        lines: [
          CartLine(productId: 'a', name: 'A', unitPrice: Money(10000), qty: 2),
          CartLine(
            productId: 'b',
            name: 'B',
            unitPrice: Money(5000),
            qty: 1,
            discount: Money(1000),
          ),
        ],
        billDiscount: Money(2000),
      );

      expect(cart.subtotal, const Money(25000)); // 20000 + 5000
      expect(cart.totalDiscount, const Money(3000)); // 1000 + 2000
      expect(cart.grandTotal, const Money(22000));
      expect(cart.itemCount, 3);
    });
  });

  group('CartController', () {
    late ProviderContainer container;
    CartController controller() => container.read(cartProvider.notifier);
    Cart cart() => container.read(cartProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('adding the same product increments quantity', () {
      controller().addProduct(product('a'));
      controller().addProduct(product('a'));
      expect(cart().lines, hasLength(1));
      expect(cart().lines.single.qty, 2);
    });

    test('quantity is capped at available stock', () {
      controller().addProduct(product('a', stock: 2));
      controller()
        ..increment('a') // 2
        ..increment('a'); // would be 3, capped at 2
      expect(cart().lines.single.qty, 2);
    });

    test('decrementing to zero removes the line', () {
      controller().addProduct(product('a'));
      controller().decrement('a');
      expect(cart().isEmpty, isTrue);
    });

    test('setQty(0) removes; negative discount is clamped to zero', () {
      controller().addProduct(product('a'));
      controller().setLineDiscount('a', const Money(-500));
      expect(cart().lines.single.discount, Money.zero);
      controller().setQty('a', 0);
      expect(cart().isEmpty, isTrue);
    });

    test('payment method, customer and clear', () {
      controller().addProduct(product('a'));
      controller().setPaymentMethod(PaymentMethod.upi);
      controller().setCustomer(phone: '9999900000', name: 'Asha');
      expect(cart().paymentMethod, PaymentMethod.upi);
      expect(cart().customerPhone, '9999900000');

      controller().clear();
      expect(cart().isEmpty, isTrue);
      expect(cart().paymentMethod, PaymentMethod.cash); // reset
    });
  });
}

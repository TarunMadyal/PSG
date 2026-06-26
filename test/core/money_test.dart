import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/utils/money.dart';

void main() {
  group('Money', () {
    test('stores rupees as integer paise', () {
      expect(Money.fromRupees(199.50).paise, 19950);
      expect(Money.fromRupees(0).paise, 0);
      expect(const Money(100).rupees, 1.0);
    });

    test('rounds to nearest paise (no float drift)', () {
      // 0.1 + 0.2 in paise must be exactly 30, not 0.30000000000000004.
      final total = Money.fromRupees(0.1) + Money.fromRupees(0.2);
      expect(total.paise, 30);
    });

    test('addition, subtraction and quantity multiplication', () {
      expect((const Money(1000) + const Money(250)).paise, 1250);
      expect((const Money(1000) - const Money(250)).paise, 750);
      expect((const Money(1000) * 3).paise, 3000);
    });

    test('percentage discount rounds correctly', () {
      // 10% off ₹199.99 -> ₹179.99 (17999 paise).
      expect(const Money(19999).percentOff(10).paise, 17999);
      expect(const Money(10000).percentOff(0).paise, 10000);
      expect(const Money(10000).percentOff(100).paise, 0);
    });

    test('formats in Indian rupee locale', () {
      expect(const Money(129900).formatted, '₹1,299.00');
      expect(const Money(0).formatted, '₹0.00');
    });

    test('zero and sign helpers', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money(-100).isNegative, isTrue);
    });
  });
}

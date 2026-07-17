import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/core/utils/upi.dart';
import 'package:psg_pos/features/settings/domain/shop_profile.dart';

void main() {
  group('ShopProfile GST cash-limit rule', () {
    const shop = ShopProfile(
      shopName: 'PSG',
      gstNumber: '29AEXPJ3122K1Z1',
      gstCashLimit: Money(1000000), // ₹10,000
    );

    test('prints GST number at or below the limit', () {
      expect(shop.shouldPrintGst(Money.fromRupees(5000)), isTrue);
      expect(shop.shouldPrintGst(Money.fromRupees(10000)), isTrue);
    });

    test('hides GST number above the limit', () {
      expect(shop.shouldPrintGst(Money.fromRupees(10000.01)), isFalse);
      expect(shop.shouldPrintGst(Money.fromRupees(25000)), isFalse);
    });

    test('never prints when no GST number is set', () {
      const noGst = ShopProfile(shopName: 'PSG', gstNumber: null);
      expect(noGst.shouldPrintGst(Money.fromRupees(100)), isFalse);
    });
  });

  group('ShopProfile UPI QR rule', () {
    const shop = ShopProfile(shopName: 'PSG', upiId: '812@okbizaxis');

    test('shows QR for a non-zero bill when UPI configured', () {
      expect(shop.shouldShowUpiQr(Money.fromRupees(550)), isTrue);
    });

    test('hides QR for a zero bill', () {
      expect(shop.shouldShowUpiQr(Money.zero), isFalse);
    });

    test('hides QR when disabled', () {
      const off = ShopProfile(
        shopName: 'PSG',
        upiId: '812@okbizaxis',
        printUpiQr: false,
      );
      expect(off.shouldShowUpiQr(Money.fromRupees(550)), isFalse);
    });

    test('payee name falls back to shop name', () {
      expect(shop.upiPayeeName, 'PSG');
      const named = ShopProfile(
        shopName: 'PSG',
        upiId: '812@okbizaxis',
        upiName: 'Padamshree Garments',
      );
      expect(named.upiPayeeName, 'Padamshree Garments');
    });
  });

  group('buildUpiUri', () {
    test('encodes payee, amount and note', () {
      final uri = buildUpiUri(
        vpa: '8123426350@okbizaxis',
        payeeName: 'PSG Garments',
        amount: Money.fromRupees(2050),
        note: 'INV-00005',
      );
      expect(uri, startsWith('upi://pay?'));
      expect(uri, contains('pa=8123426350%40okbizaxis'));
      expect(uri, contains('pn=PSG%20Garments'));
      expect(uri, contains('am=2050.00'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=INV-00005'));
    });

    test('omits amount when zero (open/any-amount QR)', () {
      final uri = buildUpiUri(vpa: 'x@bank');
      expect(uri, isNot(contains('am=')));
    });
  });
}

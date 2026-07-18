import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/core/utils/upi.dart';
import 'package:psg_pos/features/settings/domain/shop_profile.dart';

void main() {
  group('ShopProfile GST rule by payment method', () {
    const cashOff = ShopProfile(shopName: 'PSG', gstNumber: '29AEXPJ3122K1Z1');
    const cashOn = ShopProfile(
      shopName: 'PSG',
      gstNumber: '29AEXPJ3122K1Z1',
      printGstOnCash: true,
    );

    test('UPI and Cash+UPI always print GST', () {
      expect(cashOff.shouldPrintGst(PaymentMethod.upi), isTrue);
      expect(cashOff.shouldPrintGst(PaymentMethod.cashPlusUpi), isTrue);
    });

    test('cash bills hide GST by default, show it when enabled', () {
      expect(cashOff.shouldPrintGst(PaymentMethod.cash), isFalse);
      expect(cashOn.shouldPrintGst(PaymentMethod.cash), isTrue);
    });

    test('never prints GST when no number is set', () {
      const noGst = ShopProfile(shopName: 'PSG', printGstOnCash: true);
      expect(noGst.shouldPrintGst(PaymentMethod.upi), isFalse);
      expect(noGst.shouldPrintGst(PaymentMethod.cash), isFalse);
    });
  });

  group('ShopProfile UPI QR rule by payment method', () {
    const shop = ShopProfile(shopName: 'PSG', upiId: '812@okbizaxis');

    test('shows QR for UPI and Cash+UPI when a UPI amount is due', () {
      expect(shop.shouldShowUpiQr(PaymentMethod.upi, Money.fromRupees(550)), isTrue);
      expect(
        shop.shouldShowUpiQr(PaymentMethod.cashPlusUpi, Money.fromRupees(200)),
        isTrue,
      );
    });

    test('never shows QR for cash', () {
      expect(
        shop.shouldShowUpiQr(PaymentMethod.cash, Money.fromRupees(550)),
        isFalse,
      );
    });

    test('hides QR when the UPI portion is zero', () {
      expect(shop.shouldShowUpiQr(PaymentMethod.cashPlusUpi, Money.zero), isFalse);
    });

    test('hides QR when no UPI id is configured', () {
      const noUpi = ShopProfile(shopName: 'PSG');
      expect(
        noUpi.shouldShowUpiQr(PaymentMethod.upi, Money.fromRupees(550)),
        isFalse,
      );
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

import '../../../core/enums.dart';
import '../../../core/utils/money.dart';

/// Shop profile + receipt + default-printer configuration, shown at the top and
/// bottom of every printed bill and used to reconnect to the saved printer.
class ShopProfile {
  const ShopProfile({
    required this.shopName,
    this.address,
    this.phone,
    this.receiptWidth = 80,
    this.footerText,
    this.printerName,
    this.printerAddress,
    this.gstNumber,
    this.upiId,
    this.upiName,
    this.printGstOnCash = false,
  });

  final String shopName;
  final String? address;
  final String? phone;

  /// Receipt paper width in mm (58 or 80).
  final int receiptWidth;

  /// Printed at the bottom of the bill (e.g. "Thank you! Visit again.").
  final String? footerText;

  /// The saved default Bluetooth printer.
  final String? printerName;
  final String? printerAddress;

  /// GSTIN printed on bills.
  final String? gstNumber;

  /// UPI ID (VPA) used to build the payment QR.
  final String? upiId;

  /// Payee name shown when the QR is scanned (falls back to shop name).
  final String? upiName;

  /// Whether to print the GST number on CASH bills. Off by default. UPI and
  /// Cash+UPI bills always print the GST number and the QR.
  final bool printGstOnCash;

  bool get hasPrinter =>
      printerAddress != null && printerAddress!.trim().isNotEmpty;

  bool get hasGst => gstNumber != null && gstNumber!.trim().isNotEmpty;

  bool get hasUpi => upiId != null && upiId!.trim().isNotEmpty;

  /// The name to show in the customer's UPI app when scanning the QR.
  String get upiPayeeName =>
      (upiName != null && upiName!.trim().isNotEmpty) ? upiName!.trim() : shopName;

  /// Whether to print the GST number for a bill paid with [method].
  /// - UPI / Cash+UPI: always (when a GST number is set).
  /// - Cash: only when the owner enabled [printGstOnCash].
  bool shouldPrintGst(PaymentMethod method) {
    if (!hasGst) return false;
    if (method.involvesUpi) return true;
    return printGstOnCash;
  }

  /// Whether to render the UPI QR for a bill paid with [method]. The QR only
  /// appears when UPI is part of the payment and there is a non-zero UPI amount.
  bool shouldShowUpiQr(PaymentMethod method, Money upiAmount) =>
      hasUpi && method.involvesUpi && !upiAmount.isZero;

  static const ShopProfile defaults = ShopProfile(
    shopName: 'PSG Padmashree Garments',
    footerText: 'Thank you! Visit again.',
    gstNumber: '29AEXPJ3122K1Z1',
    upiId: '8123426350@okbizaxis',
  );

  ShopProfile copyWith({
    String? shopName,
    Object? address = _sentinel,
    Object? phone = _sentinel,
    int? receiptWidth,
    Object? footerText = _sentinel,
    Object? printerName = _sentinel,
    Object? printerAddress = _sentinel,
    Object? gstNumber = _sentinel,
    Object? upiId = _sentinel,
    Object? upiName = _sentinel,
    bool? printGstOnCash,
  }) {
    return ShopProfile(
      shopName: shopName ?? this.shopName,
      address: address == _sentinel ? this.address : address as String?,
      phone: phone == _sentinel ? this.phone : phone as String?,
      receiptWidth: receiptWidth ?? this.receiptWidth,
      footerText:
          footerText == _sentinel ? this.footerText : footerText as String?,
      printerName:
          printerName == _sentinel ? this.printerName : printerName as String?,
      printerAddress: printerAddress == _sentinel
          ? this.printerAddress
          : printerAddress as String?,
      gstNumber: gstNumber == _sentinel ? this.gstNumber : gstNumber as String?,
      upiId: upiId == _sentinel ? this.upiId : upiId as String?,
      upiName: upiName == _sentinel ? this.upiName : upiName as String?,
      printGstOnCash: printGstOnCash ?? this.printGstOnCash,
    );
  }
}

const Object _sentinel = Object();

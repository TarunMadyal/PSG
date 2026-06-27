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

  bool get hasPrinter =>
      printerAddress != null && printerAddress!.trim().isNotEmpty;

  static const ShopProfile defaults = ShopProfile(
    shopName: 'PSG Padmashree Garments',
    footerText: 'Thank you! Visit again.',
  );

  ShopProfile copyWith({
    String? shopName,
    Object? address = _sentinel,
    Object? phone = _sentinel,
    int? receiptWidth,
    Object? footerText = _sentinel,
    Object? printerName = _sentinel,
    Object? printerAddress = _sentinel,
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
    );
  }
}

const Object _sentinel = Object();

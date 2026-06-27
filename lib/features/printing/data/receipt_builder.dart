import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../billing/domain/bill_receipt.dart';
import '../../settings/domain/shop_profile.dart';

/// Turns a completed [BillReceipt] into ESC/POS bytes for a 58/80mm thermal
/// printer, laid out as: shop name (logo) → address → bill details → totals →
/// "thank you" footer.
///
/// Note: the rupee sign (₹) is intentionally avoided in printed output — most
/// thermal printers use code page CP437, which can't render it. Amounts print
/// as plain numbers with an "Rs" label where helpful.
class ReceiptBuilder {
  const ReceiptBuilder();

  Future<List<int>> build(BillReceipt receipt, ShopProfile shop) async {
    final profile = await CapabilityProfile.load();
    final paper = shop.receiptWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(g.reset());

    // ── Header / logo ──────────────────────────────────────────────
    bytes.addAll(
      g.text(
        shop.shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    if (_has(shop.address)) {
      for (final line in shop.address!.trim().split('\n')) {
        bytes.addAll(g.text(line.trim(), styles: _center));
      }
    }
    if (_has(shop.phone)) {
      bytes.addAll(g.text('Ph: ${shop.phone!.trim()}', styles: _center));
    }

    bytes.addAll(g.hr());

    // ── Bill meta ──────────────────────────────────────────────────
    bytes.addAll(_kv(g, 'Invoice', receipt.invoiceNo));
    bytes.addAll(_kv(g, 'Date', Formatters.dateTime(receipt.billedAt)));
    bytes.addAll(_kv(g, 'Cashier', receipt.cashierName));
    if (_has(receipt.customerPhone)) {
      bytes.addAll(_kv(g, 'Customer', receipt.customerPhone!));
    }

    bytes.addAll(g.hr());

    // ── Items table ────────────────────────────────────────────────
    bytes.addAll(
      g.row([
        PosColumn(text: 'Item', width: 6, styles: _boldLeft),
        PosColumn(text: 'Qty', width: 2, styles: _boldCenter),
        PosColumn(text: 'Rate', width: 2, styles: _boldRight),
        PosColumn(text: 'Amt', width: 2, styles: _boldRight),
      ]),
    );
    for (final l in receipt.lines) {
      bytes.addAll(
        g.row([
          PosColumn(text: l.name, width: 6),
          PosColumn(text: '${l.qty}', width: 2, styles: _center),
          PosColumn(text: l.unitPrice.formattedPlain, width: 2, styles: _right),
          PosColumn(text: l.amount.formattedPlain, width: 2, styles: _right),
        ]),
      );
      if (!l.discount.isZero) {
        bytes.addAll(
          g.row([
            PosColumn(text: '  less discount', width: 9),
            PosColumn(
              text: '-${l.discount.formattedPlain}',
              width: 3,
              styles: _right,
            ),
          ]),
        );
      }
    }

    bytes.addAll(g.hr());

    // ── Totals ─────────────────────────────────────────────────────
    bytes.addAll(_total(g, 'Subtotal', receipt.subtotal.formattedPlain));
    if (!receipt.discount.isZero) {
      bytes.addAll(_total(g, 'Discount', '-${receipt.discount.formattedPlain}'));
    }
    bytes.addAll(
      _total(g, 'TOTAL  Rs', receipt.grandTotal.formattedPlain, big: true),
    );
    bytes.addAll(_kv(g, 'Paid via', _payLabel(receipt)));

    bytes.addAll(g.hr());

    // ── Footer ─────────────────────────────────────────────────────
    if (_has(shop.footerText)) {
      bytes.addAll(g.text(shop.footerText!.trim(), styles: _center));
    }

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  /// A short standalone receipt used to confirm the printer works.
  Future<List<int>> buildTestPage(ShopProfile shop) async {
    final profile = await CapabilityProfile.load();
    final paper = shop.receiptWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(g.reset());
    bytes.addAll(
      g.text(
        shop.shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(g.hr());
    bytes.addAll(g.text('Printer test successful', styles: _center));
    bytes.addAll(g.text('${shop.receiptWidth}mm paper', styles: _center));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  // ── helpers ──────────────────────────────────────────────────────
  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  static const PosStyles _center = PosStyles(align: PosAlign.center);
  static const PosStyles _right = PosStyles(align: PosAlign.right);
  static const PosStyles _boldLeft = PosStyles(bold: true);
  static const PosStyles _boldCenter =
      PosStyles(bold: true, align: PosAlign.center);
  static const PosStyles _boldRight =
      PosStyles(bold: true, align: PosAlign.right);

  List<int> _kv(Generator g, String key, String value) => g.row([
        PosColumn(text: key, width: 4),
        PosColumn(text: value, width: 8, styles: _right),
      ]);

  List<int> _total(Generator g, String label, String value, {bool big = false}) {
    final style = big
        ? const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )
        : _right;
    return g.row([
      PosColumn(
        text: label,
        width: 6,
        styles: big ? _boldLeft : const PosStyles(),
      ),
      PosColumn(text: value, width: 6, styles: style),
    ]);
  }

  String _payLabel(BillReceipt r) {
    final m = r.paymentMethod.name;
    return m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
  }
}

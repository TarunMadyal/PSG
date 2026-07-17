import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/upi.dart';
import '../../billing/domain/bill_receipt.dart';
import '../../reports/domain/report_models.dart';
import '../../reports/domain/report_range.dart';
import '../../settings/domain/shop_profile.dart';
import 'logo_raster.dart';

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
    bytes.addAll(await _header(g, shop, paper));
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
    bytes.addAll(_kv(g, 'Date', Formatters.receiptDateTime(receipt.billedAt)));
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

    // ── GST number (hidden once the bill exceeds the cash limit) ──────
    if (shop.shouldPrintGst(receipt.grandTotal)) {
      bytes.addAll(g.text('GSTIN: ${shop.gstNumber!.trim()}', styles: _boldCenter));
      bytes.addAll(g.hr());
    }

    // ── UPI payment QR (auto-fills the amount when scanned) ───────────
    if (shop.shouldShowUpiQr(receipt.grandTotal)) {
      bytes.addAll(g.text('Scan & Pay with any UPI app', styles: _boldCenter));
      final uri = buildUpiUri(
        vpa: shop.upiId!.trim(),
        payeeName: shop.upiPayeeName,
        amount: receipt.grandTotal,
        note: receipt.invoiceNo,
      );
      bytes.addAll(g.qrcode(uri, size: QRSize.size6));
      bytes.addAll(g.text(shop.upiId!.trim(), styles: _center));
      bytes.addAll(g.hr());
    }

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

  /// A sales report for the chosen period (owner). Prints the shop logo, the
  /// period, the headline figures and the best-selling items.
  Future<List<int>> buildReport(
    ReportDashboard data,
    ReportRange range,
    ShopProfile shop,
    DateTime generatedAt,
  ) async {
    final profile = await CapabilityProfile.load();
    final paper = shop.receiptWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(g.reset());
    bytes.addAll(await _header(g, shop, paper));
    bytes.addAll(g.hr());

    bytes.addAll(
      g.text(
        '${range.label} sales report',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      g.text(
        'Generated ${Formatters.dateTime(generatedAt)}',
        styles: _center,
      ),
    );
    bytes.addAll(g.hr());

    final s = data.sales;
    bytes.addAll(_kv(g, 'Total sales', s.totalSales.formattedPlain));
    bytes.addAll(_kv(g, 'Bills', '${s.billCount}'));
    bytes.addAll(_kv(g, 'Items sold', '${s.itemsSold}'));
    bytes.addAll(_kv(g, 'Avg. bill', s.averageBill.formattedPlain));
    bytes.addAll(_kv(g, 'Discounts', s.totalDiscount.formattedPlain));

    if (data.bestSellers.isNotEmpty) {
      bytes.addAll(g.hr());
      bytes.addAll(g.text('Best sellers', styles: _boldLeft));
      bytes.addAll(
        g.row([
          PosColumn(text: 'Item', width: 7, styles: _boldLeft),
          PosColumn(text: 'Qty', width: 2, styles: _boldCenter),
          PosColumn(text: 'Amt', width: 3, styles: _boldRight),
        ]),
      );
      for (final b in data.bestSellers) {
        bytes.addAll(
          g.row([
            PosColumn(text: b.name, width: 7),
            PosColumn(text: '${b.qtySold}', width: 2, styles: _center),
            PosColumn(text: b.revenue.formattedPlain, width: 3, styles: _right),
          ]),
        );
      }
    }

    bytes.addAll(g.hr());
    bytes.addAll(
      _total(g, 'TOTAL  Rs', s.totalSales.formattedPlain, big: true),
    );
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  // ── helpers ──────────────────────────────────────────────────────
  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  /// Prints the logo raster at the top; falls back to the shop name as bold text
  /// if the logo asset can't be loaded.
  Future<List<int>> _header(
    Generator g,
    ShopProfile shop,
    PaperSize paper,
  ) async {
    final logo = await const LogoRaster()
        .load(targetWidth: paper == PaperSize.mm58 ? 360 : 520);
    if (logo != null) {
      return g.imageRaster(logo, align: PosAlign.center);
    }
    return g.text(
      shop.shopName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
  }

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
    // The big total uses double HEIGHT only (not double width) so a large
    // amount like "1,88,888.00" can never overflow the paper and wrap onto the
    // next line — the earlier bug where "2,050.00" split into "2,050.0" + "0".
    final style = big
        ? const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
          )
        : _right;
    return g.row([
      PosColumn(
        text: label,
        width: 5,
        styles: big
            ? const PosStyles(bold: true, height: PosTextSize.size2)
            : const PosStyles(),
      ),
      PosColumn(text: value, width: 7, styles: style),
    ]);
  }

  String _payLabel(BillReceipt r) {
    final m = r.paymentMethod.name;
    return m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
  }
}

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/app_database.dart';

/// Builds a CSV of every completed sale — a records backup that can be shared
/// off the device (Drive / email) and opened in Excel by the shop or its CA.
Future<String> buildSalesCsv(AppDatabase db) async {
  final bills = await (db.select(db.bills)
        ..where((t) => t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.billedAt)]))
      .get();
  final users = {for (final u in await db.select(db.users).get()) u.id: u.name};
  final customers = {
    for (final c in await db.select(db.customers).get()) c.id: c,
  };

  final rows = <String>[
    [
      'Invoice', 'Date', 'Cashier', 'Customer', 'Phone', 'Payment',
      'Cash', 'UPI', 'Subtotal', 'Discount', 'Total',
    ].map(_csv).join(','),
  ];

  for (final b in bills) {
    final cust = b.customerId != null ? customers[b.customerId] : null;
    final cash = b.cashPaidPaise ??
        (b.paymentMethod == PaymentMethod.upi ? 0 : b.grandTotalPaise);
    final upi = b.upiPaidPaise ??
        (b.paymentMethod == PaymentMethod.upi ? b.grandTotalPaise : 0);
    final fields = <String>[
      b.invoiceNo,
      Formatters.dateTime(b.billedAt),
      users[b.cashierId] ?? '',
      cust?.name ?? '',
      cust?.phone ?? '',
      b.paymentMethod.label,
      _rs(cash),
      _rs(upi),
      _rs(b.subtotalPaise),
      _rs(b.discountPaise),
      _rs(b.grandTotalPaise),
    ];
    rows.add(fields.map(_csv).join(','));
  }

  return rows.join('\n');
}

String _rs(int paise) => (paise / 100).toStringAsFixed(2);

String _csv(String v) => '"${v.replaceAll('"', '""')}"';

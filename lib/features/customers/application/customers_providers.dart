import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/app_database.dart';
import '../../billing/domain/bill_receipt.dart';

/// Live list of saved customers (captured during billing, or added manually).
final customersProvider = StreamProvider<List<Customer>>(
  (ref) => ref.watch(databaseProvider).customersDao.watchAll(),
);

/// Current search text on the Customers screen.
final customerSearchProvider = StateProvider<String>((ref) => '');

/// Customers filtered by the search text (matches name or phone).
final filteredCustomersProvider = Provider<List<Customer>>((ref) {
  final all = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
  final q = ref.watch(customerSearchProvider).trim().toLowerCase();
  if (q.isEmpty) return all;
  return all.where((c) {
    return (c.name?.toLowerCase().contains(q) ?? false) ||
        (c.phone?.toLowerCase().contains(q) ?? false);
  }).toList();
});

/// A customer's bills (newest first) for the history screen.
final customerBillsProvider =
    StreamProvider.family<List<BillSummary>, String>((ref, customerId) {
  final db = ref.watch(databaseProvider);
  return db.billsDao.watchForCustomer(customerId).map(
        (rows) => rows
            .map(
              (b) => BillSummary(
                id: b.id,
                invoiceNo: b.invoiceNo,
                billedAt: b.billedAt,
                grandTotal: Money(b.grandTotalPaise),
                paymentMethod: b.paymentMethod,
                status: b.status,
              ),
            )
            .toList(),
      );
});

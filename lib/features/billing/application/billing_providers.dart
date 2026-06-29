import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/bill_repository_impl.dart';
import '../domain/bill_receipt.dart';
import '../domain/bill_repository.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BillRepositoryImpl(
    db: db,
    billsDao: db.billsDao,
    customersDao: db.customersDao,
    usersDao: db.usersDao,
  );
});

/// Live recent transactions, for the billing screen and reports.
final recentBillsProvider = StreamProvider<List<BillSummary>>(
  (ref) => ref.watch(billRepositoryProvider).watchRecent(),
);

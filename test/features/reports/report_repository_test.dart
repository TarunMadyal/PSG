import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:psg_pos/features/billing/data/bill_repository_impl.dart';
import 'package:psg_pos/features/billing/domain/cart.dart';
import 'package:psg_pos/features/products/data/product_repository_impl.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';
import 'package:psg_pos/features/reports/data/report_repository_impl.dart';
import 'package:psg_pos/features/reports/domain/report_range.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl products;
  late BillRepositoryImpl bills;
  late ReportRepositoryImpl reports;
  late String cashierId;

  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    products = ProductRepositoryImpl(productsDao: db.productsDao);
    bills = BillRepositoryImpl(
      db: db,
      billsDao: db.billsDao,
      customersDao: db.customersDao,
      usersDao: db.usersDao,
    );
    reports = ReportRepositoryImpl(db.reportsDao);

    final cashier = await db.usersDao.save(
      UsersCompanion.insert(name: 'Asha', role: UserRole.owner),
    );
    cashierId = cashier.id;
  });

  tearDown(() async => db.close());

  Future<ProductItem> addProduct(String name, double price) async {
    await products.save(
      ProductDraft(name: name, price: Money.fromRupees(price)),
    );
    final catalog = await products.watchCatalog().first;
    return catalog.firstWhere((p) => p.name == name);
  }

  CartLine lineFor(ProductItem p, int qty) => CartLine(
        productId: p.id,
        name: p.name,
        unitPrice: p.price,
        qty: qty,
      );

  test('sales summary reflects completed bills for today', () async {
    final a = await addProduct('Shirt', 100);
    final b = await addProduct('Cap', 50);

    final result = await bills.checkout(
      cart: Cart(lines: [lineFor(a, 2), lineFor(b, 1)]),
      cashierId: cashierId,
      cashierName: 'Asha',
    );
    expect(result.isSuccess, isTrue);

    final summary = await reports.salesSummary(ReportRange.today);
    expect(summary.totalSales, Money.fromRupees(250)); // 2*100 + 1*50
    expect(summary.billCount, 1);
    expect(summary.itemsSold, 3);
    expect(summary.averageBill, Money.fromRupees(250));
  });

  test('best sellers are ranked by quantity sold', () async {
    final a = await addProduct('Shirt', 100);
    final b = await addProduct('Cap', 50);

    await bills.checkout(
      cart: Cart(lines: [lineFor(a, 5), lineFor(b, 2)]),
      cashierId: cashierId,
      cashierName: 'Asha',
    );

    final best = await reports.bestSellers(ReportRange.today);
    expect(best.first.name, 'Shirt');
    expect(best.first.qtySold, 5);
    expect(best.last.name, 'Cap');
  });

  test('dashboard composes sales and best sellers for the range', () async {
    final a = await addProduct('Shirt', 100);
    await bills.checkout(
      cart: Cart(lines: [lineFor(a, 1)]),
      cashierId: cashierId,
      cashierName: 'Asha',
    );

    final dash = await reports.dashboard(ReportRange.today);
    expect(dash.sales.billCount, 1);
    expect(dash.bestSellers, isNotEmpty);
  });
}

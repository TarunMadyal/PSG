import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:psg_pos/features/billing/data/bill_repository_impl.dart';
import 'package:psg_pos/features/billing/domain/bill_repository.dart';
import 'package:psg_pos/features/billing/domain/cart.dart';
import 'package:psg_pos/features/products/data/product_repository_impl.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';

void main() {
  late AppDatabase db;
  late BillRepository bills;
  late ProductRepositoryImpl products;
  late String cashierId;

  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    bills = BillRepositoryImpl(
      db: db,
      billsDao: db.billsDao,
      customersDao: db.customersDao,
    );
    products = ProductRepositoryImpl(productsDao: db.productsDao);

    // A cashier is required (bills.cashier_id FK).
    final user = await db.usersDao.save(
      UsersCompanion.insert(name: 'Asha', role: UserRole.owner),
    );
    cashierId = user.id;
  });

  tearDown(() async => db.close());

  Future<ProductItem> seed(String name, double price) async {
    await products.save(
      ProductDraft(name: name, price: Money.fromRupees(price)),
    );
    return (await products.watchCatalog().first)
        .firstWhere((p) => p.name == name);
  }

  Cart cartOf(List<CartLine> lines, {Money billDiscount = Money.zero}) =>
      Cart(lines: lines, billDiscount: billDiscount);

  Future<void> checkout(Cart cart) async {
    final result =
        await bills.checkout(cart: cart, cashierId: cashierId, cashierName: 'Asha');
    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
  }

  test('checkout creates a bill and its items', () async {
    final shirt = await seed('Shirt', 100);

    await checkout(
      cartOf([
        CartLine(
          productId: shirt.id,
          name: shirt.name,
          unitPrice: shirt.price,
          qty: 2,
        ),
      ]),
    );

    final billRows = await db.select(db.bills).get();
    expect(billRows, hasLength(1));
    expect(billRows.single.invoiceNo, 'INV-00001');
    expect(billRows.single.grandTotalPaise, 20000); // ₹200

    final items = await db.billsDao.itemsFor(billRows.single.id);
    expect(items, hasLength(1));
    expect(items.single.qty, 2);
  });

  test('totals apply per-line and bill discounts', () async {
    final a = await seed('A', 100);
    final b = await seed('B', 50);

    await checkout(
      cartOf(
        [
          CartLine(
            productId: a.id,
            name: a.name,
            unitPrice: a.price,
            qty: 2,
            discount: Money.fromRupees(10),
          ),
          CartLine(productId: b.id, name: b.name, unitPrice: b.price),
        ],
        billDiscount: Money.fromRupees(5),
      ),
    );

    final bill = (await db.select(db.bills).get()).single;
    // subtotal 200 + 50 = 250; discount 10 + 5 = 15; total 235
    expect(bill.subtotalPaise, 25000);
    expect(bill.discountPaise, 1500);
    expect(bill.grandTotalPaise, 23500);
  });

  test('invoice numbers increment per sale', () async {
    final p = await seed('P', 10);
    final line = CartLine(productId: p.id, name: p.name, unitPrice: p.price);

    await checkout(cartOf([line]));
    await checkout(cartOf([line]));

    final invoices =
        (await db.select(db.bills).get()).map((b) => b.invoiceNo).toSet();
    expect(invoices, {'INV-00001', 'INV-00002'});
  });

  test('an empty cart is rejected', () async {
    final result = await bills.checkout(
      cart: Cart.empty,
      cashierId: cashierId,
      cashierName: 'Asha',
    );
    expect(result.isFailure, isTrue);
    expect(await db.select(db.bills).get(), isEmpty);
  });

  test('a phone number creates and links a customer', () async {
    final p = await seed('P', 10);
    await checkout(
      Cart(
        lines: [CartLine(productId: p.id, name: p.name, unitPrice: p.price)],
        customerPhone: '9000090000',
        customerName: 'Ravi',
      ),
    );

    final customers = await db.select(db.customers).get();
    expect(customers, hasLength(1));
    expect(customers.single.phone, '9000090000');

    final bill = (await db.select(db.bills).get()).single;
    expect(bill.customerId, customers.single.id);
  });

  test('watchRecent surfaces completed bills', () async {
    final p = await seed('P', 10);
    await checkout(
      cartOf([CartLine(productId: p.id, name: p.name, unitPrice: p.price)]),
    );
    final recent = await bills.watchRecent().first;
    expect(recent, hasLength(1));
    expect(recent.single.grandTotal, Money.fromRupees(10));
  });
}

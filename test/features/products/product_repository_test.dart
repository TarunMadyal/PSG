import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:psg_pos/features/products/data/product_repository_impl.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';
import 'package:psg_pos/features/products/domain/product_repository.dart';

void main() {
  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    repo = ProductRepositoryImpl(
      db: db,
      productsDao: db.productsDao,
      inventoryDao: db.inventoryDao,
    );
  });

  tearDown(() async => db.close());

  ProductDraft draft({
    String name = 'Cotton Shirt',
    double price = 1299,
    int stock = 20,
  }) {
    return ProductDraft(
      name: name,
      price: Money.fromRupees(price),
      stock: stock,
      brand: 'PSG',
      size: 'M',
      sku: 'SH-1',
    );
  }

  test('save creates a product with stock visible in the catalog', () async {
    final result = await repo.save(draft());
    expect(result.isSuccess, isTrue);

    final catalog = await repo.watchCatalog().first;
    expect(catalog, hasLength(1));
    expect(catalog.single.name, 'Cotton Shirt');
    expect(catalog.single.price, Money.fromRupees(1299));
    expect(catalog.single.stock, 20);
    expect(catalog.single.attributesLabel, 'PSG · M');
  });

  test('save rejects an empty name', () async {
    final result = await repo.save(draft(name: '   '));
    expect(result.isFailure, isTrue);
    expect(await repo.watchCatalog().first, isEmpty);
  });

  test('editing a product adjusts its stock via the ledger', () async {
    await repo.save(draft(stock: 20));
    final id = (await repo.watchCatalog().first).single.id;

    await repo.save(draft(stock: 12), id: id);

    final catalog = await repo.watchCatalog().first;
    expect(catalog, hasLength(1)); // not duplicated
    expect(catalog.single.stock, 12);

    final moves = await db.select(db.inventoryMovements).get();
    expect(moves, hasLength(2)); // initial + adjustment
  });

  test('low-stock flag reflects reorder level', () async {
    await repo.save(
      ProductDraft(
        name: 'Socks',
        price: Money.fromRupees(99),
        stock: 3,
        reorderLevel: 5,
      ),
    );
    final item = (await repo.watchCatalog().first).single;
    expect(item.isLowStock, isTrue);
  });

  test('delete removes the product from the catalog', () async {
    await repo.save(draft());
    final id = (await repo.watchCatalog().first).single.id;

    final result = await repo.delete(id);
    expect(result.isSuccess, isTrue);
    expect(await repo.watchCatalog().first, isEmpty);
  });

  test('search finds products by name and sku', () async {
    await repo.save(draft(name: 'Blue Jeans'));
    expect(await repo.search('jeans'), hasLength(1));
    expect(await repo.search('SH-1'), hasLength(1));
    expect(await repo.search('zzz'), isEmpty);
  });
}

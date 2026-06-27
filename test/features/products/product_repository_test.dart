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
    repo = ProductRepositoryImpl(productsDao: db.productsDao);
  });

  tearDown(() async => db.close());

  ProductDraft draft({
    String name = 'Cotton Shirt',
    double price = 1299,
  }) {
    return ProductDraft(
      name: name,
      price: Money.fromRupees(price),
      brand: 'PSG',
      size: 'M',
    );
  }

  test('save creates a product visible in the catalog', () async {
    final result = await repo.save(draft());
    expect(result.isSuccess, isTrue);

    final catalog = await repo.watchCatalog().first;
    expect(catalog, hasLength(1));
    expect(catalog.single.name, 'Cotton Shirt');
    expect(catalog.single.price, Money.fromRupees(1299));
    expect(catalog.single.attributesLabel, 'PSG · M');
  });

  test('save rejects an empty name', () async {
    final result = await repo.save(draft(name: '   '));
    expect(result.isFailure, isTrue);
    expect(await repo.watchCatalog().first, isEmpty);
  });

  test('editing a product updates it without duplicating', () async {
    await repo.save(draft(price: 1299));
    final id = (await repo.watchCatalog().first).single.id;

    await repo.save(draft(price: 999), id: id);

    final catalog = await repo.watchCatalog().first;
    expect(catalog, hasLength(1));
    expect(catalog.single.price, Money.fromRupees(999));
  });

  test('delete removes the product from the catalog', () async {
    await repo.save(draft());
    final id = (await repo.watchCatalog().first).single.id;

    final result = await repo.delete(id);
    expect(result.isSuccess, isTrue);
    expect(await repo.watchCatalog().first, isEmpty);
  });

  test('search finds products by name and brand', () async {
    await repo.save(draft(name: 'Blue Jeans'));
    expect(await repo.search('jeans'), hasLength(1));
    expect(await repo.search('psg'), hasLength(1));
    expect(await repo.search('zzz'), isEmpty);
  });
}

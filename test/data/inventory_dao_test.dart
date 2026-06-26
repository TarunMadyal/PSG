import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/data/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
  });

  tearDown(() async => db.close());

  Future<String> seedProduct() async {
    final p = await db.productsDao.save(
      ProductsCompanion.insert(name: 'Shirt', pricePaise: const Value(10000)),
    );
    return p.id;
  }

  Future<int> movementCount(String productId) async {
    final rows = await (db.select(db.inventoryMovements)
          ..where((t) => t.productId.equals(productId)))
        .get();
    return rows.length;
  }

  test('setStock creates inventory and an initial restock movement', () async {
    final id = await seedProduct();
    await db.inventoryDao.setStock(productId: id, targetQty: 25, reorderLevel: 5);

    expect(await db.inventoryDao.qtyFor(id), 25);
    final moves = await (db.select(db.inventoryMovements)
          ..where((t) => t.productId.equals(id)))
        .get();
    expect(moves, hasLength(1));
    expect(moves.single.reason, MovementReason.restock);
    expect(moves.single.changeQty, 25);
  });

  test('setStock to a new target records the difference as an adjustment',
      () async {
    final id = await seedProduct();
    await db.inventoryDao.setStock(productId: id, targetQty: 25);
    await db.inventoryDao.setStock(productId: id, targetQty: 18);

    expect(await db.inventoryDao.qtyFor(id), 18);
    final moves = await (db.select(db.inventoryMovements)
          ..where((t) => t.productId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    expect(moves, hasLength(2));
    expect(moves.last.reason, MovementReason.adjust);
    expect(moves.last.changeQty, -7); // 18 - 25
  });

  test('adjust applies a relative change and records a sale movement',
      () async {
    final id = await seedProduct();
    await db.inventoryDao.setStock(productId: id, targetQty: 10);

    await db.inventoryDao.adjust(
      productId: id,
      changeQty: -3,
      reason: MovementReason.sale,
      refBillId: 'bill-1',
    );

    expect(await db.inventoryDao.qtyFor(id), 7);
    expect(await movementCount(id), 2);
  });

  test('setStock with no change adds no movement', () async {
    final id = await seedProduct();
    await db.inventoryDao.setStock(productId: id, targetQty: 10);
    await db.inventoryDao.setStock(productId: id, targetQty: 10);
    expect(await movementCount(id), 1); // only the initial one
  });
}

// Hide Drift's query helpers that clash with flutter_test matchers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/data/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory database — no files touch disk, fresh per test. FK enforcement
    // is enabled on the raw connection to match production behaviour.
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  ProductsCompanion sampleProduct({String? id, String name = 'Cotton Shirt'}) {
    return ProductsCompanion.insert(
      id: id == null ? const Value.absent() : Value(id),
      name: name,
      pricePaise: const Value(129900), // ₹1,299.00
      brand: const Value('PSG'),
    );
  }

  group('ProductsDao', () {
    test('save inserts a product and enqueues an outbox entry', () async {
      await db.productsDao.save(sampleProduct());

      final all = await db.productsDao.getAll();
      expect(all, hasLength(1));
      expect(all.single.name, 'Cotton Shirt');
      expect(all.single.pricePaise, 129900);
      expect(all.single.version, 1);

      // The offline-first write pattern enqueued a pending sync change.
      final pending = await db.outboxDao.pending();
      expect(pending, hasLength(1));
      expect(pending.single.op, OutboxOp.upsert);
      expect(pending.single.entityTable, 'products');
      expect(pending.single.payload, isNotNull);
    });

    test('save updates an existing product and bumps version', () async {
      const id = 'fixed-id-1';
      await db.productsDao.save(sampleProduct(id: id));

      await db.productsDao.save(
        sampleProduct(id: id).copyWith(pricePaise: const Value(99900)),
      );

      final product = await db.productsDao.getById(id);
      expect(product, isNotNull);
      expect(product!.pricePaise, 99900);
      expect(product.version, 2); // bumped on update
      expect(await db.productsDao.getAll(), hasLength(1)); // not duplicated
    });

    test('search matches name and brand (case-insensitive)', () async {
      await db.productsDao.save(sampleProduct(name: 'Blue Denim Jeans'));
      await db.productsDao.save(
        ProductsCompanion.insert(name: 'Red Saree', pricePaise: const Value(50000)),
      );

      expect(await db.productsDao.search('denim'), hasLength(1));
      expect(await db.productsDao.search('psg'), hasLength(1)); // brand match
      expect(await db.productsDao.search('saree'), hasLength(1));
      expect(await db.productsDao.search('nonexistent'), isEmpty);
    });

    test('softDelete hides the product but keeps it recoverable', () async {
      const id = 'fixed-id-2';
      await db.productsDao.save(sampleProduct(id: id));

      await db.productsDao.softDelete(id);

      expect(await db.productsDao.getAll(), isEmpty);
      expect(await db.productsDao.getAll(includeDeleted: true), hasLength(1));

      final row = await db.productsDao.getById(id);
      expect(row!.isDeleted, isTrue);

      // A delete change is queued for sync.
      final pending = await db.outboxDao.pending();
      expect(pending.where((e) => e.op == OutboxOp.delete), hasLength(1));
    });

    test('watchActive emits only non-deleted, active products', () async {
      const id = 'fixed-id-3';
      await db.productsDao.save(sampleProduct(id: id));

      final first = await db.productsDao.watchActive().first;
      expect(first, hasLength(1));

      await db.productsDao.softDelete(id);
      final afterDelete = await db.productsDao.watchActive().first;
      expect(afterDelete, isEmpty);
    });
  });

  group('Schema', () {
    test('enforces foreign keys (a bill item needs a real bill)', () async {
      // PRAGMA foreign_keys is enabled on the raw connection.
      await expectLater(
        db.into(db.billItems).insert(
              BillItemsCompanion.insert(
                billId: 'ghost-bill',
                productId: 'ghost-product',
                nameSnapshot: 'X',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('OutboxDao', () {
    test('countPending and markDone work', () async {
      await db.outboxDao.enqueue(
        tableName: 'products',
        rowId: 'r1',
        op: OutboxOp.upsert,
        payload: {'name': 'x'},
      );
      expect(await db.outboxDao.countPending(), 1);

      final pending = await db.outboxDao.pending();
      await db.outboxDao.markDone(pending.single.id);
      expect(await db.outboxDao.countPending(), 0);
    });
  });
}

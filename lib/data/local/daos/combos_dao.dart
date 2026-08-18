import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'combos_dao.g.dart';

@DriftAccessor(tables: [ComboShirts, ComboPants])
class CombosDao extends DatabaseAccessor<AppDatabase> with _$CombosDaoMixin {
  CombosDao(super.db);

  Stream<List<ComboShirt>> watchShirts() => (select(comboShirts)
        ..where((t) => t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  Stream<List<ComboPant>> watchPants() => (select(comboPants)
        ..where((t) => t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  Future<void> updateShirtPrice(String id, int pricePaise) =>
      (update(comboShirts)..where((t) => t.id.equals(id)))
          .write(ComboShirtsCompanion(pricePaise: Value(pricePaise)));

  Future<void> updatePantPrice(String id, int pricePaise) =>
      (update(comboPants)..where((t) => t.id.equals(id)))
          .write(ComboPantsCompanion(pricePaise: Value(pricePaise)));

  Future<void> addShirt(String name, int pricePaise) async {
    final last = await (select(comboShirts)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    final maxOrder = last?.sortOrder ?? 0;
    await into(comboShirts).insert(
      ComboShirtsCompanion.insert(
        name: name.trim(),
        pricePaise: Value(pricePaise),
        sortOrder: Value(maxOrder + 1),
      ),
    );
  }

  Future<void> addPant(String name, int pricePaise) async {
    final last = await (select(comboPants)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    final maxOrder = last?.sortOrder ?? 0;
    await into(comboPants).insert(
      ComboPantsCompanion.insert(
        name: name.trim(),
        pricePaise: Value(pricePaise),
        sortOrder: Value(maxOrder + 1),
      ),
    );
  }

  Future<int> totalShirts() =>
      comboShirts.count().getSingle();

  Future<void> seedDefaults() async {
    const shirts = [
      ('1000/5 Shirt', 20000, 1),
      ('900/3 Formal Shirt', 30000, 2),
      ('800/3 Shining Shirt', 25000, 3),
      ('800/3 Lenin Shirt', 25000, 4),
      ('Baggy Shirt', 35000, 5),
    ];
    const pants = [
      ('1000/3 Formal Pant', 35000, 1),
      ('1100/3 Lenin Formal Pant', 40000, 2),
      ('900/2 Jeans', 50000, 3),
      ('1000/2 Jeans', 55000, 4),
      ('900/2 Jeans (2)', 45000, 5),
    ];

    for (final (name, price, sort) in shirts) {
      await into(comboShirts).insert(
        ComboShirtsCompanion.insert(
          name: name,
          pricePaise: Value(price),
          sortOrder: Value(sort),
        ),
      );
    }
    for (final (name, price, sort) in pants) {
      await into(comboPants).insert(
        ComboPantsCompanion.insert(
          name: name,
          pricePaise: Value(price),
          sortOrder: Value(sort),
        ),
      );
    }
  }
}

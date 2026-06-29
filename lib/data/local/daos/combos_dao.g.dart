// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'combos_dao.dart';

// ignore_for_file: type=lint
mixin _$CombosDaoMixin on DatabaseAccessor<AppDatabase> {
  $ComboShirtsTable get comboShirts => attachedDatabase.comboShirts;
  $ComboPantsTable get comboPants => attachedDatabase.comboPants;
  CombosDaoManager get managers => CombosDaoManager(this);
}

class CombosDaoManager {
  final _$CombosDaoMixin _db;
  CombosDaoManager(this._db);
  $$ComboShirtsTableTableManager get comboShirts =>
      $$ComboShirtsTableTableManager(_db.attachedDatabase, _db.comboShirts);
  $$ComboPantsTableTableManager get comboPants =>
      $$ComboPantsTableTableManager(_db.attachedDatabase, _db.comboPants);
}

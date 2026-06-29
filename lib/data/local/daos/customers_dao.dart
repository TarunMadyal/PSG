import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'customers_dao.g.dart';

/// Minimal customer access used during billing (optional customer capture).
/// The full customers feature arrives in a later phase.
@DriftAccessor(tables: [Customers, Outbox])
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Future<Customer?> findByPhone(String phone) {
    return (select(customers)
          ..where(
            (t) => t.phone.equals(phone) & t.isDeleted.equals(false),
          ))
        .getSingleOrNull();
  }

  Future<Customer?> getById(String id) {
    return (select(customers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Finds a non-deleted customer by exact (case-insensitive) name.
  Future<Customer?> findByName(String name) async {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    final rows = await (select(customers)
          ..where((t) => t.name.lower().equals(n) & t.isDeleted.equals(false))
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Live list of saved customers, newest first.
  Stream<List<Customer>> watchAll() {
    return (select(customers)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Resolves the customer for a sale, **always** returning an id so every bill
  /// is attributed:
  /// - phone given → find or create by phone (returning customers dedupe here);
  /// - name only   → reuse a same-named customer or create one;
  /// - neither     → create a walk-in record labelled [walkInRef] so the sale
  ///   still shows up under Customers.
  Future<String> resolveForSale({
    String? name,
    String? phone,
    required String walkInRef,
  }) async {
    final p = phone?.trim();
    if (p != null && p.isNotEmpty) {
      final id = await upsertByPhone(name: name, phone: p);
      if (id != null) return id;
    }
    final n = name?.trim();
    if (n != null && n.isNotEmpty) {
      final existing = await findByName(n);
      if (existing != null) return existing.id;
      return _create(name: n);
    }
    return _create(name: walkInRef);
  }

  /// Manually adds (or upserts by phone) a customer from the Customers screen.
  Future<String> addManual({String? name, String? phone}) async {
    final p = phone?.trim();
    if (p != null && p.isNotEmpty) {
      final id = await upsertByPhone(name: name, phone: p);
      if (id != null) return id;
    }
    return _create(name: name?.trim());
  }

  Future<String> _create({String? name, String? phone}) async {
    final created = await into(customers).insertReturning(
      CustomersCompanion.insert(name: Value(name), phone: Value(phone)),
    );
    await _enqueue(created.id, created.toJson());
    return created.id;
  }

  /// Finds an existing customer by phone or creates one. Returns the id, or
  /// null if no phone was supplied (anonymous sale).
  Future<String?> upsertByPhone({String? name, String? phone}) async {
    final trimmedPhone = phone?.trim();
    if (trimmedPhone == null || trimmedPhone.isEmpty) return null;

    final existing = await findByPhone(trimmedPhone);
    if (existing != null) {
      // Backfill a name if we now have one and didn't before.
      if ((existing.name == null || existing.name!.isEmpty) &&
          (name != null && name.trim().isNotEmpty)) {
        await (update(customers)..where((t) => t.id.equals(existing.id))).write(
          CustomersCompanion(
            name: Value(name.trim()),
            updatedAt: Value(DateTime.now().toUtc()),
            version: Value(existing.version + 1),
          ),
        );
        final updated = await findByPhone(trimmedPhone);
        if (updated != null) await _enqueue(updated.id, updated.toJson());
      }
      return existing.id;
    }

    final created = await into(customers).insertReturning(
      CustomersCompanion.insert(
        name: Value(name?.trim()),
        phone: Value(trimmedPhone),
      ),
    );
    await _enqueue(created.id, created.toJson());
    return created.id;
  }

  Future<void> _enqueue(String rowId, Map<String, dynamic> payload) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        entityTable: customers.actualTableName,
        rowId: rowId,
        op: OutboxOp.upsert,
        payload: Value(jsonEncode(payload)),
      ),
    );
  }
}

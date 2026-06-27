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

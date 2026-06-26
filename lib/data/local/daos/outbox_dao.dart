import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'outbox_dao.g.dart';

/// Data access for the local sync outbox.
///
/// Every local mutation enqueues an entry here (inside the same transaction as
/// the write) so the change is durably queued for the cloud even across crashes.
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Enqueues a pending change. Pass a [transaction]-bound DAO when enqueuing as
  /// part of a larger atomic write.
  Future<void> enqueue({
    required String tableName,
    required String rowId,
    required OutboxOp op,
    Map<String, dynamic>? payload,
  }) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        entityTable: tableName,
        rowId: rowId,
        op: op,
        payload: Value(payload == null ? null : jsonEncode(payload)),
      ),
    );
  }

  /// Oldest-first list of changes still waiting to be pushed.
  Future<List<OutboxData>> pending({int limit = 100}) {
    return (select(outbox)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> countPending() async {
    final count = countAll();
    final row =
        await (selectOnly(outbox)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> markDone(String id) =>
      (delete(outbox)..where((t) => t.id.equals(id))).go();
}

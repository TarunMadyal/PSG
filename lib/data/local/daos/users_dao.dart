import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../app_database.dart';
import '../tables/tables.dart';

part 'users_dao.g.dart';

/// Data access for staff/owner accounts, used by the auth layer for offline
/// PIN login and role checks.
@DriftAccessor(tables: [Users, Outbox])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  /// Active, non-deleted users available to log in, name-sorted.
  Future<List<User>> activeUsers() {
    return (select(users)
          ..where((t) => t.isDeleted.equals(false) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<User?> getById(String id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Live stream of all non-deleted users, name-sorted (for Settings → Users).
  Stream<List<User>> watchAll() {
    return (select(users)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.role),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  /// Activates or deactivates [userId] (soft toggle — does not delete).
  ///
  /// Uses a partial UPDATE (not insertOrReplace) so required columns such as
  /// name/role/pinHash are preserved.
  Future<void> setActive(String userId, {required bool active}) {
    return _patch(
      userId,
      (existing) => UsersCompanion(
        isActive: Value(active),
        updatedAt: Value(DateTime.now().toUtc()),
        version: Value(existing.version + 1),
      ),
    );
  }

  /// Updates a user's password hash (used to change the Admin/Staff password).
  Future<void> setPinHash(String userId, String pinHash) {
    return _patch(
      userId,
      (existing) => UsersCompanion(
        pinHash: Value(pinHash),
        updatedAt: Value(DateTime.now().toUtc()),
        version: Value(existing.version + 1),
      ),
    );
  }

  /// Renames a user (works for staff and owner). Trims and ignores blanks.
  Future<void> rename(String userId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value();
    return _patch(
      userId,
      (existing) => UsersCompanion(
        name: Value(trimmed),
        updatedAt: Value(DateTime.now().toUtc()),
        version: Value(existing.version + 1),
      ),
    );
  }

  /// Applies a partial update to a user and enqueues the change for sync.
  Future<void> _patch(
    String userId,
    UsersCompanion Function(User existing) build,
  ) {
    return transaction(() async {
      final existing = await getById(userId);
      if (existing == null) return;

      await (update(users)..where((t) => t.id.equals(userId)))
          .write(build(existing));

      final updated = await getById(userId);
      if (updated != null) {
        await into(outbox).insert(
          OutboxCompanion.insert(
            entityTable: users.actualTableName,
            rowId: userId,
            op: OutboxOp.upsert,
            payload: Value(jsonEncode(_safeJson(updated))),
          ),
        );
      }
    });
  }

  /// Soft-deletes a user (recoverable) and enqueues the deletion for sync. The
  /// account disappears from the login screen and the users list.
  Future<void> softDelete(String id) {
    return transaction(() async {
      final existing = await getById(id);
      if (existing == null) return;

      await (update(users)..where((t) => t.id.equals(id))).write(
        UsersCompanion(
          isDeleted: const Value(true),
          isActive: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
          version: Value(existing.version + 1),
        ),
      );

      await into(outbox).insert(
        OutboxCompanion.insert(
          entityTable: users.actualTableName,
          rowId: id,
          op: OutboxOp.delete,
        ),
      );
    });
  }

  /// Whether any account exists — drives the first-run owner setup flow.
  Future<bool> hasAny() async {
    final count = countAll();
    final row = await (selectOnly(users)
          ..addColumns([count])
          ..where(users.isDeleted.equals(false)))
        .getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  Future<int> countByRole(UserRole role) async {
    final count = countAll();
    final row = await (selectOnly(users)
          ..addColumns([count])
          ..where(
            users.isDeleted.equals(false) & users.role.equalsValue(role),
          ))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Inserts or updates a user and atomically enqueues the change for sync.
  /// Returns the persisted row (with generated id/defaults).
  Future<User> save(UsersCompanion user) {
    return transaction(() async {
      final existing =
          user.id.present ? await getById(user.id.value) : null;

      final toWrite = existing == null
          ? user
          : user.copyWith(
              updatedAt: Value(DateTime.now().toUtc()),
              version: Value(existing.version + 1),
            );

      final written = await into(users)
          .insertReturning(toWrite, mode: InsertMode.insertOrReplace);

      await into(outbox).insert(
        OutboxCompanion.insert(
          entityTable: users.actualTableName,
          rowId: written.id,
          op: OutboxOp.upsert,
          // PIN/password hashes are excluded from the sync payload — secrets
          // never leave the device through the outbox.
          payload: Value(jsonEncode(_safeJson(written))),
        ),
      );

      return written;
    });
  }

  Map<String, dynamic> _safeJson(User user) {
    final json = user.toJson();
    // Strip secrets regardless of camelCase/snake_case serialization.
    for (final key in ['pinHash', 'pin_hash', 'passwordHash', 'password_hash']) {
      json.remove(key);
    }
    return json;
  }
}

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a new v4 UUID — used as the client-side default for every primary
/// key so rows can be created offline on any device without collisions.
String newId() => _uuid.v4();

/// Columns shared by every synchronisable entity.
///
/// - [id]: UUID primary key generated on-device (duplicate-safe sync).
/// - [createdAt]/[updatedAt]: timestamps; [updatedAt] drives delta sync and
///   last-write-wins conflict resolution.
/// - [version]: incremented on each change; tiebreaker for conflicts.
/// - [isDeleted]: soft delete so deletions sync safely and stay recoverable.
/// - [deviceId]: which device last wrote the row (audit + conflict diagnosis).
///
/// Each table mixes this in and declares `primaryKey => {id}`.
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newId)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn get deviceId => text().nullable()();
}

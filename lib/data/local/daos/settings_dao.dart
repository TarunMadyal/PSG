import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'settings_dao.g.dart';

/// Access to the single shop-profile / receipt / printer settings row.
///
/// The table is effectively a singleton: [get] lazily creates the default row
/// on first read, and [save] always writes that same row.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Returns the settings row, creating it with defaults if it doesn't exist.
  Future<AppSetting> get() async {
    final existing = await (select(appSettings)
          ..where((t) => t.isDeleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;

    return into(appSettings).insertReturning(
      const AppSettingsCompanion(
        footerText: Value('Thank you! Visit again.'),
        gstNumber: Value('29AEXPJ3122K1Z1'),
        upiId: Value('8123426350@okbizaxis'),
      ),
    );
  }

  /// Live settings, so the UI reflects edits instantly.
  Stream<AppSetting?> watch() {
    return (select(appSettings)
          ..where((t) => t.isDeleted.equals(false))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Persists changes to the (single) settings row, bumping its version.
  Future<AppSetting> save(AppSettingsCompanion changes) async {
    final current = await get();
    await (update(appSettings)..where((t) => t.id.equals(current.id))).write(
      changes.copyWith(
        updatedAt: Value(DateTime.now().toUtc()),
        version: Value(current.version + 1),
      ),
    );
    return (await get());
  }
}

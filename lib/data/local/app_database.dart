import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/enums.dart';
import 'daos/bills_dao.dart';
import 'daos/combos_dao.dart';
import 'daos/customers_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/products_dao.dart';
import 'daos/reports_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/users_dao.dart';
import 'tables/sync_columns.dart';
import 'tables/tables.dart';

part 'app_database.g.dart';

/// The local SQLite database — the on-device source of truth that makes the POS
/// fully functional offline. Mirrored to Supabase by the sync engine (Phase 8).
@DriftDatabase(
  tables: [
    Users,
    AppSettings,
    Products,
    Customers,
    Bills,
    BillItems,
    Outbox,
    SyncState,
    ComboShirts,
    ComboPants,
  ],
  daos: [
    ProductsDao,
    OutboxDao,
    UsersDao,
    BillsDao,
    CustomersDao,
    ReportsDao,
    SettingsDao,
    CombosDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Builds a database over a custom executor — used by tests with an in-memory
  /// database so no files touch disk.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await combosDao.seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          // The app is still pre-production: rather than carry per-version
          // migrations, rebuild the schema from scratch on any upgrade. Cloud
          // sync (when enabled) re-hydrates data, so this is safe here.
          for (final table in allTables.toList().reversed) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
          await combosDao.seedDefaults();
        },
        // Note: FK enforcement is enabled via the raw-connection `setup`
        // callback (see `_openConnection`), not here — SQLite ignores
        // `PRAGMA foreign_keys` when run inside beforeOpen's transaction.
      );
}

/// Opens the production database file in the app documents directory, lazily so
/// the path lookup only happens when the DB is first used.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'psg_pos.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      // Enable FK enforcement on the raw connection — doing it here (not in a
      // transaction via beforeOpen) is the only place SQLite honours the pragma.
      setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
    );
  });
}

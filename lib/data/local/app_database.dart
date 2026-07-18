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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await combosDao.seedDefaults();
        },
        // Stepped, ADDITIVE migrations: each app update preserves existing data
        // (bills, products, combos, settings). Never drop-and-recreate — the
        // device DB is the source of truth until cloud sync exists.
        onUpgrade: (m, from, to) async {
          // v3: combo billing + nullable product on bill items.
          if (from < 3) {
            await m.createTable(comboShirts);
            await m.createTable(comboPants);
            // Relax bill_items.product_id from NOT NULL to nullable so combo /
            // random lines (which have no catalog product) can be stored. This
            // recreates the table copying all existing rows.
            // ignore: experimental_member_use
            await m.alterTable(TableMigration(billItems));
            await combosDao.seedDefaults();
          }
          // v4: GST number, cash limit and UPI QR settings.
          if (from < 4) {
            await m.addColumn(appSettings, appSettings.gstNumber);
            await m.addColumn(appSettings, appSettings.gstCashLimitPaise);
            await m.addColumn(appSettings, appSettings.upiId);
            await m.addColumn(appSettings, appSettings.upiName);
            await m.addColumn(appSettings, appSettings.showUpiQr);
            // Seed defaults into the existing (single) settings row.
            await customStatement(
              'UPDATE app_settings SET '
              "gst_number = COALESCE(gst_number, '29AEXPJ3122K1Z1'), "
              "upi_id = COALESCE(upi_id, '8123426350@okbizaxis')",
            );
          }
          // v5: split (Cash + UPI) payment amounts + GST-on-cash toggle.
          if (from < 5) {
            await m.addColumn(bills, bills.cashPaidPaise);
            await m.addColumn(bills, bills.upiPaidPaise);
            await m.addColumn(appSettings, appSettings.printGstOnCash);
          }
          // v6: GST vs non-GST bill flag. Classify existing bills sensibly —
          // UPI / Cash+UPI bills were GST bills; cash bills were not.
          if (from < 6) {
            await m.addColumn(bills, bills.isGst);
            await customStatement(
              'UPDATE bills SET is_gst = 1 '
              "WHERE payment_method IN ('upi', 'cashPlusUpi')",
            );
          }
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

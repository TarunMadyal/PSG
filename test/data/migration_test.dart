import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Proves that upgrading an existing on-device database preserves the shop's
/// data — an app update must never wipe bills, products or settings.
void main() {
  test('v3 -> v5 upgrade keeps data and adds new columns/defaults', () async {
    final dir = await Directory.systemTemp.createTemp('psg_migration');
    final path = '${dir.path}/psg_pos.sqlite';

    // Build a v3-shaped database with a real, already-configured settings row
    // and a bills table (so the v5 step that alters `bills` has a table to
    // touch), then stamp it as schema version 3 — exactly what a shop tablet on
    // an earlier app version looks like.
    final raw = sqlite3.open(path);
    raw.execute('''
      CREATE TABLE app_settings (
        id TEXT NOT NULL PRIMARY KEY,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        device_id TEXT,
        shop_name TEXT NOT NULL DEFAULT 'PSG Padmashree Garments',
        address TEXT,
        phone TEXT,
        receipt_width INTEGER NOT NULL DEFAULT 80,
        footer_text TEXT,
        printer_name TEXT,
        printer_address TEXT
      );
    ''');
    raw.execute('''
      CREATE TABLE bills (
        id TEXT NOT NULL PRIMARY KEY,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        device_id TEXT,
        invoice_no TEXT NOT NULL,
        customer_id TEXT,
        cashier_id TEXT NOT NULL,
        subtotal_paise INTEGER NOT NULL DEFAULT 0,
        discount_paise INTEGER NOT NULL DEFAULT 0,
        gst_paise INTEGER NOT NULL DEFAULT 0,
        grand_total_paise INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        billed_at INTEGER NOT NULL
      );
    ''');
    raw.execute(
      'INSERT INTO app_settings '
      '(id, created_at, updated_at, shop_name, address, phone, receipt_width) '
      "VALUES ('s1', 1700000000, 1700000000, 'Padamshree Garments', "
      "'Haveri', '8660011315', 80);",
    );
    raw.execute(
      'INSERT INTO bills (id, created_at, updated_at, invoice_no, cashier_id, '
      'grand_total_paise, payment_method, billed_at) '
      "VALUES ('b1', 1700000000, 1700000000, 'INV-00001', 'u1', 55000, "
      "'cash', 1700000000);",
    );
    raw.execute('PRAGMA user_version = 3;');
    raw.dispose();

    // Open the current app database over that file — runs the additive
    // v3 -> v5 migration.
    final db = AppDatabase.forTesting(
      NativeDatabase(
        File(path),
        setup: (c) => c.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    final settings = await db.settingsDao.get();

    // Existing settings survived the upgrade.
    expect(settings.shopName, 'Padamshree Garments');
    expect(settings.address, 'Haveri');
    expect(settings.phone, '8660011315');

    // New columns exist with sensible defaults.
    expect(settings.gstNumber, '29AEXPJ3122K1Z1');
    expect(settings.upiId, '8123426350@okbizaxis');
    expect(settings.printGstOnCash, false);

    // The existing bill survived and gained the nullable split columns.
    final bill = await (db.select(db.bills)
          ..where((t) => t.id.equals('b1')))
        .getSingle();
    expect(bill.grandTotalPaise, 55000);
    expect(bill.cashPaidPaise, isNull);
  });
}

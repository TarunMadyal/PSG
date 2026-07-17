import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Proves that upgrading an existing on-device database preserves the shop's
/// data — an app update must never wipe bills, products or settings.
void main() {
  test('v3 -> v4 upgrade keeps settings and seeds GST/UPI defaults', () async {
    final dir = await Directory.systemTemp.createTemp('psg_migration');
    final path = '${dir.path}/psg_pos.sqlite';

    // Build a v3-shaped settings table with a real, already-configured row,
    // then stamp the DB as schema version 3 — exactly what a shop tablet on the
    // previous app version looks like.
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
    raw.execute(
      'INSERT INTO app_settings '
      '(id, created_at, updated_at, shop_name, address, phone, receipt_width) '
      "VALUES ('s1', 1700000000, 1700000000, 'Padamshree Garments', "
      "'Haveri', '8660011315', 80);",
    );
    raw.execute('PRAGMA user_version = 3;');
    raw.dispose();

    // Open the current app database over that file — this runs the additive
    // v3 -> v4 migration.
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

    // Existing data survived the upgrade.
    expect(settings.shopName, 'Padamshree Garments');
    expect(settings.address, 'Haveri');
    expect(settings.phone, '8660011315');

    // New v4 columns exist and were seeded with sensible defaults.
    expect(settings.gstNumber, '29AEXPJ3122K1Z1');
    expect(settings.upiId, '8123426350@okbizaxis');
    expect(settings.gstCashLimitPaise, 1000000);
    expect(settings.showUpiQr, true);
  });
}

import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import 'sync_columns.dart';

/// Staff/owner accounts. Auth identity lives in Supabase (Phase 3); this mirror
/// enables offline login and role checks on-device.
class Users extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get role => textEnum<UserRole>()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get passwordHash => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Shop profile, receipt and printer configuration. Effectively a single row.
class AppSettings extends Table with SyncColumns {
  TextColumn get shopName =>
      text().withDefault(const Constant('PSG Padmashree Garments'))();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();

  /// Receipt paper width in mm (58 or 80).
  IntColumn get receiptWidth => integer().withDefault(const Constant(80))();

  /// Printed at the bottom of every bill (e.g. "Thank you! Visit again.").
  TextColumn get footerText => text().nullable()();

  /// The default Bluetooth thermal printer, saved after pairing in Settings.
  TextColumn get printerName => text().nullable()();
  TextColumn get printerAddress => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Product catalog. A product is just a name (+ optional descriptors) and a
/// single selling price — the amount the customer pays. Designed to scale to
/// thousands of rows.
class Products extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get size => text().nullable()();
  TextColumn get color => text().nullable()();

  /// Selling price in integer paise — the single price the customer pays.
  IntColumn get pricePaise => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Optional customer directory, keyed by phone for purchase-history lookup.
class Customers extends Table with SyncColumns {
  TextColumn get name => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Bill (invoice) header. Totals are stored in integer paise.
class Bills extends Table with SyncColumns {
  TextColumn get invoiceNo => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get cashierId => text()();

  IntColumn get subtotalPaise => integer().withDefault(const Constant(0))();
  IntColumn get discountPaise => integer().withDefault(const Constant(0))();
  IntColumn get gstPaise => integer().withDefault(const Constant(0))();
  IntColumn get grandTotalPaise => integer().withDefault(const Constant(0))();

  TextColumn get paymentMethod => textEnum<PaymentMethod>()();
  TextColumn get status =>
      textEnum<BillStatus>().withDefault(Constant(BillStatus.completed.name))();
  DateTimeColumn get billedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (customer_id) REFERENCES customers (id)',
        'FOREIGN KEY (cashier_id) REFERENCES users (id)',
      ];
}

/// A single line item on a bill. `nameSnapshot`/`ratePaise` freeze the product
/// details at sale time so history stays accurate if the product changes later.
class BillItems extends Table with SyncColumns {
  TextColumn get billId => text()();
  TextColumn get productId => text()();
  TextColumn get nameSnapshot => text()();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  IntColumn get ratePaise => integer().withDefault(const Constant(0))();
  IntColumn get discountPaise => integer().withDefault(const Constant(0))();
  IntColumn get amountPaise => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (bill_id) REFERENCES bills (id)',
        'FOREIGN KEY (product_id) REFERENCES products (id)',
      ];
}

/// Local-only queue of changes pending push to the cloud (the sync "outbox").
/// Durable so a crash mid-sync never loses a change; drained idempotently.
class Outbox extends Table {
  TextColumn get id => text().clientDefault(newId)();

  /// Name of the table the queued change targets (e.g. "products").
  TextColumn get entityTable => text()();
  TextColumn get rowId => text()();
  TextColumn get op => textEnum<OutboxOp>()();

  /// JSON payload of the row to upsert (null for deletes).
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local-only single-row sync cursor/state.
class SyncState extends Table {
  /// Always 1 — enforces a single row.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// High-water mark for delta pulls (latest `updatedAt` already pulled).
  DateTimeColumn get lastPullCursor => dateTime().nullable()();
  DateTimeColumn get lastPushAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

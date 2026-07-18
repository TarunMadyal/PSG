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

  /// GSTIN printed on bills (e.g. "29AEXPJ3122K1Z1"). Default seeded on first
  /// run in [SettingsDao.get]; nullable so the owner can clear it.
  TextColumn get gstNumber => text().nullable()();

  /// Bills at or below this amount (in paise) print the GST number; bills
  /// ABOVE it hide the GST number. Legacy — replaced by [printGstOnCash]; kept
  /// so existing databases don't need a destructive migration.
  IntColumn get gstCashLimitPaise =>
      integer().withDefault(const Constant(1000000))();

  /// Whether to print the GST number on CASH bills. Off by default. UPI and
  /// Cash+UPI bills always print the GST number (and the QR).
  BoolColumn get printGstOnCash => boolean().withDefault(const Constant(false))();

  /// The shop's UPI ID (VPA) for the payment QR, e.g. "name@okbizaxis".
  /// Default seeded on first run; nullable so the owner can clear it.
  TextColumn get upiId => text().nullable()();

  /// Payee name shown in the customer's UPI app when they scan the QR.
  TextColumn get upiName => text().nullable()();

  /// Whether to show / print the dynamic UPI payment QR on bills.
  BoolColumn get showUpiQr => boolean().withDefault(const Constant(true))();

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

  /// For split (Cash + UPI) payments: how much was paid in cash vs UPI. Null on
  /// older bills; then the split is derived from [paymentMethod] at read time.
  IntColumn get cashPaidPaise => integer().nullable()();
  IntColumn get upiPaidPaise => integer().nullable()();

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

/// Shirt options for combo billing. Owner-editable; seeded on first install.
class ComboShirts extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  IntColumn get pricePaise => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pant options for combo billing. Owner-editable; seeded on first install.
class ComboPants extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  IntColumn get pricePaise => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A single line item on a bill. `nameSnapshot`/`ratePaise` freeze the product
/// details at sale time so history stays accurate if the product changes later.
class BillItems extends Table with SyncColumns {
  TextColumn get billId => text()();
  // Nullable: combo and random items have no product in the catalog.
  TextColumn get productId => text().nullable()();
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

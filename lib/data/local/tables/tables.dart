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

/// Shop profile and receipt configuration. Effectively a single row.
class AppSettings extends Table with SyncColumns {
  TextColumn get shopName =>
      text().withDefault(const Constant('PSG Padmashree Garments'))();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get gstNumber => text().nullable()();
  TextColumn get logoUrl => text().nullable()();

  /// Receipt paper width in mm (58 or 80).
  IntColumn get receiptWidth => integer().withDefault(const Constant(80))();
  TextColumn get footerText => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Product catalog. Designed to scale to thousands of rows.
class Products extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get size => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();

  /// Selling price in integer paise.
  IntColumn get pricePaise => integer().withDefault(const Constant(0))();

  /// Purchase cost in integer paise (for profit reports later).
  IntColumn get costPaise => integer().nullable()();

  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Current stock level per product. The authoritative quantity is reconstructable
/// from [InventoryMovements]; this is a fast-read cache kept in step within the
/// same transaction as each movement.
class Inventory extends Table with SyncColumns {
  TextColumn get productId => text()();
  IntColumn get qtyOnHand => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // FKs are declared explicitly because `id` is inherited from the SyncColumns
  // mixin, which drift's `.references()` analysis can't resolve.
  @override
  List<String> get customConstraints =>
      ['FOREIGN KEY (product_id) REFERENCES products (id)'];
}

/// Append-only ledger of every stock change. Never updated/deleted, so stock is
/// always auditable and concurrent changes from two devices add up correctly
/// instead of overwriting each other.
class InventoryMovements extends Table with SyncColumns {
  TextColumn get productId => text()();

  /// Signed quantity delta (negative for a sale, positive for a restock).
  IntColumn get changeQty => integer()();
  TextColumn get reason => textEnum<MovementReason>()();

  /// The bill that caused this movement, when applicable.
  TextColumn get refBillId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints =>
      ['FOREIGN KEY (product_id) REFERENCES products (id)'];
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

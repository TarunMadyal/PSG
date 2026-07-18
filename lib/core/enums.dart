/// Shared domain enums, stored as their `name` string in both the local SQLite
/// database and the Supabase cloud — keeping the two schemas identical and the
/// values human-readable in raw data dumps/backups.
library;

/// Access role for a user account. Capability checks derive from this, and the
/// set is open for future roles (manager, accountant, …) without schema change.
enum UserRole {
  owner,
  staff,
}

/// How a bill was paid. The selectable options are cash, upi and cashPlusUpi;
/// `card`/`other` are legacy values kept only so older bills still parse.
enum PaymentMethod {
  cash,
  upi,
  cashPlusUpi,
  card,
  other,
}

/// The payment methods a cashier can pick for a new sale.
const List<PaymentMethod> kSelectablePaymentMethods = [
  PaymentMethod.cash,
  PaymentMethod.upi,
  PaymentMethod.cashPlusUpi,
];

extension PaymentMethodX on PaymentMethod {
  /// A UPI payment is expected (in full or in part), so a QR should be shown.
  bool get involvesUpi =>
      this == PaymentMethod.upi || this == PaymentMethod.cashPlusUpi;

  /// Human label for the bill / UI.
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.cashPlusUpi => 'Cash + UPI',
        PaymentMethod.card => 'Card',
        PaymentMethod.other => 'Other',
      };
}

/// Lifecycle state of a bill. `voided` (not `void`, a Dart keyword) marks a
/// reversed sale while preserving the record for audit.
enum BillStatus {
  completed,
  voided,
}

/// Operation type for a pending change in the local outbox (sync queue).
enum OutboxOp {
  upsert,
  delete,
}

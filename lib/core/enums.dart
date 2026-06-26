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

/// How a bill was paid.
enum PaymentMethod {
  cash,
  card,
  upi,
  other,
}

/// Lifecycle state of a bill. `voided` (not `void`, a Dart keyword) marks a
/// reversed sale while preserving the record for audit.
enum BillStatus {
  completed,
  voided,
}

/// Reason for an entry in the append-only inventory ledger. `returned`/`adjust`
/// avoid reserved words while staying readable.
enum MovementReason {
  sale,
  returned,
  adjust,
  restock,
}

/// Operation type for a pending change in the local outbox (sync queue).
enum OutboxOp {
  upsert,
  delete,
}

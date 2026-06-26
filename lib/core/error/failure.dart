/// Base type for all domain-level errors.
///
/// We surface failures as values (via [Result]) instead of throwing across
/// layer boundaries, so every call site is forced to handle the error case —
/// critical for a system that must never silently lose a sale.
sealed class Failure {
  const Failure(this.message, {this.cause});

  /// Human-readable, user-safe message.
  final String message;

  /// Original error/exception, kept for logging (never shown to users raw).
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Local database / storage error.
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});
}

/// Network or cloud (Supabase) error.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

/// Validation error (bad input, business rule violated).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

/// Authentication / authorization error.
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

/// Printer / hardware error.
class PrinterFailure extends Failure {
  const PrinterFailure(super.message, {super.cause});
}

/// Anything not otherwise classified.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}

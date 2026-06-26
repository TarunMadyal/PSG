import '../../../core/error/result.dart';
import 'app_user.dart';

/// Contract for authentication and account management. Backed locally by the
/// Drift database (offline-first); the cloud mirror is reconciled by sync.
abstract interface class AuthRepository {
  /// Whether any account exists yet (false triggers first-run owner setup).
  Future<bool> hasAnyUser();

  /// Active accounts available on the login screen's user picker.
  Future<List<AppUser>> listLoginableUsers();

  /// Verifies [pin] for [userId]. On success returns the authenticated user.
  Future<Result<AppUser>> loginWithPin({
    required String userId,
    required String pin,
  });

  /// Creates the first (owner) account during first-run setup.
  Future<Result<AppUser>> createOwner({
    required String name,
    required String pin,
  });

  /// Creates an additional account (owner-only; enforced by the caller).
  Future<Result<AppUser>> createUser({
    required String name,
    required String pin,
    required bool isOwner,
    String? phone,
  });
}

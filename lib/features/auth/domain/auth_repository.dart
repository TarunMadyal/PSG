import '../../../core/enums.dart';
import '../../../core/error/result.dart';
import 'app_user.dart';

/// Contract for authentication and the two-password access model. Backed locally
/// by the Drift database (offline-first).
///
/// There are exactly two passwords: one for the Admin (owner) and one for Staff.
/// The password entered at login determines the role — there is no role picker.
abstract interface class AuthRepository {
  /// Whether any account exists yet (false triggers first-run setup).
  Future<bool> hasAnyUser();

  /// Signs in by matching [password] against the stored account passwords.
  /// Returns the matching account (whose role decides the interface shown).
  Future<Result<AppUser>> login(String password);

  /// First-run setup: creates the Admin (owner) and Staff accounts.
  Future<Result<void>> createInitialAccounts({
    required String adminPassword,
    required String staffPassword,
  });

  /// Changes the password for the [role] account (Admin or Staff), creating the
  /// Staff account if it does not exist yet.
  Future<Result<void>> setPassword({
    required UserRole role,
    required String password,
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/enums.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../data/auth_repository_impl.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/capability.dart';
import 'auth_state.dart';

/// Wires the local [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthRepositoryImpl(
    usersDao: db.usersDao,
    hasher: ref.watch(pinHasherProvider),
  );
});

/// Owns the session and drives routing redirects.
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Kick off the async first-run check; start in loading.
    _bootstrap();
    return const AuthState.loading();
  }

  Future<void> _bootstrap() async {
    final hasUser = await _repo.hasAnyUser();
    state = hasUser
        ? const AuthState.unauthenticated()
        : const AuthState.needsSetup();
  }

  /// Accounts shown on the login picker.
  Future<List<AppUser>> loginableUsers() => _repo.listLoginableUsers();

  /// Attempts PIN login; updates state on success.
  Future<Result<AppUser>> login({
    required String userId,
    required String pin,
  }) async {
    final result = await _repo.loginWithPin(userId: userId, pin: pin);
    if (result case Success(:final value)) {
      state = AuthState.authenticated(value);
    }
    return result;
  }

  /// First-run: creates the owner and signs them in.
  Future<Result<AppUser>> createOwnerAndLogin({
    required String name,
    required String pin,
  }) async {
    final result = await _repo.createOwner(name: name, pin: pin);
    if (result case Success(:final value)) {
      state = AuthState.authenticated(value);
    }
    return result;
  }

  /// Owner adds a new staff (or owner) account from the Users settings.
  Future<Result<AppUser>> addUser({
    required String name,
    required String pin,
    required bool isOwner,
    String? phone,
  }) =>
      _repo.createUser(name: name, pin: pin, isOwner: isOwner, phone: phone);

  /// Toggles a user's active flag (owner-only; caller checks capability).
  Future<void> setUserActive(String userId, {required bool active}) async {
    final db = ref.read(databaseProvider);
    await db.usersDao.setActive(userId, active: active);
  }

  /// Removes a user account (owner-only). Refuses to delete the last owner so
  /// the shop can never be locked out.
  Future<Result<void>> deleteUser(String userId) async {
    final db = ref.read(databaseProvider);
    final user = await db.usersDao.getById(userId);
    if (user == null) {
      return const Result.failure(ValidationFailure('Account not found.'));
    }
    if (user.role == UserRole.owner) {
      final owners = await db.usersDao.countByRole(UserRole.owner);
      if (owners <= 1) {
        return const Result.failure(
          ValidationFailure('You cannot remove the only owner account.'),
        );
      }
    }
    await db.usersDao.softDelete(userId);
    return const Result.success(null);
  }

  /// Signs out — returns to the login screen (session is in-memory).
  void logout() => state = const AuthState.unauthenticated();
}

/// Live stream of all non-deleted users for the Settings → Users panel.
final usersListProvider = StreamProvider<List<AppUser>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.usersDao.watchAll().map(
        (rows) => rows
            .map(
              (u) => AppUser(
                id: u.id,
                name: u.name,
                role: u.role,
                phone: u.phone,
                email: u.email,
                isActive: u.isActive,
              ),
            )
            .toList(),
      );
});

/// The currently signed-in user, or null.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);

/// Capabilities granted to the current user (empty when signed out).
final capabilitiesProvider = Provider<Set<Capability>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const {};
  return capabilitiesFor(user.role);
});

/// Convenience: whether the current user has [capability].
final canProvider = Provider.family<bool, Capability>(
  (ref, capability) => ref.watch(capabilitiesProvider).contains(capability),
);

/// Whether the current user is an owner.
final isOwnerProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.role == UserRole.owner,
);

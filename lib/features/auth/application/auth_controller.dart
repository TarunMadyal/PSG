import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/enums.dart';
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

  /// Signs in with a single [password]; its match decides the role/interface.
  Future<Result<AppUser>> login(String password) async {
    final result = await _repo.login(password);
    if (result case Success(:final value)) {
      state = AuthState.authenticated(value);
    }
    return result;
  }

  /// First-run: creates the Admin and Staff accounts, then signs in as Admin.
  Future<Result<void>> setupAccounts({
    required String adminPassword,
    required String staffPassword,
  }) async {
    final result = await _repo.createInitialAccounts(
      adminPassword: adminPassword,
      staffPassword: staffPassword,
    );
    if (result case Success()) {
      // Sign in as Admin using the just-created password.
      await login(adminPassword);
    }
    return result;
  }

  /// Changes the Admin or Staff password (Admin-only; caller checks capability).
  Future<Result<void>> changePassword({
    required UserRole role,
    required String password,
  }) =>
      _repo.setPassword(role: role, password: password);

  /// Signs out — returns to the login screen (session is in-memory).
  void logout() => state = const AuthState.unauthenticated();
}

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

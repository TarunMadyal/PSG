import '../domain/app_user.dart';

/// Top-level authentication state driving routing and the session.
sealed class AuthState {
  const AuthState();

  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.needsSetup() = AuthNeedsSetup;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.authenticated(AppUser user) = AuthAuthenticated;

  /// The signed-in user, if any.
  AppUser? get user => switch (this) {
        AuthAuthenticated(:final user) => user,
        _ => null,
      };

  bool get isAuthenticated => this is AuthAuthenticated;
}

/// Still determining state (e.g. checking whether any account exists).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No account exists yet — show first-run owner setup.
final class AuthNeedsSetup extends AuthState {
  const AuthNeedsSetup();
}

/// Accounts exist but nobody is signed in — show login.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// A user is signed in.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  @override
  final AppUser user;
}

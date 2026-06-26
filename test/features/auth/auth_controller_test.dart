import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/di/providers.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/security/pin_hasher.dart';
import 'package:psg_pos/features/auth/application/auth_controller.dart';
import 'package:psg_pos/features/auth/application/auth_state.dart';
import 'package:psg_pos/data/local/app_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Fast hashing for tests.
        pinHasherProvider.overrideWithValue(const PinHasher(iterations: 500)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Waits for the controller's async bootstrap to settle.
  Future<AuthState> settle() async {
    container.read(authControllerProvider); // ensure built
    await Future<void>.delayed(Duration.zero);
    return container.read(authControllerProvider);
  }

  test('fresh install needs first-run setup', () async {
    final state = await settle();
    expect(state, isA<AuthNeedsSetup>());
  });

  test('createOwnerAndLogin creates an owner and signs in', () async {
    await settle();
    final result = await container
        .read(authControllerProvider.notifier)
        .createOwnerAndLogin(name: 'Asha', pin: '1234');

    expect(result.isSuccess, isTrue);
    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect(state.user!.name, 'Asha');
    expect(state.user!.role, UserRole.owner);
  });

  test('rejects a too-short PIN', () async {
    await settle();
    final result = await container
        .read(authControllerProvider.notifier)
        .createOwnerAndLogin(name: 'Asha', pin: '12');
    expect(result.isFailure, isTrue);
  });

  group('with an existing owner', () {
    setUp(() async {
      await settle();
      await container
          .read(authControllerProvider.notifier)
          .createOwnerAndLogin(name: 'Asha', pin: '1234');
      // Sign back out to test login.
      container.read(authControllerProvider.notifier).logout();
    });

    test('login with correct PIN authenticates', () async {
      final users =
          await container.read(authControllerProvider.notifier).loginableUsers();
      expect(users, hasLength(1));

      final result = await container
          .read(authControllerProvider.notifier)
          .login(userId: users.first.id, pin: '1234');

      expect(result.isSuccess, isTrue);
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    });

    test('login with wrong PIN fails and stays signed out', () async {
      final users =
          await container.read(authControllerProvider.notifier).loginableUsers();
      final result = await container
          .read(authControllerProvider.notifier)
          .login(userId: users.first.id, pin: '9999');

      expect(result.isFailure, isTrue);
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('logout returns to unauthenticated', () async {
      final users =
          await container.read(authControllerProvider.notifier).loginableUsers();
      await container
          .read(authControllerProvider.notifier)
          .login(userId: users.first.id, pin: '1234');
      container.read(authControllerProvider.notifier).logout();
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });
  });
}

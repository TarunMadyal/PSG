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

    test('owner can add staff who then appear on the login picker', () async {
      final notifier = container.read(authControllerProvider.notifier);
      final result =
          await notifier.addUser(name: 'Ravi', pin: '4321', isOwner: false);
      expect(result.isSuccess, isTrue);

      final users = await notifier.loginableUsers();
      expect(users.map((u) => u.name), containsAll(['Asha', 'Ravi']));
    });

    test('cannot delete the only owner', () async {
      final notifier = container.read(authControllerProvider.notifier);
      final users = await notifier.loginableUsers();
      final owner = users.firstWhere((u) => u.name == 'Asha');

      final result = await notifier.deleteUser(owner.id);
      expect(result.isFailure, isTrue);
      // Still present.
      final after = await notifier.loginableUsers();
      expect(after.any((u) => u.id == owner.id), isTrue);
    });

    test('deactivating then reactivating preserves the account', () async {
      final notifier = container.read(authControllerProvider.notifier);
      await notifier.addUser(name: 'Ravi', pin: '4321', isOwner: false);
      var users = await notifier.loginableUsers();
      final ravi = users.firstWhere((u) => u.name == 'Ravi');

      await notifier.setUserActive(ravi.id, active: false);
      users = await notifier.loginableUsers();
      expect(users.any((u) => u.id == ravi.id), isFalse);

      await notifier.setUserActive(ravi.id, active: true);
      users = await notifier.loginableUsers();
      final back = users.firstWhere((u) => u.id == ravi.id);
      expect(back.name, 'Ravi');
      expect(back.role, UserRole.staff);
    });

    test('owner can rename any account', () async {
      final notifier = container.read(authControllerProvider.notifier);
      final owner =
          (await notifier.loginableUsers()).firstWhere((u) => u.name == 'Asha');
      final result = await notifier.renameUser(owner.id, 'Asha Rao');
      expect(result.isSuccess, isTrue);
      final after = await notifier.loginableUsers();
      expect(after.firstWhere((u) => u.id == owner.id).name, 'Asha Rao');
    });

    test('deleting staff removes them from the login picker', () async {
      final notifier = container.read(authControllerProvider.notifier);
      await notifier.addUser(name: 'Ravi', pin: '4321', isOwner: false);
      var users = await notifier.loginableUsers();
      final ravi = users.firstWhere((u) => u.name == 'Ravi');

      final result = await notifier.deleteUser(ravi.id);
      expect(result.isSuccess, isTrue);

      users = await notifier.loginableUsers();
      expect(users.any((u) => u.id == ravi.id), isFalse);
    });
  });
}

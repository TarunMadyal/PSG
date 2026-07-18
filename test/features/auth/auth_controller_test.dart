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
        pinHasherProvider.overrideWithValue(const PinHasher(iterations: 500)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<AuthState> settle() async {
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(authControllerProvider);
  }

  AuthController auth() => container.read(authControllerProvider.notifier);

  test('fresh install needs setup', () async {
    expect(await settle(), isA<AuthNeedsSetup>());
  });

  test('setup creates both accounts and signs in as admin', () async {
    await settle();
    final result = await auth().setupAccounts(
      adminPassword: 'admin1',
      staffPassword: 'staff1',
    );
    expect(result.isSuccess, isTrue);
    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect(state.user!.role, UserRole.owner);
  });

  test('setup rejects too-short or identical passwords', () async {
    await settle();
    expect(
      (await auth().setupAccounts(adminPassword: '12', staffPassword: 'staff1'))
          .isFailure,
      isTrue,
    );
    expect(
      (await auth()
              .setupAccounts(adminPassword: 'same1', staffPassword: 'same1'))
          .isFailure,
      isTrue,
    );
  });

  group('with accounts set up', () {
    setUp(() async {
      await settle();
      await auth()
          .setupAccounts(adminPassword: 'admin1', staffPassword: 'staff1');
      auth().logout();
    });

    test('admin password opens the owner interface', () async {
      final result = await auth().login('admin1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.role, UserRole.owner);
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    });

    test('staff password opens the staff interface', () async {
      final result = await auth().login('staff1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.role, UserRole.staff);
    });

    test('wrong password fails and stays signed out', () async {
      final result = await auth().login('nope99');
      expect(result.isFailure, isTrue);
      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('changing the staff password works with the new one', () async {
      final changed = await auth().changePassword(
        role: UserRole.staff,
        password: 'staff2',
      );
      expect(changed.isSuccess, isTrue);

      expect((await auth().login('staff1')).isFailure, isTrue);
      final ok = await auth().login('staff2');
      expect(ok.isSuccess, isTrue);
      expect(ok.valueOrNull!.role, UserRole.staff);
    });
  });
}

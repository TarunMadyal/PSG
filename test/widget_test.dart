import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/app/app.dart';
import 'package:psg_pos/core/di/providers.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/security/pin_hasher.dart';
import 'package:psg_pos/data/local/app_database.dart';

void main() {
  late AppDatabase db;
  const hasher = PinHasher(iterations: 500);

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
  });

  tearDown(() async => db.close());

  Future<void> seedUser(String name, UserRole role, String password) {
    return db.usersDao.save(
      UsersCompanion.insert(
        name: name,
        role: role,
        pinHash: Value(hasher.hash(password)),
      ),
    );
  }

  Widget buildApp() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pinHasherProvider.overrideWithValue(hasher),
        ],
        child: const PsgPosApp(),
      );

  Future<void> pumpTablet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('fresh install shows first-run setup', (tester) async {
    await pumpTablet(tester);
    expect(find.text('Set up your passwords'), findsOneWidget);
  });

  testWidgets('with accounts present, shows the password login', (tester) async {
    await seedUser('Admin', UserRole.owner, 'admin1');
    await pumpTablet(tester);
    expect(find.text('Enter password'), findsOneWidget);
  });

  testWidgets('admin password lands on billing with full nav', (tester) async {
    await seedUser('Admin', UserRole.owner, 'admin1');
    await pumpTablet(tester);
    await login(tester, 'admin1');

    expect(find.text('Search products to add'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);
    expect(find.text('Products'), findsWidgets);

    await disposeApp(tester);
  });

  testWidgets('staff password hides owner-only navigation', (tester) async {
    await seedUser('Staff', UserRole.staff, 'staff1');
    await pumpTablet(tester);
    await login(tester, 'staff1');

    expect(find.text('Search products to add'), findsOneWidget);
    expect(find.text('Billing'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Products'), findsNothing);

    await disposeApp(tester);
  });
}

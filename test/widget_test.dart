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

  Future<void> seedUser(String name, UserRole role) {
    return db.usersDao.save(
      UsersCompanion.insert(
        name: name,
        role: role,
        pinHash: Value(hasher.hash('1234')),
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

  Future<void> loginWithPin(WidgetTester tester) async {
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
  }

  testWidgets('fresh install shows first-run setup', (tester) async {
    await pumpTablet(tester);
    expect(find.text('Set up your shop'), findsOneWidget);
  });

  testWidgets('with accounts present, shows the login screen', (tester) async {
    await seedUser('Asha', UserRole.owner);
    await pumpTablet(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Asha'), findsWidgets);
  });

  testWidgets('owner login lands on billing with full nav', (tester) async {
    await seedUser('Asha', UserRole.owner);
    await pumpTablet(tester);
    await loginWithPin(tester);

    // Lands on the billing screen (catalog search field present).
    expect(find.text('Search products to add'), findsOneWidget);
    // Owner sees owner-only destinations.
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);
    expect(find.text('Products'), findsWidgets);
  });

  testWidgets('staff login hides owner-only navigation', (tester) async {
    await seedUser('Ravi', UserRole.staff);
    await pumpTablet(tester);
    await loginWithPin(tester);

    expect(find.text('Search products to add'), findsOneWidget);
    expect(find.text('Billing'), findsWidgets);
    // Owner-only destinations are not shown to staff.
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Products'), findsNothing);
  });
}

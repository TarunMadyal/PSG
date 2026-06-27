// Generates PNG screenshots of the main screens with seeded demo data.
// Run with:  flutter test --update-goldens test/screenshots.dart
// Output:    test/goldens/*.png
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/app/app.dart';
import 'package:psg_pos/core/di/providers.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/core/security/pin_hasher.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:psg_pos/features/products/data/product_repository_impl.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';

/// Loads real fonts from the Flutter SDK so screenshot text renders properly
/// (otherwise flutter_test uses a placeholder box font).
Future<void> _loadRealFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      }
    }
    await loader.load();
  }

  const sdk = '/opt/flutter';
  const robotoDir =
      '$sdk/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto';
  await load('Roboto', [
    '$robotoDir/Roboto-Thin.ttf',
    '$robotoDir/Roboto-Light.ttf',
    '$robotoDir/Roboto-Regular.ttf',
    '$robotoDir/Roboto-Medium.ttf',
    '$robotoDir/Roboto-Bold.ttf',
    '$robotoDir/Roboto-Black.ttf',
  ]);
  await load('MaterialIcons', [
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

void main() {
  const hasher = PinHasher(iterations: 500);
  late AppDatabase db;

  setUpAll(_loadRealFonts);

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
  });
  tearDown(() async => db.close());

  Future<String> seedOwner() async {
    final u = await db.usersDao.save(
      UsersCompanion.insert(
        name: 'Asha Rao',
        role: UserRole.owner,
        pinHash: Value(hasher.hash('1234')),
      ),
    );
    return u.id;
  }

  Future<void> seedCatalog() async {
    final repo = ProductRepositoryImpl(productsDao: db.productsDao);
    final items = <List<dynamic>>[
      ['Cotton Formal Shirt', 'Raymond', 'M', 'White', 1299.0],
      ['Slim Fit Jeans', 'Levis', '32', 'Blue', 2499.0],
      ['Silk Saree', 'Nalli', 'Free', 'Maroon', 4999.0],
      ['Kids T-Shirt', 'Gini', '8Y', 'Yellow', 499.0],
      ['Woollen Sweater', 'Monte', 'L', 'Grey', 1899.0],
      ['Cotton Kurta', 'Fabindia', 'XL', 'Beige', 1599.0],
    ];
    for (final p in items) {
      await repo.save(
        ProductDraft(
          name: p[0] as String,
          brand: p[1] as String,
          size: p[2] as String,
          color: p[3] as String,
          price: Money.fromRupees(p[4] as double),
        ),
      );
    }
  }

  Widget app() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pinHasherProvider.overrideWithValue(hasher),
        ],
        child: const PsgPosApp(),
      );

  Future<void> setTablet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Future<void> login(WidgetTester tester) async {
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('01 first-run setup', (tester) async {
    await setTablet(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await shoot(tester, '01_setup');
    await teardown(tester);
  });

  testWidgets('02 login', (tester) async {
    await seedOwner();
    await setTablet(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await shoot(tester, '02_login');
    await teardown(tester);
  });

  testWidgets('03 billing with cart', (tester) async {
    await seedOwner();
    await seedCatalog();
    await setTablet(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await login(tester);
    // Add a couple of items to the cart.
    await tester.tap(find.text('Cotton Formal Shirt'));
    await tester.pump();
    await tester.tap(find.text('Silk Saree'));
    await tester.pumpAndSettle();
    await shoot(tester, '03_billing');
    await teardown(tester);
  });

  testWidgets('04 products catalog', (tester) async {
    await seedOwner();
    await seedCatalog();
    await setTablet(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await login(tester);
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();
    await shoot(tester, '04_products');
    await teardown(tester);
  });

  testWidgets('05 settings', (tester) async {
    await seedOwner();
    await setTablet(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await login(tester);
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await shoot(tester, '05_settings');
    await teardown(tester);
  });
}

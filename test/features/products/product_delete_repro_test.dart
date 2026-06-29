import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/di/providers.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/data/local/app_database.dart';
import 'package:psg_pos/features/auth/application/auth_controller.dart';
import 'package:psg_pos/features/auth/domain/capability.dart';
import 'package:psg_pos/features/products/data/product_repository_impl.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';
import 'package:psg_pos/features/products/presentation/products_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    final repo = ProductRepositoryImpl(productsDao: db.productsDao);
    await repo.save(
      ProductDraft(name: 'Linen Kurta', category: 'Kurta', price: Money.fromRupees(499)),
    );
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          capabilitiesProvider.overrideWithValue(Capability.values.toSet()),
        ],
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('opening the edit sheet does not crash', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Linen Kurta'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Edit product'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('deleting from the edit sheet removes the product',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Linen Kurta'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Delete product'));
    await tester.pumpAndSettle();
    // Confirm.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Linen Kurta'), findsNothing);
    await dispose(tester);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/utils/money.dart';
import 'package:psg_pos/features/auth/application/auth_controller.dart';
import 'package:psg_pos/features/auth/domain/capability.dart';
import 'package:psg_pos/features/products/application/product_providers.dart';
import 'package:psg_pos/features/products/domain/product_item.dart';
import 'package:psg_pos/features/products/presentation/products_screen.dart';

void main() {
  final sampleCatalog = [
    ProductItem(
      id: 'p1',
      name: 'Linen Kurta',
      price: Money.fromRupees(499),
      stock: 8,
    ),
  ];

  /// Pumps ProductsScreen in isolation. The catalog is injected as a stream
  /// value (no DB IO) so the test is fully deterministic, and capabilities are
  /// overridden to exercise owner-vs-staff gating.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Set<Capability> caps,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          capabilitiesProvider.overrideWithValue(caps),
          catalogProvider.overrideWith((ref) => Stream.value(sampleCatalog)),
        ],
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('owner sees products and the Add button', (tester) async {
    await pumpScreen(tester, caps: Capability.values.toSet());

    expect(find.text('Linen Kurta'), findsOneWidget);
    expect(find.text('In stock · 8'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add product'),
      findsOneWidget,
    );
  });

  testWidgets('staff sees products but no Add button', (tester) async {
    await pumpScreen(tester, caps: {Capability.createBill});

    expect(find.text('Linen Kurta'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add product'),
      findsNothing,
    );
  });
}

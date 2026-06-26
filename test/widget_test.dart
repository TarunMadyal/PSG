import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/app/app.dart';

void main() {
  testWidgets('App boots to the styled billing shell', (tester) async {
    // Use a tablet-sized surface so the wide (NavigationRail) layout renders.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: PsgPosApp()));
    await tester.pumpAndSettle();

    // Lands on Billing by default.
    expect(find.text('Fast Billing'), findsOneWidget);

    // All six top-level destinations are present in the rail.
    expect(find.text('Billing'), findsWidgets);
    expect(find.text('Products'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Sync status is surfaced for trust.
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('Can navigate to Reports tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: PsgPosApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reports').first);
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsWidgets);
    expect(find.textContaining('Phase 7'), findsOneWidget);
  });
}

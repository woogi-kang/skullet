import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skullet_example/main.dart';

void main() {
  testWidgets('shows skeletons, then the content, on every tab', (
    tester,
  ) async {
    Api.latency = const Duration(milliseconds: 80);
    await tester.pumpWidget(const DemoApp());
    expect(find.text('Grace Hopper'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Hedy'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pump();
    expect(find.text('Carrier Wave'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Carrier Wave'), findsOneWidget);

    // A reload draws its skeleton from the tracks last shown.
    final semantics = tester.ensureSemantics();
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.bySemanticsLabel('Loading tracks'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.bySemanticsLabel('Loading tracks'), findsNothing);
    semantics.dispose();

    await tester.tap(find.text('Options'));
    await tester.pump();
    expect(find.text('Grace Hopper'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Grace Hopper'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('pulse'), 200);
    await tester.tap(find.text('pulse'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('SkeletonAnimation.pulse'),
      200,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  // The smallest phones in use are about 320 logical pixels wide; an Android
  // emulator in CI is one of them.
  testWidgets('every tab fits a 320 wide phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Api.latency = const Duration(milliseconds: 80);
    await tester.pumpWidget(const DemoApp());
    for (final tab in ['Feed', 'Music', 'Options']) {
      await tester.tap(find.text(tab));
      // While loading, then loaded.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}

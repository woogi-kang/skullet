// Pixel tests of how skeletons and reveals look. Golden files are rendered on
// Linux; run with `flutter test --tags golden`, and update them with
// `--update-goldens`.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skullet/skullet.dart';
import 'package:skullet/src/plan.dart' show SweepTiming;

import 'demo.dart';

void main() {
  setUp(() {
    forgetShapes();
    SweepTiming.reset();
    debugSkulletAnimateInTests = true;
  });
  tearDown(() => debugSkulletAnimateInTests = false);

  Future<void> frame(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  void small(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final mode in [RevealMode.sweep, RevealMode.smart]) {
    testWidgets('${mode.name}: skeleton, reveal, content', (tester) async {
      small(tester);
      await tester.pumpWidget(host(profile(null), reveal: mode));
      await tester.pump(const Duration(milliseconds: 400));
      await frame(tester, '${mode.name}_0_skeleton');
      await tester.pumpWidget(host(profile(realUser), reveal: mode));
      for (var i = 1; i <= 3; i++) {
        // Frames at 60fps: a sweep that drops frames turns into a crossfade.
        for (var f = 0; f < 6; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await frame(tester, '${mode.name}_${i}_reveal');
      }
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await frame(tester, '${mode.name}_4_content');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('dark', (tester) async {
    small(tester);
    await tester.pumpWidget(host(profile(null, dark: true), dark: true));
    await tester.pump(const Duration(milliseconds: 1200));
    await frame(tester, 'dark_skeleton');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('debug overlay', (tester) async {
    small(tester);
    await tester.pumpWidget(host(profile(null), debug: true));
    await tester.pump(const Duration(milliseconds: 400));
    await frame(tester, 'debug_loading');
    await tester.pumpWidget(host(profile(realUser), debug: true));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await frame(tester, 'debug_revealed');
    await tester.pumpWidget(const SizedBox());
  });
}

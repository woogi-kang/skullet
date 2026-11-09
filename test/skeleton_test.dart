import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skullet/measure.dart';
import 'package:skullet/skullet.dart';
import 'package:skullet/src/environment.dart' show InputTracker;
import 'package:skullet/src/plan.dart';
import 'package:skullet/src/render.dart';

import 'demo.dart';

RenderReveal? revealOf(WidgetTester tester) {
  final found = find.byType(RevealLayer);
  return found.evaluate().isEmpty
      ? null
      : tester.renderObject<RenderReveal>(found);
}

void main() {
  setUp(() {
    forgetShapes();
    InputTracker.reset();
    SweepTiming.reset();
    debugSkulletAnimateInTests = false;
  });

  group('in tests, by default', () {
    testWidgets('pumpAndSettle settles while loading', (tester) async {
      await tester.pumpWidget(host(profile(null)));
      await tester.pumpAndSettle();
      expect(find.byType(GhostLayer), findsOneWidget);
    });

    testWidgets('reveals are instant and content is in the tree at once', (
      tester,
    ) async {
      await tester.pumpWidget(host(profile(null)));
      await tester.pumpWidget(host(profile(realUser)));
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(revealOf(tester)!.revealing, isFalse);
      expect(revealOf(tester)!.resolvedMode, RevealMode.instant);
    });
  });

  testWidgets('the skeleton takes exactly the content\'s space', (
    tester,
  ) async {
    await tester.pumpWidget(host(profile(null)));
    final loading = tester.getSize(find.byType(GhostLayer));
    await tester.pumpWidget(host(const ProfileCard(user: sampleUser)));
    expect(tester.getSize(find.byType(ProfileCard)), loading);
  });

  testWidgets(
    'while loading: labelled for screen readers, sample hidden, taps ignored',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        host(
          Skeleton<String>(
            data: null,
            sample: 'sample',
            label: 'Loading profile',
            builder: (context, text) =>
                TextButton(onPressed: () => taps++, child: Text(text)),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Loading profile'), findsOneWidget);
      expect(find.bySemanticsLabel('sample'), findsNothing);
      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      expect(taps, 0);
      semantics.dispose();
    },
  );

  testWidgets('the remembered shape draws the next skeleton without a sample', (
    tester,
  ) async {
    await tester.pumpWidget(host(profile(null, id: 'p')));
    await tester.pumpWidget(host(profile(realUser, id: 'p')));
    await tester.pump();
    await tester.pumpWidget(host(const SizedBox()));
    // Within a run, the data last shown is used: exact.
    await tester.pumpWidget(host(profile(null, id: 'p', sample: null)));
    expect(find.byType(GhostLayer), findsOneWidget);
    expect(
      find.text('Ada Lovelace'),
      findsOneWidget,
      reason: 'measured from the last data',
    );
    // Without it, the stored shape.
    Skullet.lastData.clear();
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pumpWidget(host(profile(null, id: 'p', sample: null)));
    expect(find.byType(ShapeLayer), findsOneWidget);
    expect(tester.getSize(find.byType(ShapeLayer)).height, greaterThan(100));
    // forgetShapes clears both.
    forgetShapes();
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pumpWidget(host(profile(null, id: 'p', sample: null)));
    expect(find.byType(ShapeLayer), findsNothing);
  });

  test('a shape survives JSON, layout only', () {
    const shape = SkeletonShape(Size(100, 40), [
      Bone(
        BoneKind.text,
        Rect.fromLTWH(0, 0, 80, 12),
        radius: BorderRadius.all(Radius.circular(4)),
        piece: 1,
        fontSize: 14,
      ),
      Bone(
        BoneKind.block,
        Rect.fromLTWH(0, 20, 20, 20),
        unit: Rect.fromLTWH(0, 0, 100, 40),
      ),
    ]);
    final back = SkeletonShape.fromJson(shape.toJson());
    expect(back.size, shape.size);
    expect(back.bones.map((b) => b.rect), shape.bones.map((b) => b.rect));
    expect(back.bones.first.radius, shape.bones.first.radius);
    expect(back.bones.last.unit, shape.bones.last.unit);
  });

  testWidgets('nothing to measure: three generic lines', (tester) async {
    await tester.pumpWidget(
      host(Skeleton<String>(data: null, builder: (c, s) => Text(s))),
    );
    expect(find.byType(SkeletonBox), findsNWidgets(3));
  });

  testWidgets('skeleton, error, empty and emptyMessage', (tester) async {
    Widget build({
      String? data,
      Widget? skeleton,
      Widget? error,
      bool empty = false,
    }) => host(
      Skeleton<String>(
        data: data,
        sample: 'x',
        skeleton: skeleton,
        error: error,
        empty: empty,
        emptyMessage: const Text('Nothing yet'),
        builder: (c, s) => Text(s),
      ),
    );
    await tester.pumpWidget(build(skeleton: const Text('custom')));
    expect(find.text('custom'), findsOneWidget);
    await tester.pumpWidget(build(error: const Text('failed')));
    expect(find.text('failed'), findsOneWidget);
    await tester.pumpWidget(build(data: 'here', empty: true));
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('Skeleton.child measures its child as it is', (tester) async {
    await tester.pumpWidget(
      host(Skeleton.child(loading: true, child: const Text('Hello'))),
    );
    expect(find.byType(GhostLayer), findsOneWidget);
    await tester.pumpWidget(
      host(Skeleton.child(loading: false, child: const Text('Hello'))),
    );
    expect(find.byType(GhostLayer), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('FutureSkeleton loads until the future completes', (
    tester,
  ) async {
    final completer = Completer<String>();
    await tester.pumpWidget(
      host(
        FutureSkeleton<String>(
          future: completer.future,
          sample: 'x',
          builder: (c, s) => Text(s),
        ),
      ),
    );
    expect(find.byType(GhostLayer), findsOneWidget);
    completer.complete('done');
    await tester.pumpAndSettle();
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('SkeletonReplace measures its stand-in', (tester) async {
    await tester.pumpWidget(
      host(
        Skeleton<String>(
          data: null,
          sample: 'x',
          builder: (c, s) => const SkeletonReplace(
            skeleton: SkeletonBox(width: 40, height: 40),
            child: FlutterLogo(size: 80),
          ),
        ),
      ),
    );
    expect(find.byType(FlutterLogo), findsNothing);
    expect(find.byType(SkeletonBox), findsOneWidget);
  });

  testWidgets('onReveal fires once content came in over a skeleton', (
    tester,
  ) async {
    var revealed = 0;
    await tester.pumpWidget(host(profile(null, onReveal: () => revealed++)));
    await tester.pumpWidget(
      host(profile(realUser, onReveal: () => revealed++)),
    );
    await tester.pump();
    expect(revealed, 1);
  });

  group('SkulletMode.system', () {
    Widget app({required Brightness theme}) => MaterialApp(
      theme: ThemeData(brightness: theme, fontFamily: 'Roboto'),
      home: Scaffold(body: profile(null)),
    );

    SkeletonColors colorsDrawn(WidgetTester tester) =>
        tester.widget<GhostLayer>(find.byType(GhostLayer)).colors;

    testWidgets('a light app on a dark system gets light colours', (
      tester,
    ) async {
      // macOS in Dark appearance, running an app that only has a light
      // theme: the dark palette would be white bones on a white page.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app(theme: Brightness.light));
      expect(colorsDrawn(tester), SkeletonColors.light);
    });

    testWidgets('a dark app on a light system gets dark colours', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app(theme: Brightness.dark));
      expect(colorsDrawn(tester), SkeletonColors.dark);
    });

    testWidgets('with no text colour around, follows the platform', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        MediaQuery.fromView(
          view: tester.view,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: profile(null),
          ),
        ),
      );
      expect(colorsDrawn(tester), SkeletonColors.dark);
    });
  });

  group('with animations on', () {
    setUp(() => debugSkulletAnimateInTests = true);
    tearDown(() => debugSkulletAnimateInTests = false);

    Future<RenderReveal> load(
      WidgetTester tester, {
      required Duration wait,
      RevealMode mode = RevealMode.smart,
      bool loading = false,
    }) async {
      await tester.pumpWidget(
        host(
          profile(loading ? realUser : null, loading: loading),
          reveal: mode,
        ),
      );
      await tester.pump(wait);
      await tester.pumpWidget(host(profile(realUser), reveal: mode));
      await tester.pump(const Duration(milliseconds: 16));
      return revealOf(tester)!;
    }

    testWidgets(
      'smart: a load under 150ms shows no skeleton and swaps at once',
      (tester) async {
        final reveal = await load(
          tester,
          wait: const Duration(milliseconds: 50),
        );
        expect(reveal.resolvedMode, RevealMode.instant);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('smart: a longer load comes in row by row', (tester) async {
      final reveal = await load(
        tester,
        wait: const Duration(milliseconds: 400),
      );
      expect(reveal.resolvedMode, RevealMode.smart);
      expect(reveal.revealing, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      expect(reveal.revealing, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('smart: input in the last 400ms swaps at once', (tester) async {
      await tester.pumpWidget(host(profile(null)));
      await tester.pump(const Duration(milliseconds: 400));
      InputTracker.markInput();
      await tester.pumpWidget(host(profile(realUser)));
      await tester.pump();
      expect(revealOf(tester)!.resolvedMode, RevealMode.instant);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('smart: a refetch crossfades quickly', (tester) async {
      final reveal = await load(
        tester,
        wait: const Duration(milliseconds: 400),
        loading: true,
      );
      expect(reveal.resolvedMode, RevealMode.together);
      await tester.pump(const Duration(milliseconds: 150));
      expect(reveal.revealing, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sweep and sequence run, then finish', (tester) async {
      for (final mode in [
        RevealMode.sweep,
        RevealMode.sequence,
        RevealMode.together,
      ]) {
        SweepTiming.reset();
        final reveal = await load(
          tester,
          wait: const Duration(milliseconds: 400),
          mode: mode,
        );
        expect(reveal.resolvedMode, mode);
        expect(reveal.revealing, isTrue);
        await tester.pump(const Duration(milliseconds: 700));
        expect(reveal.revealing, isFalse, reason: '$mode');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('reduced motion is always instant', (tester) async {
      Widget app(User? u) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: host(profile(u)),
      );
      await tester.pumpWidget(app(null));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(app(realUser));
      await tester.pump();
      expect(revealOf(tester)!.resolvedMode, RevealMode.instant);
    });
  });

  group('plan', () {
    RevealContext ctx({
      int waited = 400,
      bool input = false,
      bool refetch = false,
      double height = 200,
      int pieces = 6,
    }) => RevealContext(
      waited: Duration(milliseconds: waited),
      input: input,
      refetch: refetch,
      height: height,
      pieces: pieces,
    );

    test('smart chooses as skullet does', () {
      expect(choose(RevealMode.smart, ctx(waited: 100)), RevealMode.instant);
      expect(choose(RevealMode.smart, ctx(input: true)), RevealMode.instant);
      expect(choose(RevealMode.smart, ctx(refetch: true)), RevealMode.together);
      expect(choose(RevealMode.smart, ctx(height: 40)), RevealMode.together);
      expect(choose(RevealMode.smart, ctx(pieces: 3)), RevealMode.together);
      expect(choose(RevealMode.smart, ctx()), RevealMode.smart);
      expect(choose(RevealMode.sweep, ctx()), RevealMode.sweep);
      expect(choose(RevealMode.sequence, ctx(waited: 0)), RevealMode.sequence);
    });

    test('sequence: top to bottom within 320ms, each fade 200ms', () {
      const bones = [
        Bone(BoneKind.text, Rect.fromLTWH(0, 0, 100, 10), piece: 0),
        Bone(BoneKind.text, Rect.fromLTWH(0, 90, 100, 10), piece: 1),
      ];
      final c = Cascade.plan(
        content: bones,
        skeleton: bones,
        size: const Size(100, 100),
        screenTop: 0,
        screenHeight: 800,
        byRow: false,
      );
      expect(c.pieceDelay[0], Duration.zero);
      expect(c.pieceDelay[1]! > c.pieceDelay[0]!, isTrue);
      expect(c.duration <= cascadeSpread + fadeDuration, isTrue);
    });

    test('smart rows: smaller text a beat behind, off-screen at once', () {
      const unit = Rect.fromLTWH(0, 0, 300, 40);
      const far = Rect.fromLTWH(0, 2000, 300, 40);
      const bones = [
        Bone(
          BoneKind.text,
          Rect.fromLTWH(0, 0, 100, 16),
          piece: 0,
          fontSize: 17,
          unit: unit,
        ),
        Bone(
          BoneKind.text,
          Rect.fromLTWH(0, 20, 80, 12),
          piece: 1,
          fontSize: 13,
          unit: unit,
        ),
        Bone(
          BoneKind.text,
          Rect.fromLTWH(0, 2000, 80, 12),
          piece: 2,
          fontSize: 13,
          unit: far,
        ),
      ];
      final c = Cascade.plan(
        content: bones,
        skeleton: bones,
        size: const Size(300, 2040),
        screenTop: 0,
        screenHeight: 800,
        byRow: true,
      );
      expect(c.pieceDelay[1]! - c.pieceDelay[0]!, secondaryDelay);
      expect(c.pieceDelay[2], isNull);
    });
  });

  group('a changed theme reaches a skeleton already on screen', () {
    setUp(() => debugSkulletAnimateInTests = true);
    tearDown(() => debugSkulletAnimateInTests = false);

    Widget themed(SkeletonAnimation animation, {double radius = 4}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: SkulletProvider(
            theme: SkulletTheme(animation: animation, radius: radius),
            child: Skeleton.child(
              loading: true,
              child: const Text('A line of sample text'),
            ),
          ),
        );

    testWidgets('from a still animation to a shimmer', (tester) async {
      await tester.pumpWidget(themed(SkeletonAnimation.none));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(themed(SkeletonAnimation.shimmer));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('a new text radius is measured again', (tester) async {
      await tester.pumpWidget(themed(SkeletonAnimation.none));
      await tester.pump(const Duration(milliseconds: 300));
      RenderGhost ghost() =>
          tester.renderObject<RenderGhost>(find.byType(GhostLayer));
      expect(ghost().shape!.bones.first.radius.topLeft.x, 4);

      await tester.pumpWidget(themed(SkeletonAnimation.none, radius: 10));
      expect(ghost().shape!.bones.first.radius.topLeft.x, 10);
    });
  });
}

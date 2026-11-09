// Regression tests for 0.2.0: the hidden sample stays hidden, skeletons
// out of sight ask for no frames, content keeps its state through a refetch,
// and the stored format, directions, text kinds and themes all hold.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skullet/measure.dart';
import 'package:skullet/skullet.dart';
import 'package:skullet/src/plan.dart';
import 'package:skullet/src/render.dart';
import 'package:skullet/src/skeleton.dart' show shapeKey;

import 'demo.dart';

void main() {
  setUp(() {
    forgetShapes();
    SweepTiming.reset();
    debugSkulletAnimateInTests = false;
  });
  tearDown(() => debugSkulletAnimateInTests = false);

  group('the hidden sample', () {
    testWidgets('takes no focus, by autofocus or by Tab', (tester) async {
      final hidden = FocusNode(debugLabel: 'hidden');
      final visible = FocusNode(debugLabel: 'visible');
      addTearDown(hidden.dispose);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              TextButton(
                focusNode: visible,
                onPressed: () {},
                child: const Text('Visible'),
              ),
              Skeleton<String>(
                data: null,
                sample: 'sample',
                builder: (context, text) => TextButton(
                  focusNode: hidden,
                  autofocus: true,
                  onPressed: () {},
                  child: Text(text),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(hidden.hasFocus, isFalse);
      visible.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(hidden.hasFocus, isFalse);
    });

    testWidgets('runs no animations of its own', (tester) async {
      debugSkulletAnimateInTests = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SkulletProvider(
            mode: SkulletMode.light,
            theme: const SkulletTheme(animation: SkeletonAnimation.none),
            child: Skeleton<String>(
              data: null,
              sample: 'sample',
              builder: (context, text) => const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
      // Past the 150ms a skeleton is held back for.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('frames', () {
    Widget shimmering({required bool tickers}) => MaterialApp(
      home: TickerMode(
        enabled: tickers,
        child: SkulletProvider(mode: SkulletMode.light, child: profile(null)),
      ),
    );

    testWidgets('a skeleton where tickers are off asks for none', (
      tester,
    ) async {
      debugSkulletAnimateInTests = true;
      await tester.pumpWidget(shimmering(tickers: false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a skeleton on screen keeps shimmering', (tester) async {
      debugSkulletAnimateInTests = true;
      await tester.pumpWidget(shimmering(tickers: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a skeleton paints on a layer of its own', (tester) async {
      await tester.pumpWidget(host(profile(null)));
      expect(
        tester.renderObject<RenderGhost>(find.byType(GhostLayer)),
        isA<RenderGhost>().having(
          (r) => r.isRepaintBoundary,
          'isRepaintBoundary',
          isTrue,
        ),
      );
    });
  });

  testWidgets('content keeps its state through a refetch', (tester) async {
    Widget counter(bool loading) => host(
      Skeleton<String>(
        data: 'data',
        loading: loading,
        builder: (context, _) => const _Counter(),
      ),
    );
    await tester.pumpWidget(counter(false));
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(counter(true));
    await tester.pumpWidget(counter(false));
    expect(find.text('1'), findsOneWidget);
  });

  group('remembered shapes', () {
    test('store their format version and kinds by name', () {
      const shape = SkeletonShape(Size(10, 10), [
        Bone(BoneKind.text, Rect.fromLTWH(0, 0, 10, 4)),
      ]);
      final json = shape.toJson();
      expect(json['v'], SkeletonShape.formatVersion);
      expect((json['b']! as List).first, containsPair('k', 'text'));
      expect(SkeletonShape.fromJson(json).bones.single.kind, BoneKind.text);
    });

    test('written by 0.1.0 still read', () {
      final shape = SkeletonShape.fromJson({
        'w': 10,
        'h': 10,
        'b': [
          {
            'k': 1,
            'r': [0, 0, 10, 10],
            'c': [2, 2, 2, 2],
            'p': 0,
            'f': 0,
          },
        ],
      });
      expect(shape.bones.single.kind, BoneKind.block);
    });

    test('from a newer version are refused, not misread', () {
      final json = {'v': 99, 'w': 1, 'h': 1, 'b': <Object>[]};
      expect(() => SkeletonShape.fromJson(json), throwsFormatException);
      expect(SkeletonShape.tryFromJson(json), isNull);
      expect(SkeletonShape.tryFromJson({'v': 1}), isNull);
    });

    testWidgets('are kept per screen width', (tester) async {
      late BuildContext context;
      Future<String> keyAt(double width) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        return shapeKey('feed', context);
      }

      expect(await keyAt(390), await keyAt(395));
      expect(await keyAt(390), isNot(await keyAt(844)));
    });

    testWidgets('go to the provider\'s store when it has one', (tester) async {
      final store = MemoryShapeStore();
      await tester.pumpWidget(
        MaterialApp(
          home: SkulletProvider(
            store: store,
            child: Skeleton<String>(
              id: 'own',
              data: 'data',
              builder: (context, text) => Text(text),
            ),
          ),
        ),
      );
      await tester.pump();
      final key = shapeKey('own', tester.element(find.text('data')));
      expect(store.read(key), isNotNull);
      expect(Skullet.store.read(key), isNull);
    });

    test('the data last shown is bounded', () {
      final limit = Skullet.lastDataLimit;
      addTearDown(() => Skullet.lastDataLimit = limit);
      Skullet.lastDataLimit = 2;
      Skullet.remember('a', 1);
      Skullet.remember('b', 2);
      Skullet.remember('a', 3);
      Skullet.remember('c', 4);
      expect(Skullet.lastData.keys, ['a', 'c']);
    });
  });

  group('measuring', () {
    Future<List<Bone>> measure(
      WidgetTester tester,
      Widget child, {
      TextDirection direction = TextDirection.ltr,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Material(
            child: Directionality(
              textDirection: direction,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: const ValueKey('root'),
                  width: 300,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      return measureBones(tester.element(find.byKey(const ValueKey('root'))));
    }

    testWidgets('reads corners by direction', (tester) async {
      final bones = await measure(
        tester,
        const ClipRRect(
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(10),
          ),
          child: SkeletonBlock(child: SizedBox(width: 50, height: 50)),
        ),
        direction: TextDirection.rtl,
      );
      final radius = bones.single.radius;
      expect(radius.topRight, const Radius.circular(10));
      expect(radius.topLeft, Radius.zero);
    });

    testWidgets('gives SelectableText bars', (tester) async {
      final bones = await measure(
        tester,
        const SelectableText('Selectable text that is measured'),
      );
      // One line with Roboto; the web test font wraps it.
      expect(bones.where((b) => b.kind == BoneKind.text), isNotEmpty);
    });

    testWidgets('gives widgets inline in text a block', (tester) async {
      final bones = await measure(
        tester,
        const Text.rich(
          TextSpan(
            text: 'Verified ',
            children: [WidgetSpan(child: Icon(Icons.check_circle, size: 16))],
          ),
        ),
      );
      expect(bones.where((b) => b.kind == BoneKind.text), isNotEmpty);
      expect(bones.where((b) => b.kind == BoneKind.block), hasLength(1));
    });

    testWidgets('draws Cupertino controls as blocks', (tester) async {
      final bones = await measure(
        tester,
        Row(
          children: [
            CupertinoSwitch(value: true, onChanged: (_) {}),
            const CupertinoActivityIndicator(),
          ],
        ),
      );
      final blocks = bones.where((b) => b.kind == BoneKind.block).toList();
      expect(blocks, hasLength(2));
      final toggle = blocks.first;
      expect(toggle.radius.topLeft.x, toggle.rect.shortestSide / 2);
    });

    test('a sequence reads right to left in RTL', () {
      Duration? first(TextDirection direction) {
        final cascade = Cascade.plan(
          content: const [
            Bone(BoneKind.block, Rect.fromLTWH(0, 0, 40, 20), piece: 0),
            Bone(BoneKind.block, Rect.fromLTWH(160, 0, 40, 20), piece: 1),
          ],
          skeleton: const [],
          size: const Size(200, 20),
          screenTop: 0,
          screenHeight: 800,
          byRow: false,
          textDirection: direction,
        );
        return cascade.pieceDelay[0];
      }

      expect(first(TextDirection.ltr), Duration.zero);
      expect(first(TextDirection.rtl), greaterThan(Duration.zero));
    });
  });

  group('themes', () {
    testWidgets('a SkulletTheme in ThemeData applies without a provider', (
      tester,
    ) async {
      late SkulletProvider provider;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [SkulletTheme(radius: 9)]),
          home: Builder(
            builder: (context) {
              provider = SkulletProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(provider.theme.radius, 9);
    });

    test('themes blend', () {
      const a = SkulletTheme(radius: 0);
      const b = SkulletTheme(radius: 10, animation: SkeletonAnimation.pulse);
      final half = a.lerp(b, 0.5);
      expect(half.radius, 5);
      expect(half.animation, SkeletonAnimation.pulse);
      expect(a.lerp(b, 0.2).animation, SkeletonAnimation.shimmer);
    });

    testWidgets('high contrast strengthens the fill', (tester) async {
      late SkeletonColors colors;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: SkulletProvider(
            mode: SkulletMode.light,
            child: Builder(
              builder: (context) {
                colors = SkulletProvider.of(context).colorsOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(colors.base.a, closeTo(SkeletonColors.light.base.a * 2, 0.01));
    });

    testWidgets('the provider\'s label is read for unlabelled skeletons', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SkulletProvider(
            label: 'Loading',
            child: Skeleton<String>(
              data: null,
              sample: 'sample',
              builder: (context, text) => Text(text),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets('FutureSkeleton passes its reveal and skeleton on', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FutureSkeleton<String>(
          future: null,
          reveal: RevealMode.sweep,
          skeleton: const SizedBox(key: ValueKey('own'), height: 10),
          builder: (context, text) => Text(text),
        ),
      ),
    );
    final skeleton = tester.widget<Skeleton<String>>(
      find.byType(Skeleton<String>),
    );
    expect(skeleton.reveal, RevealMode.sweep);
    expect(find.byKey(const ValueKey('own')), findsOneWidget);
  });

  testWidgets('a sweep over selectable content paints without errors', (
    tester,
  ) async {
    debugSkulletAnimateInTests = true;
    Widget at(User? user) =>
        host(SelectionArea(child: profile(user)), reveal: RevealMode.sweep);
    await tester.pumpWidget(at(null));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(at(realUser));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // The promise skullet makes: the skeleton takes the content's exact space,
  // whatever the text scale, direction or brightness.
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final direction in TextDirection.values) {
      for (final dark in [false, true]) {
        testWidgets('nothing moves at text scale $scale, ${direction.name}, '
            '${dark ? 'dark' : 'light'}', (tester) async {
          Widget at(Widget child) => host(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(textDirection: direction, child: child),
              ),
            ),
            dark: dark,
          );
          Widget card(String? data) => Skeleton<String>(
            data: data,
            sample: 'A sample line of text',
            builder: (context, text) => Column(
              key: const ValueKey('card'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 18)),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16),
                    Expanded(child: Text('$text, and a second line')),
                  ],
                ),
              ],
            ),
          );
          await tester.pumpWidget(at(card(null)));
          final loading = tester.getSize(find.byType(GhostLayer));
          await tester.pumpWidget(at(card('A sample line of text')));
          expect(tester.getSize(find.byKey(const ValueKey('card'))), loading);
        });
      }
    }
  }
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => count++),
    child: Text('$count'),
  );
}

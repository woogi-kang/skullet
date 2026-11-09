// Runs skullet on a real device, simulator, desktop or browser: skeletons
// paint on this platform's renderer, every reveal runs to its end, the
// example loads on each tab, and a screen of skeletons keeps up.
//
//   flutter test integration_test -d <device>
//
// CI runs this on an Android emulator, an iOS simulator, macOS, Windows,
// Linux and Chrome.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skullet/skullet.dart';
import 'package:skullet_example/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUp(() {
    // Desktop test runs can look like `flutter test` to skullet; these test
    // the real animations.
    debugSkulletAnimateInTests = true;
    forgetShapes();
  });

  testWidgets('skeletons paint on this platform, in the app\'s brightness', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _Harness(dark: dark, data: null, reveal: RevealMode.smart),
      );
      await _wait(tester, const Duration(milliseconds: 600));
      final ghost = _renderOf(tester, 'GhostLayer');
      final painted = await _paintedPixels(ghost);
      expect(painted, greaterThan(100), reason: 'dark: $dark');
      final context = tester.element(find.byType(Skeleton<String>));
      expect(
        SkulletProvider.of(context).colorsOf(context),
        dark ? SkeletonColors.dark : SkeletonColors.light,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  for (final mode in RevealMode.values) {
    testWidgets('${mode.name}: the reveal runs to its end', (tester) async {
      await tester.pumpWidget(_Harness(dark: false, data: null, reveal: mode));
      await _wait(tester, const Duration(milliseconds: 400));
      await tester.pumpWidget(
        _Harness(dark: false, data: 'Ada Lovelace', reveal: mode),
      );
      await _wait(tester, const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      final reveal = _renderOf(tester, 'RevealLayer');
      expect((reveal as dynamic).revealing, isFalse);
      expect(await _paintedPixels(reveal), greaterThan(100));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the example loads on every tab', (tester) async {
    Api.latency = const Duration(milliseconds: 600);
    await tester.pumpWidget(const DemoApp());
    await _waitFor(tester, find.text('Grace Hopper'));
    await tester.tap(find.text('Music'));
    await _waitFor(tester, find.text('Carrier Wave'));
    await tester.tap(find.text('Options'));
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a screen of shimmering skeletons keeps up', (tester) async {
    final timings = <ui.FrameTiming>[];
    void collect(List<ui.FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    await tester.pumpWidget(const _List());
    await _wait(tester, const Duration(seconds: 3));
    SchedulerBinding.instance.removeTimingsCallback(collect);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    if (timings.isEmpty) {
      debugPrint('skullet benchmark: this platform reports no frame timings');
      return;
    }
    String summary(Duration Function(ui.FrameTiming) of) {
      final ms = [for (final t in timings) of(t).inMicroseconds / 1000]..sort();
      final average = ms.reduce((a, b) => a + b) / ms.length;
      final p90 = ms[math.min(ms.length - 1, (ms.length * 0.9).floor())];
      return 'avg ${average.toStringAsFixed(2)}ms, '
          'p90 ${p90.toStringAsFixed(2)}ms';
    }

    final report =
        'skullet benchmark (40 skeletons, 3s): ${timings.length} frames; '
        'build ${summary((t) => t.buildDuration)}; '
        'raster ${summary((t) => t.rasterDuration)}';
    debugPrint(report);
    binding.reportData = {'benchmark': report};
  });
}

/// Pumps frames for [duration] of real time.
Future<void> _wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Pumps until [finder] finds something, for up to ten seconds.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $finder');
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The render object of the one widget named [type]: skullet's layers are
/// not exported, but each paints on a layer of its own.
RenderBox _renderOf(WidgetTester tester, String type) => tester.renderObject(
  find.byWidgetPredicate((w) => w.runtimeType.toString() == type),
);

/// How many pixels [box] painted on its own layer, as this platform's
/// renderer drew them.
Future<int> _paintedPixels(RenderBox box) async {
  expect(box.isRepaintBoundary, isTrue);
  final layer = box.debugLayer! as OffsetLayer;
  final image = await layer.toImage(Offset.zero & box.size);
  final bytes = await image.toByteData();
  image.dispose();
  var painted = 0;
  for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
    if (bytes.getUint8(i) > 0) painted++;
  }
  return painted;
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.dark,
    required this.data,
    required this.reveal,
  });

  final bool dark;
  final String? data;
  final RevealMode reveal;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SkulletProvider(
            reveal: reveal,
            child: Skeleton<String>(
              data: data,
              sample: 'Sample Name',
              builder: (context, name) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.indigo,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(name, style: const TextStyle(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 4; i++)
                    Text('Line $i of a profile that wraps like a real one.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ListView.builder(
          itemCount: 40,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.all(12),
            child: Skeleton<String>(
              data: null,
              sample: 'Row $i',
              builder: (context, text) => Row(
                children: [
                  const Icon(Icons.person, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(text), const Text('A second line')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Runs skullet's own geometry cases against the Flutter measurement, with the
// same checks as skullet's verify.ts: every line of text is covered, every
// marked block has a bone of its exact size, every marked text gets one bar
// per line, clipped text stays inside its box, and no bone covers nothing.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skullet/measure.dart';
import 'package:skullet/skullet.dart';

import 'geometry_cases.dart';

const tolerance = 1.0;

void main() {
  // Images the cases decode stay in the image cache, which the leak tracker
  // would otherwise count against the last test.
  tearDown(() {
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  for (final c in geometryCases) {
    testWidgets('${c.label}: ${c.description}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: c.width,
                child: Builder(builder: c.build),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final rootElement = tester.element(find.byType(SizedBox).first);
      final root = rootElement.findRenderObject()! as RenderBox;
      final bones = measureBones(
        rootElement,
      ).where((b) => b.kind != BoneKind.surface).map((b) => b.rect).toList();
      final failures = verify(tester, root, rootElement, bones);
      expect(failures, isEmpty, reason: bones.join('\n'));
    });
  }
}

Rect rectIn(RenderBox root, RenderBox box, [Rect? local]) =>
    MatrixUtils.transformRect(
      box.getTransformTo(root),
      local ?? Offset.zero & box.size,
    );

/// Line fragments of text that should be covered, clipped to what shows.
List<Rect> textFragments(RenderBox root, Element from) {
  final lines = <Rect>[];
  void visit(Element element, bool skipped) {
    final widget = element.widget;
    // Text a block covers whole is drawn by that block, as skullet marks it
    // covered.
    final skip =
        skipped ||
        (widget is Expect && widget.expected == Expected.block) ||
        widget is SkeletonIgnore ||
        widget is SkeletonBlock ||
        widget is Icon ||
        widget is InputDecorator ||
        widget is Switch;
    if (element is RenderObjectElement) {
      final object = element.renderObject;
      if (object is RenderParagraph && !skip) {
        final text = object.text.toPlainText();
        final start = text.indexOf(RegExp(r'\S'));
        if (start >= 0) {
          final end = text.trimRight().length;
          for (final box in object.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          )) {
            final r = box.toRect().intersect(Offset.zero & object.size);
            if (r.width >= 1 && r.height >= 1) {
              lines.add(rectIn(root, object, r));
            }
          }
        }
      }
    }
    element.visitChildElements((e) => visit(e, skip));
  }

  visit(from, false);
  return lines;
}

int lineCount(List<Rect> boxes) {
  final tops = <double>[];
  for (final b in boxes) {
    if (!tops.any((t) => (t - b.top).abs() < 2)) tops.add(b.top);
  }
  return tops.length;
}

List<String> verify(
  WidgetTester tester,
  RenderBox root,
  Element rootElement,
  List<Rect> bones,
) {
  final failures = <String>[];
  final lines = textFragments(root, rootElement);
  for (final line in lines) {
    final covered = bones.any((bone) {
      final middle = bone.center.dy;
      return bone.left <= line.left + tolerance &&
          bone.right >= line.right - tolerance &&
          middle >= line.top &&
          middle <= line.bottom;
    });
    if (!covered) failures.add('uncovered line at $line');
  }

  final drawable = [...lines];
  for (final element in find.byType(Expect).evaluate()) {
    final expect = element.widget as Expect;
    final area = rectIn(root, element.findRenderObject()! as RenderBox);
    switch (expect.expected) {
      case Expected.block:
        drawable.add(area);
        final match = bones.any(
          (b) =>
              (b.left - area.left).abs() <= tolerance &&
              (b.right - area.right).abs() <= tolerance &&
              (b.top - area.top).abs() <= tolerance &&
              (b.bottom - area.bottom).abs() <= tolerance,
        );
        if (!match) {
          failures.add('no block for ${expect.child.runtimeType} at $area');
        }
      case Expected.lines:
        final expected = lineCount(textFragments(root, element));
        final inside = bones.where((b) => area.contains(b.center)).length;
        if (inside != expected) {
          failures.add(
            '${expect.child.runtimeType} has $inside bars for $expected lines',
          );
        }
      case Expected.clipped:
        final inside = bones.where((b) => b.overlaps(area)).toList();
        if (inside.isEmpty) failures.add('nothing drawn in $area');
        if (inside.any(
          (b) =>
              b.left < area.left - tolerance ||
              b.right > area.right + tolerance ||
              b.top < area.top - tolerance ||
              b.bottom > area.bottom + tolerance,
        )) {
          failures.add('bone spills out of $area');
        }
    }
  }
  final strays = bones
      .where((b) => !drawable.any((d) => d.overlaps(b)))
      .toList();
  if (strays.isNotEmpty) {
    failures.add('${strays.length} bone(s) over nothing: $strays');
  }
  return failures;
}

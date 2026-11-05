import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'bones.dart';
import 'hints.dart';

/// Measures laid-out content into bones, the way skullet measures the DOM:
/// a bar for each line of text, a block for each image, icon, control or
/// chip, and painted surfaces such as cards kept as they are.
///
/// [root] is the element of the content; it must be laid out. Bones are in
/// the coordinates of its render box.
List<Bone> measureBones(Element root, {double textRadius = 4}) {
  final box = root.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return const [];
  return _Measure(box, textRadius).run(root);
}

/// Text runs closer than this, in font sizes, are one label.
const double _labelGap = 0.4;

class _Measure {
  _Measure(this.root, this.textRadius);

  final RenderBox root;
  final double textRadius;
  final List<Bone> bones = [];
  int _piece = 0;

  List<Bone> run(Element element) {
    _visit(element, null, null, null);
    return bones;
  }

  Rect _rectOf(RenderObject object, [Rect? local]) {
    final box = object as RenderBox;
    return MatrixUtils.transformRect(
      box.getTransformTo(root),
      local ?? Offset.zero & box.size,
    );
  }

  /// Clips [rect] to [clip]; null when what's left is a sliver nobody sees.
  Rect? _visible(Rect rect, Rect? clip) {
    final shown = clip == null ? rect : rect.intersect(clip);
    return shown.width >= 2 && shown.height >= 2 ? shown : null;
  }

  void _add(
    BoneKind kind,
    Rect? rect,
    BorderRadius radius, {
    Decoration? decoration,
    double fontSize = 0,
    Rect? unit,
    int? piece,
  }) {
    if (rect == null) return;
    bones.add(
      Bone(
        kind,
        rect,
        radius: radius,
        decoration: decoration,
        piece: piece ?? _piece++,
        fontSize: fontSize,
        unit: unit,
      ),
    );
  }

  void _visit(
    Element element,
    Rect? clip,
    BorderRadius? clipRadius,
    Rect? unit,
  ) {
    final widget = element.widget;
    final object = element is RenderObjectElement ? element.renderObject : null;
    if (object is RenderBox && !object.hasSize) return;
    if (widget is SkeletonIgnore) return;

    unit = _unitOf(element) ?? unit;

    // Hints and widgets that are one block whatever they hold.
    if (widget is SkeletonBlock ||
        widget is Icon ||
        widget is ImageIcon ||
        widget is Image ||
        widget is InputDecorator ||
        widget is Checkbox ||
        widget is Switch ||
        widget is Radio ||
        widget is Slider ||
        widget is CircularProgressIndicator ||
        widget is LinearProgressIndicator) {
      final found = element.findRenderObject();
      if (found is RenderBox && found.hasSize && found.attached) {
        var rect = _rectOf(found);
        var radius = clipRadius ?? BorderRadius.zero;
        if (widget is SkeletonBlock && widget.radius != null) {
          radius = widget.radius!;
        } else if (widget is Icon || widget is ImageIcon) {
          final size = math.min(rect.width, rect.height);
          rect = Rect.fromCenter(
            center: rect.center,
            width: size,
            height: size,
          );
          radius = BorderRadius.circular(size * 0.2);
        } else if (widget is Switch || widget is Radio || widget is Checkbox) {
          radius = BorderRadius.circular(rect.shortestSide / 2);
        } else if (widget is InputDecorator) {
          radius = BorderRadius.circular(4);
        }
        _add(
          BoneKind.block,
          _visible(rect, clip),
          _within(radius, rect, clip, clipRadius),
          unit: unit,
        );
      }
      return;
    }

    if (object is RenderOffstage && object.offstage) return;
    if (object is RenderOpacity && object.opacity == 0) return;
    if (object is RenderAnimatedOpacity && object.opacity.value == 0) return;
    if (object is RenderSkeletonBox) {
      _add(
        BoneKind.block,
        _visible(_rectOf(object), clip),
        object.radius ?? BorderRadius.circular(textRadius),
        unit: unit,
      );
      return;
    }

    if (object is RenderParagraph) {
      _lines(object, clip, unit);
      return;
    }

    if (object is RenderImage) {
      _add(
        BoneKind.block,
        _visible(_rectOf(object), clip),
        clipRadius ?? BorderRadius.zero,
        unit: unit,
      );
      return;
    }

    // Painted boxes: a box around at most one label (a button, a chip, an
    // avatar) fills as a block; anything holding more keeps its surface.
    final paint = widget is ColoredBox
        ? (widget.color.a > 0
              ? _BoxPaint(
                  fills: true,
                  radius: BorderRadius.zero,
                  decoration: BoxDecoration(color: widget.color),
                )
              : null)
        : _paintOf(object);
    if (paint != null) {
      final rect = _rectOf(element.findRenderObject()!);
      final labels = _labels(element);
      if (labels <= 1 && paint.fills) {
        final radius = paint.radius == BorderRadius.zero
            ? (clipRadius ?? paint.radius)
            : paint.radius;
        _add(BoneKind.block, _visible(rect, clip), radius, unit: unit);
        return;
      }
      if (paint.decoration != null) {
        _add(
          BoneKind.surface,
          rect,
          paint.radius,
          decoration: paint.decoration,
          unit: unit,
        );
      }
      final inner = paint.clips
          ? (clip == null ? rect : rect.intersect(clip))
          : clip;
      element.visitChildElements(
        (child) =>
            _visit(child, inner, paint.clips ? paint.radius : clipRadius, unit),
      );
      return;
    }

    // Clips narrow what can be seen, and lend media their corners.
    var innerClip = clip;
    var innerRadius = clipRadius;
    if (object is RenderClipRect ||
        object is RenderClipRRect ||
        object is RenderClipOval ||
        object is RenderClipPath) {
      final rect = _rectOf(object!);
      innerClip = clip == null ? rect : rect.intersect(clip);
      if (object is RenderClipOval) {
        innerRadius = BorderRadius.circular(rect.shortestSide / 2);
      } else if (object is RenderClipRRect) {
        innerRadius = object.borderRadius.resolve(TextDirection.ltr);
      } else if (object is RenderClipPath &&
          object.clipper is ShapeBorderClipper) {
        innerRadius = _radiusOfShape(
          (object.clipper! as ShapeBorderClipper).shape,
          rect,
        );
      }
    }
    element.visitChildElements(
      (child) => _visit(child, innerClip, innerRadius, unit),
    );
  }

  /// A block that fills a rounded clip of the same size takes its corners.
  BorderRadius _within(
    BorderRadius own,
    Rect rect,
    Rect? clip,
    BorderRadius? clipRadius,
  ) {
    if (clip == null || clipRadius == null || own != BorderRadius.zero) {
      return own;
    }
    final same =
        (clip.left - rect.left).abs() < 1 &&
        (clip.top - rect.top).abs() < 1 &&
        (clip.right - rect.right).abs() < 1 &&
        (clip.bottom - rect.bottom).abs() < 1;
    return same ? clipRadius : own;
  }

  /// A row of a list or a card of a grid: an ancestor with two or more
  /// siblings built from the same widget.
  Rect? _unitOf(Element element) {
    final parent = _parentOf(element);
    if (parent == null) return null;
    var alike = 0;
    parent.visitChildElements((sibling) {
      if (sibling.widget.runtimeType == element.widget.runtimeType) alike++;
    });
    if (alike < 3) return null;
    final object = element.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    return _rectOf(object);
  }

  Element? _parentOf(Element element) {
    Element? parent;
    element.visitAncestorElements((ancestor) {
      parent = ancestor;
      return false;
    });
    return parent;
  }

  void _lines(RenderParagraph paragraph, Rect? clip, Rect? unit) {
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final fontSize = _fontSize(paragraph);
    final own = _rectOf(paragraph);
    final shown = clip == null ? own : own.intersect(clip);
    final radius = BorderRadius.circular(textRadius);
    final piece = _piece++;
    if (text.trim().isEmpty) {
      // An empty text still stands for a line of it.
      final width = paragraph.size.width > 0
          ? paragraph.size.width * 0.6
          : fontSize * 8;
      final height = fontSize * 1.15;
      _add(
        BoneKind.text,
        _visible(_rectOf(paragraph, Rect.fromLTWH(0, 0, width, height)), clip),
        radius,
        fontSize: fontSize,
        unit: unit,
        piece: piece,
      );
      return;
    }
    // Tight boxes: each run from the font's ascent to its descent.
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final lines = <Rect>[];
    for (final box in boxes) {
      final rect = box.toRect().intersect(Offset.zero & paragraph.size);
      if (rect.width < 1 || rect.height < 1) continue;
      final i = lines.indexWhere(
        (line) =>
            (line.center.dy - rect.center.dy).abs() < rect.height / 2 &&
            rect.left - line.right < fontSize * _labelGap &&
            line.left - rect.right < fontSize * _labelGap,
      );
      if (i == -1) {
        lines.add(rect);
      } else {
        lines[i] = lines[i].expandToInclude(rect);
      }
    }
    for (final line in lines) {
      _add(
        BoneKind.text,
        _visible(_rectOf(paragraph, line).intersect(shown), null),
        radius,
        fontSize: fontSize,
        unit: unit,
        piece: piece,
      );
    }
  }

  double _fontSize(RenderParagraph paragraph) {
    double? size;
    paragraph.text.visitChildren((span) {
      if (span is TextSpan && span.style?.fontSize != null) {
        size = math.max(size ?? 0, span.style!.fontSize!);
      }
      return true;
    });
    return paragraph.textScaler.scale(size ?? 14);
  }

  /// Text labels and media under [element], counting text runs that sit
  /// side by side as one label, stopping at two.
  int _labels(Element element) {
    final runs = <(Rect, double)>[];
    var media = 0;
    void visit(Element child) {
      if (media + runs.length > 8) return;
      final widget = child.widget;
      if (widget is SkeletonIgnore) return;
      if (widget is Icon || widget is Image || widget is ImageIcon) {
        media++;
        return;
      }
      final object = child is RenderObjectElement ? child.renderObject : null;
      if (object is RenderParagraph && object.hasSize) {
        if (object.text.toPlainText().trim().isNotEmpty) {
          runs.add((_rectOf(object), _fontSize(object)));
        }
        return;
      }
      if (object is RenderImage) {
        media++;
        return;
      }
      child.visitChildElements(visit);
    }

    element.visitChildElements(visit);
    // Runs beside each other on one line are pieces of one label.
    final labels = <Rect>[];
    for (final (rect, size) in runs) {
      final i = labels.indexWhere(
        (label) =>
            (label.center.dy - rect.center.dy).abs() < rect.height / 2 &&
            rect.left - label.right < size * _labelGap &&
            label.left - rect.right < size * _labelGap,
      );
      if (i == -1) {
        labels.add(rect);
      } else {
        labels[i] = labels[i].expandToInclude(rect);
      }
    }
    return labels.length + media;
  }
}

class _BoxPaint {
  const _BoxPaint({
    required this.fills,
    required this.radius,
    this.decoration,
    this.clips = false,
  });

  /// Paints a fill (colour, gradient or image), not only an outline.
  final bool fills;
  final BorderRadius radius;
  final Decoration? decoration;
  final bool clips;
}

/// What a render object paints as a box, if anything.
_BoxPaint? _paintOf(RenderObject? object) {
  if (object is RenderDecoratedBox &&
      object.position == DecorationPosition.background) {
    final decoration = object.decoration;
    if (decoration is BoxDecoration) {
      final fills =
          (decoration.color != null && decoration.color!.a > 0) ||
          decoration.gradient != null ||
          decoration.image != null;
      final outlined =
          decoration.border != null && decoration.border!.isUniform;
      final divider =
          decoration.border != null && !decoration.border!.isUniform;
      if (!fills && !outlined && !divider && decoration.boxShadow == null) {
        return null;
      }
      final size = (object as RenderBox).size;
      final radius = decoration.shape == BoxShape.circle
          ? BorderRadius.circular(size.shortestSide / 2)
          : decoration.borderRadius?.resolve(TextDirection.ltr) ??
                BorderRadius.zero;
      return _BoxPaint(fills: fills, radius: radius, decoration: decoration);
    }
    if (decoration is ShapeDecoration) {
      final fills =
          (decoration.color != null && decoration.color!.a > 0) ||
          decoration.gradient != null;
      final size = (object as RenderBox).size;
      return _BoxPaint(
        fills: fills,
        radius: _radiusOfShape(decoration.shape, Offset.zero & size),
        decoration: decoration,
      );
    }
    return null;
  }
  if (object is RenderPhysicalShape) {
    if (object.color.a == 0) return null;
    final rect = Offset.zero & object.size;
    final clipper = object.clipper;
    final radius = clipper is ShapeBorderClipper
        ? _radiusOfShape(clipper.shape, rect)
        : BorderRadius.zero;
    final shape = clipper is ShapeBorderClipper
        ? clipper.shape
        : const RoundedRectangleBorder();
    return _BoxPaint(
      fills: true,
      radius: radius,
      decoration: ShapeDecoration(color: object.color, shape: shape),
      clips: object.clipBehavior != Clip.none,
    );
  }
  if (object is RenderPhysicalModel) {
    if (object.color.a == 0) return null;
    final size = object.size;
    final radius = object.shape == BoxShape.circle
        ? BorderRadius.circular(size.shortestSide / 2)
        : object.borderRadius ?? BorderRadius.zero;
    return _BoxPaint(
      fills: true,
      radius: radius,
      decoration: BoxDecoration(
        color: object.color,
        borderRadius: radius,
        shape: object.shape,
      ),
      clips: object.clipBehavior != Clip.none,
    );
  }
  return null;
}

BorderRadius _radiusOfShape(ShapeBorder shape, Rect rect) {
  if (shape is RoundedRectangleBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr);
  }
  if (shape is RoundedSuperellipseBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr);
  }
  if (shape is ContinuousRectangleBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr);
  }
  if (shape is StadiumBorder || shape is CircleBorder) {
    return BorderRadius.circular(rect.shortestSide / 2);
  }
  return BorderRadius.zero;
}

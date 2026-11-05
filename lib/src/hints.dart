import 'package:flutter/widgets.dart';

import 'bones.dart';
import 'environment.dart';
import 'shimmering.dart';
import 'theme.dart';

/// Draws its child as one block in a skeleton.
class SkeletonBlock extends StatelessWidget {
  /// Creates a block hint.
  const SkeletonBlock({super.key, this.radius, required this.child});

  /// Corners of the block; a rounded clip around it lends its own otherwise.
  final BorderRadius? radius;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Draws nothing for its child in a skeleton.
class SkeletonIgnore extends StatelessWidget {
  /// Creates an ignore hint.
  const SkeletonIgnore({super.key, required this.child});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Shows [skeleton] in place of [child] while a skeleton is measured: for
/// things that don't measure well, like a logo, a chart or a canvas.
class SkeletonReplace extends StatelessWidget {
  /// Creates a replacement hint.
  const SkeletonReplace({
    super.key,
    required this.skeleton,
    required this.child,
  });

  /// Measured in place of [child]. A [SkeletonBox] usually.
  final Widget skeleton;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SkeletonScope.inSkeleton(context) ? skeleton : child;
}

/// Marks a subtree as being measured for a skeleton.
class SkeletonScope extends InheritedWidget {
  /// Creates the scope.
  const SkeletonScope({super.key, required super.child});

  /// Whether [context] is being laid out to measure a skeleton.
  static bool inSkeleton(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkeletonScope>() != null;

  @override
  bool updateShouldNotify(SkeletonScope oldWidget) => false;
}

/// One placeholder box that joins the shared shimmer and follows the theme.
class SkeletonBox extends LeafRenderObjectWidget {
  /// Creates a box. [width] defaults to 60% of the space, [height] to the
  /// ambient font size, [radius] to the theme's.
  const SkeletonBox({super.key, this.width, this.height, this.radius});

  /// Width in logical pixels.
  final double? width;

  /// Height in logical pixels.
  final double? height;

  /// Corners.
  final BorderRadius? radius;

  @override
  RenderSkeletonBox createRenderObject(BuildContext context) {
    final provider = SkulletProvider.of(context);
    return RenderSkeletonBox(
      width: width,
      height: height ?? DefaultTextStyle.of(context).style.fontSize ?? 14,
      radius: radius,
      theme: provider.theme,
      colors: provider.colorsOf(context),
      still: motionReduced(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSkeletonBox renderObject,
  ) {
    final provider = SkulletProvider.of(context);
    renderObject
      ..width = width
      ..height = height ?? DefaultTextStyle.of(context).style.fontSize ?? 14
      ..radius = radius
      ..theme = provider.theme
      ..colors = provider.colorsOf(context)
      ..still = motionReduced(context);
  }
}

/// Render object of [SkeletonBox].
class RenderSkeletonBox extends RenderBox with Shimmering {
  /// Creates it.
  RenderSkeletonBox({
    double? width,
    required double height,
    this.radius,
    required SkulletTheme theme,
    required SkeletonColors colors,
    required bool still,
  }) : _width = width,
       _height = height,
       _theme = theme,
       _colors = colors,
       _still = still;

  double? _width;
  set width(double? value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  /// Corners.
  BorderRadius? radius;

  SkulletTheme _theme;
  @override
  SkulletTheme get theme => _theme;
  set theme(SkulletTheme value) {
    _theme = value;
    markNeedsPaint();
  }

  SkeletonColors _colors;
  @override
  SkeletonColors get colors => _colors;
  set colors(SkeletonColors value) {
    _colors = value;
    markNeedsPaint();
  }

  bool _still;
  @override
  bool get still => _still;
  set still(bool value) {
    _still = value;
    markNeedsPaint();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width =
        _width ??
        (constraints.hasBoundedWidth ? constraints.maxWidth * 0.6 : 100);
    return constraints.constrain(Size(width, _height));
  }

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    paintShimmering(context, offset, [
      Bone(
        BoneKind.block,
        Offset.zero & size,
        radius: radius ?? BorderRadius.circular(theme.radius),
      ),
    ]);
  }
}

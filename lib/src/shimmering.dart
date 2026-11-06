import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'bones.dart';
import 'environment.dart';
import 'paint.dart';
import 'theme.dart';

/// A render box that paints bones with the shared animation, scheduling a
/// frame for itself only while something moves.
mixin Shimmering on RenderBox {
  int? _callback;
  SkulletTheme? _theme;
  SkeletonColors? _colors;
  bool _still = false;

  /// The theme to paint with.
  SkulletTheme get theme => _theme!;
  set theme(SkulletTheme value) {
    final old = _theme;
    _theme = value;
    if (old != null && old.radius != value.radius) textRadiusChanged();
    markNeedsPaint();
  }

  /// Colours for the current brightness.
  SkeletonColors get colors => _colors!;
  set colors(SkeletonColors value) {
    _colors = value;
    markNeedsPaint();
  }

  /// Holds the skeleton still.
  bool get still => _still;
  set still(bool value) {
    if (value == _still) return;
    _still = value;
    markNeedsPaint();
  }

  /// Called when [theme] gives text bars new corners, so anything measured
  /// with the old ones can be measured again.
  void textRadiusChanged() {}

  @override
  void detach() {
    _cancel();
    super.detach();
  }

  void _cancel() {
    if (_callback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_callback!);
      _callback = null;
    }
  }

  /// Asks for another frame, once.
  void scheduleNextFrame() {
    if (_callback != null || !attached) return;
    _callback = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _callback = null;
      if (attached) markNeedsPaint();
    });
  }

  /// The paint for this frame; schedules the next one when it moves.
  BonePaint bonePaint() {
    final paint = BonePaint(
      theme: theme,
      colors: colors,
      clock: frameClock,
      still: still,
    );
    if (paint.animates && animationsAllowed) scheduleNextFrame();
    return paint;
  }

  /// Paints [bones] at [offset] with the shared animation.
  void paintShimmering(
    PaintingContext context,
    Offset offset,
    List<Bone> bones, {
    double opacity = 1,
    double Function(int)? boneOpacity,
  }) {
    bonePaint().paint(
      context.canvas,
      bones,
      origin: offset,
      screen: localToGlobal(Offset.zero),
      size: size,
      opacity: opacity,
      boneOpacity: boneOpacity,
    );
  }
}

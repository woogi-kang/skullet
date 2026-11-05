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

  /// The theme to paint with.
  SkulletTheme get theme;

  /// Colours for the current brightness.
  SkeletonColors get colors;

  /// Holds the skeleton still.
  bool get still;

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

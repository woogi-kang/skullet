import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'bones.dart';
import 'theme.dart';

/// The highlight's slant from vertical: a diagonal, top right to bottom left.
const double slant = 20 * math.pi / 180;

/// The direction across the slant.
final Offset slantNormal = Offset(math.cos(slant), math.sin(slant));

/// A shimmer keeps the pace it has across a screen this wide.
const double _referenceWidth = 1280;

/// The highlight's width, so it doesn't grow heavier on a wide screen.
const double _band = 320;

/// Bands follow each other this many band-widths apart.
const double _spacing = 2.5;

/// Where across the band the highlight is brightest.
const double _peak = 0.85;

/// Stops per eased ramp: enough to read as one curve with no banding.
const int steps = 12;

/// Cosine easing, 0 to 1.
double ease(double t) => (1 - math.cos(math.pi * t.clamp(0, 1))) / 2;

/// How a frame of skeleton is painted.
class BonePaint {
  /// Creates the paint for one frame.
  const BonePaint({
    required this.theme,
    required this.colors,
    required this.clock,
    required this.still,
  });

  /// The theme.
  final SkulletTheme theme;

  /// Its colours for the current brightness.
  final SkeletonColors colors;

  /// The shared frame clock.
  final Duration clock;

  /// Hold still: reduced motion, or a test.
  final bool still;

  /// Whether painting this needs a new frame every frame.
  bool get animates => !still && theme.animation != SkeletonAnimation.none;

  double get _phase {
    final period = theme.period.inMicroseconds;
    return (clock.inMicroseconds % period) / period;
  }

  /// Paints [bones] with their top left at [origin] on [canvas]. [screen] is
  /// where [origin] sits on screen, so the shimmer is placed by screen
  /// position and every skeleton shares one stream. [opacity] fades the whole
  /// skeleton; [boneOpacity] fades bone by bone.
  void paint(
    Canvas canvas,
    List<Bone> bones, {
    required Offset origin,
    required Offset screen,
    required Size size,
    double opacity = 1,
    double Function(int index)? boneOpacity,
  }) {
    if (opacity <= 0) return;
    Shader? shine;
    var pulse = 1.0;
    if (animates) {
      switch (theme.animation) {
        case SkeletonAnimation.shimmer:
          shine = _stream(origin - screen);
        case SkeletonAnimation.groupShimmer:
          shine = _stream(origin);
        case SkeletonAnimation.pulse:
          pulse = 0.55 + 0.45 * (1 + math.cos(2 * math.pi * _phase)) / 2;
        case SkeletonAnimation.none:
          break;
      }
    }
    for (var i = 0; i < bones.length; i++) {
      final bone = bones[i];
      final alpha = opacity * (boneOpacity?.call(i) ?? 1);
      if (alpha <= 0) continue;
      final rect = bone.rect.shift(origin);
      if (bone.kind == BoneKind.surface) {
        final decoration = bone.decoration;
        if (decoration == null) continue;
        if (alpha < 1) {
          canvas.saveLayer(
            rect.inflate(2),
            Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
          );
        }
        decoration
            .createBoxPainter(() {})
            .paint(canvas, rect.topLeft, ImageConfiguration(size: rect.size));
        if (alpha < 1) canvas.restore();
        continue;
      }
      final rrect = bone.radius.toRRect(rect);
      final base = colors.base;
      canvas.drawRRect(
        rrect,
        Paint()..color = base.withValues(alpha: base.a * alpha * pulse),
      );
      if (shine != null) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = shine
            ..color = Color.fromRGBO(0, 0, 0, alpha),
        );
      }
    }
  }

  /// The repeating highlight, drawn so that [zero] (in canvas coordinates)
  /// is the stream's origin.
  Shader _stream(Offset zero) {
    final period = _band * _spacing;
    // Pace: one loop crosses the reference width.
    final travelled = _phase * (_referenceWidth + period);
    final at = travelled % period;
    final from = zero + slantNormal * (at - period);
    final highlight = colors.highlight;
    final stops = <double>[];
    final shades = <Color>[];
    void stop(double at, double alpha) {
      stops.add(at * _band / period);
      shades.add(highlight.withValues(alpha: highlight.a * alpha));
    }

    for (var i = 0; i <= steps; i++) {
      stop(i / steps * _peak, ease(i / steps));
    }
    for (var i = 1; i <= steps; i++) {
      stop(_peak + i / steps * (1 - _peak), ease(1 - i / steps));
    }
    stops.add(1);
    shades.add(highlight.withValues(alpha: 0));
    return ui.Gradient.linear(
      from,
      from + slantNormal * period,
      shades,
      stops,
      TileMode.repeated,
    );
  }
}

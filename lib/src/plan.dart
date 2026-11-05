import 'dart:math' as math;
import 'dart:ui';

import 'bones.dart';
import 'paint.dart';
import 'theme.dart';

/// A skeleton up for less than this is a flash: smart holds it back.
const skeletonDelay = Duration(milliseconds: 150);

/// One piece's fade.
const fadeDuration = Duration(milliseconds: 200);

/// From the first piece of a sequence to the last.
const cascadeSpread = Duration(milliseconds: 320);

/// A refetch, already familiar.
const quickFade = Duration(milliseconds: 120);

/// Smaller text follows the text it sits under.
const secondaryDelay = Duration(milliseconds: 60);

/// Reveals landing this close share one order, and one sweep front.
const batchWindow = Duration(milliseconds: 150);

/// The most a sweep takes across the reveal that starts it.
const waveSpread = Duration(milliseconds: 360);

/// The most a sweep takes across a reveal that joins one under way.
const sweepSpread = Duration(milliseconds: 600);

/// A sweep bigger than this many screens crossfades instead.
const maxSweepArea = 1.5;

/// The longest an image keeps its own skeleton after a reveal.
const imageTimeout = Duration(seconds: 10);

/// What a reveal knows as its content lands.
class RevealContext {
  /// Creates the context.
  const RevealContext({
    required this.waited,
    required this.input,
    required this.refetch,
    required this.height,
    required this.pieces,
  });

  /// How long the skeleton was up.
  final Duration waited;

  /// Someone scrolled, dragged or typed just now.
  final bool input;

  /// The skeleton was drawn over data already on screen.
  final bool refetch;

  /// The content's height.
  final double height;

  /// How many pieces the content arrives in.
  final int pieces;
}

/// The reveal mode `smart` resolves to for [context].
RevealMode choose(RevealMode mode, RevealContext context) {
  if (mode != RevealMode.smart && mode != RevealMode.sweep) return mode;
  if (context.input || context.waited < skeletonDelay) {
    return RevealMode.instant;
  }
  if (context.refetch) return RevealMode.together;
  if (mode == RevealMode.sweep) return RevealMode.sweep;
  return context.height < 72 || context.pieces <= 3
      ? RevealMode.together
      : RevealMode.smart;
}

/// The delay of each content piece and each skeleton bone in a sequence.
class Cascade {
  Cascade._(this.pieceDelay, this.boneDelay, this.duration);

  /// Delay per content piece number; null brings it in at once.
  final Map<int, Duration?> pieceDelay;

  /// Delay per skeleton bone index.
  final List<Duration?> boneDelay;

  /// The whole cascade, last fade included.
  final Duration duration;

  /// Opacity of something with [delay] at [elapsed].
  static double opacityAt(Duration? delay, Duration elapsed) {
    if (delay == null) return 1;
    return ease((elapsed - delay).inMicroseconds / fadeDuration.inMicroseconds);
  }

  /// Plans a cascade. [content] and [skeleton] bones are in the reveal's own
  /// coordinates; [screenTop] is the reveal's top on screen. [byRow] times
  /// whole rows by their place on screen, main text first (smart); otherwise
  /// each piece goes by its place in the reveal (sequence).
  factory Cascade.plan({
    required List<Bone> content,
    required List<Bone> skeleton,
    required Size size,
    required double screenTop,
    required double screenHeight,
    required bool byRow,
    Duration late = Duration.zero,
  }) {
    Duration? at(Rect rect, Rect? unit, bool secondary) {
      if (!byRow) {
        final down = rect.top / math.max(size.height, 1);
        final across = rect.left / math.max(size.width, 1);
        return cascadeSpread * (down * 0.8 + across * 0.2).clamp(0, 1);
      }
      bool onScreen(Rect r) =>
          r.bottom + screenTop > 0 && r.top + screenTop < screenHeight;
      if (unit == null) return onScreen(rect) ? Duration.zero : null;
      if (!onScreen(unit)) return null;
      final top = ((unit.top + screenTop) / screenHeight).clamp(0.0, 1.0);
      final delay = cascadeSpread * top - late;
      return (delay.isNegative ? Duration.zero : delay) +
          (secondary ? secondaryDelay : Duration.zero);
    }

    double unitFont(Rect? unit, List<Bone> bones) {
      var size = 0.0;
      for (final bone in bones) {
        if (bone.unit == unit) size = math.max(size, bone.fontSize);
      }
      return size;
    }

    final pieceDelay = <int, Duration?>{};
    final pieces = <int, Rect>{};
    final pieceBones = <int, Bone>{};
    for (final bone in content) {
      if (bone.kind == BoneKind.surface) continue;
      pieces.update(
        bone.piece,
        (r) => r.expandToInclude(bone.rect),
        ifAbsent: () => bone.rect,
      );
      pieceBones.putIfAbsent(bone.piece, () => bone);
    }
    for (final entry in pieces.entries) {
      final bone = pieceBones[entry.key]!;
      final secondary =
          bone.fontSize > 0 && bone.fontSize < unitFont(bone.unit, content);
      pieceDelay[entry.key] = at(entry.value, bone.unit, secondary);
    }
    final boneDelay = <Duration?>[];
    for (final bone in skeleton) {
      if (bone.kind == BoneKind.surface) {
        boneDelay.add(null);
        continue;
      }
      final unit = bone.unit;
      final secondary =
          bone.fontSize > 0 && bone.fontSize < unitFont(unit, skeleton) * 0.95;
      boneDelay.add(at(bone.rect, unit, secondary));
    }
    var last = Duration.zero;
    for (final delay in [...pieceDelay.values, ...boneDelay]) {
      if (delay != null && delay > last) last = delay;
    }
    return Cascade._(pieceDelay, boneDelay, last + fadeDuration);
  }
}

/// Timing of a sweep front shared by reveals that land together.
class SweepTiming {
  /// Creates a timing.
  const SweepTiming(this.delay, this.duration);

  /// When the front reaches this reveal.
  final Duration delay;

  /// How long it takes across.
  final Duration duration;

  static Duration _start = const Duration(days: -1);
  static double _origin = 0;
  static double _speed = 1;

  /// A point's position across the slant, in px.
  static double u(Offset p) => p.dx * slantNormal.dx + p.dy * slantNormal.dy;

  /// Times the front across [screenRect] at [now], joining a front already
  /// under way when it hasn't reached this reveal yet. [shimmerPeriod] sets
  /// the pace: the front runs at twice the shimmer's.
  static SweepTiming plan(
    Rect screenRect,
    Duration now,
    Duration shimmerPeriod,
  ) {
    final corners = [
      screenRect.topLeft,
      screenRect.topRight,
      screenRect.bottomLeft,
      screenRect.bottomRight,
    ].map(u);
    final from = corners.reduce(math.min);
    final to = corners.reduce(math.max);
    final pace = (1280 + 800) / shimmerPeriod.inMilliseconds; // px per ms
    final elapsed = (now - _start).inMicroseconds / 1000;
    final joined =
        elapsed <= batchWindow.inMilliseconds &&
        (from - _origin) / _speed >= elapsed &&
        (to - _origin) / _speed - elapsed <= sweepSpread.inMilliseconds;
    if (!joined) {
      _start = now;
      _origin = from;
      _speed = math.max(2 * pace, (to - from) / waveSpread.inMilliseconds);
    }
    final since = (now - _start).inMicroseconds / 1000;
    final delay = (from - _origin) / _speed - since;
    final duration = (to - from) / _speed;
    return SweepTiming(
      Duration(microseconds: (math.max(delay, 0) * 1000).round()),
      Duration(microseconds: (duration * 1000).round()),
    );
  }

  /// Forgets the front under way, for tests.
  static void reset() => _start = const Duration(days: -1);
}

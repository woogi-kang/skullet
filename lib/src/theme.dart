import 'package:flutter/widgets.dart';

/// Colours of a skeleton.
@immutable
class SkeletonColors {
  /// Creates colours.
  const SkeletonColors({required this.base, required this.highlight});

  /// The default light colours: a faint shade with a white highlight.
  static const light = SkeletonColors(
    base: Color(0x12000000),
    highlight: Color(0x99FFFFFF),
  );

  /// The default dark colours.
  static const dark = SkeletonColors(
    base: Color(0x14FFFFFF),
    highlight: Color(0x1AFFFFFF),
  );

  /// The skeleton's fill.
  final Color base;

  /// The highlight sweeping across it.
  final Color highlight;

  @override
  bool operator ==(Object other) =>
      other is SkeletonColors &&
      other.base == base &&
      other.highlight == highlight;

  @override
  int get hashCode => Object.hash(base, highlight);
}

/// How skeletons move.
enum SkeletonAnimation {
  /// One highlight sweeps the whole screen; every skeleton shares it.
  shimmer,

  /// Each skeleton gets a sweep of its own, in the same phase.
  groupShimmer,

  /// Every skeleton fades softly in and out.
  pulse,

  /// Skeletons hold still.
  none,
}

/// How quickly the animation loops.
enum SkeletonSpeed {
  /// A shimmer in 4s, a pulse in 2.4s.
  slow,

  /// A shimmer in 2s, a pulse in 1.2s.
  fast,
}

/// Which colours to use.
enum SkulletMode {
  /// Light colours.
  light,

  /// Dark colours.
  dark,

  /// Follows the platform brightness.
  system,
}

/// How content replaces its skeleton.
enum RevealMode {
  /// Decides for each reveal: at once for a fast load or during a gesture, a
  /// quick crossfade for a refetch, whole for something small, otherwise row
  /// by row.
  smart,

  /// Crossfades the whole skeleton into the content.
  together,

  /// Brings each piece in where its skeleton was, top to bottom.
  sequence,

  /// Uncovers the content behind a slanted front at the shimmer's angle.
  sweep,

  /// Swaps at once.
  instant,
}

/// How skeletons look and move.
@immutable
class SkulletTheme {
  /// Creates a theme.
  const SkulletTheme({
    this.light = SkeletonColors.light,
    this.dark = SkeletonColors.dark,
    this.animation = SkeletonAnimation.shimmer,
    this.speed = SkeletonSpeed.slow,
    this.radius = 4,
  });

  /// Colours on a light background.
  final SkeletonColors light;

  /// Colours on a dark background.
  final SkeletonColors dark;

  /// How skeletons move.
  final SkeletonAnimation animation;

  /// How quickly.
  final SkeletonSpeed speed;

  /// Corner radius of each line of text, in logical pixels. Images, chips and
  /// controls keep their own.
  final double radius;

  /// One loop of the animation.
  Duration get period => switch ((animation, speed)) {
    (SkeletonAnimation.pulse, SkeletonSpeed.slow) => const Duration(
      milliseconds: 2400,
    ),
    (SkeletonAnimation.pulse, SkeletonSpeed.fast) => const Duration(
      milliseconds: 1200,
    ),
    (_, SkeletonSpeed.slow) => const Duration(milliseconds: 4000),
    (_, SkeletonSpeed.fast) => const Duration(milliseconds: 2000),
  };

  /// A copy with the given fields replaced.
  SkulletTheme copyWith({
    SkeletonColors? light,
    SkeletonColors? dark,
    SkeletonAnimation? animation,
    SkeletonSpeed? speed,
    double? radius,
  }) => SkulletTheme(
    light: light ?? this.light,
    dark: dark ?? this.dark,
    animation: animation ?? this.animation,
    speed: speed ?? this.speed,
    radius: radius ?? this.radius,
  );

  @override
  bool operator ==(Object other) =>
      other is SkulletTheme &&
      other.light == light &&
      other.dark == dark &&
      other.animation == animation &&
      other.speed == speed &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(light, dark, animation, speed, radius);
}

/// Sets up skeletons for everything below it.
class SkulletProvider extends InheritedWidget {
  /// Creates a provider.
  const SkulletProvider({
    super.key,
    this.theme = const SkulletTheme(),
    this.mode = SkulletMode.system,
    this.reveal = RevealMode.smart,
    this.debug = false,
    required super.child,
  });

  /// How skeletons look and move.
  final SkulletTheme theme;

  /// Which colours to use.
  final SkulletMode mode;

  /// How content replaces its skeleton.
  final RevealMode reveal;

  /// Outlines every skeleton with where its shape came from, then whether
  /// the content moved anything when it arrived.
  final bool debug;

  /// The nearest provider's settings, or the defaults.
  static SkulletProvider of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkulletProvider>() ??
      const SkulletProvider(child: SizedBox.shrink());

  /// The colours for [context], following [mode].
  SkeletonColors colorsOf(BuildContext context) => switch (mode) {
    SkulletMode.light => theme.light,
    SkulletMode.dark => theme.dark,
    SkulletMode.system =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
          ? theme.dark
          : theme.light,
  };

  @override
  bool updateShouldNotify(SkulletProvider oldWidget) =>
      theme != oldWidget.theme ||
      mode != oldWidget.mode ||
      reveal != oldWidget.reveal ||
      debug != oldWidget.debug;
}

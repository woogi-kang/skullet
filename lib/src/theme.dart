// Needed on Flutter 3.32, whose widgets library does not export it.
// ignore: unnecessary_import
import 'dart:ui' show Brightness;

import 'package:flutter/material.dart';

import 'shapes.dart';

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

  /// Colours for high contrast ([MediaQuery.highContrast]): the fill twice as
  /// strong, so the outline of what is loading can be made out.
  SkeletonColors get highContrast => SkeletonColors(
    base: base.withValues(alpha: (base.a * 2).clamp(0.0, 1.0)),
    highlight: highlight,
  );

  /// Blends [a] into [b].
  static SkeletonColors lerp(SkeletonColors a, SkeletonColors b, double t) =>
      SkeletonColors(
        base: Color.lerp(a.base, b.base, t)!,
        highlight: Color.lerp(a.highlight, b.highlight, t)!,
      );

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

  /// Follows the brightness the app shows where the skeleton is, read from
  /// the colour of the text around it: light text sits on a dark surface.
  /// Falls back to the platform brightness when there is no text colour.
  ///
  /// An app with only a light theme stays light on a system in dark mode.
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
///
/// Give it to a [SkulletProvider], or set it alongside the rest of your
/// theme, where it blends when the theme changes:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: const [SkulletTheme(radius: 6)]),
///   darkTheme: ThemeData.dark().copyWith(
///     extensions: const [SkulletTheme(animation: SkeletonAnimation.pulse)],
///   ),
/// )
/// ```
///
/// A provider's theme wins over the one in [ThemeData.extensions].
@immutable
class SkulletTheme extends ThemeExtension<SkulletTheme> {
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
  @override
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

  /// Blends colours and corners; the animation and speed switch halfway.
  @override
  SkulletTheme lerp(covariant SkulletTheme? other, double t) {
    if (other == null) return this;
    return SkulletTheme(
      light: SkeletonColors.lerp(light, other.light, t),
      dark: SkeletonColors.lerp(dark, other.dark, t),
      animation: t < 0.5 ? animation : other.animation,
      speed: t < 0.5 ? speed : other.speed,
      radius: radius + (other.radius - radius) * t,
    );
  }

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
    this.store,
    this.label,
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

  /// Where skeletons below remember their shapes; [Skullet.store] when
  /// null. Give each signed-in account, or each test, a store of its own.
  final ShapeStore? store;

  /// Read to screen readers for a skeleton that has no label of its own,
  /// such as a localised "Loading". Nothing is read when both are null.
  final String? label;

  /// The nearest provider's settings. Without one, the defaults, with the
  /// [SkulletTheme] in [ThemeData.extensions] if there is one.
  static SkulletProvider of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<SkulletProvider>();
    if (provider != null) return provider;
    final theme = Theme.of(context).extension<SkulletTheme>();
    return theme == null
        ? const SkulletProvider(child: SizedBox.shrink())
        : SkulletProvider(theme: theme, child: const SizedBox.shrink());
  }

  /// The colours for [context], following [mode], stronger under high
  /// contrast.
  SkeletonColors colorsOf(BuildContext context) {
    final colors = switch (mode) {
      SkulletMode.light => theme.light,
      SkulletMode.dark => theme.dark,
      SkulletMode.system =>
        _brightnessOf(context) == Brightness.dark ? theme.dark : theme.light,
    };
    return (MediaQuery.maybeHighContrastOf(context) ?? false)
        ? colors.highContrast
        : colors;
  }

  /// The brightness of what surrounds [context]. The platform's setting
  /// alone isn't enough: an app without a dark theme stays light when the
  /// system goes dark, and dark bones on it would be invisible.
  static Brightness _brightnessOf(BuildContext context) {
    final text = DefaultTextStyle.of(context).style.color;
    if (text != null && text.a > 0) {
      return text.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light;
    }
    return MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
  }

  @override
  bool updateShouldNotify(SkulletProvider oldWidget) =>
      theme != oldWidget.theme ||
      mode != oldWidget.mode ||
      reveal != oldWidget.reveal ||
      debug != oldWidget.debug ||
      store != oldWidget.store ||
      label != oldWidget.label;
}

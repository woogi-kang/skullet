import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

import 'feed.dart';

/// Change one setting at a time and watch what it does to one post, with
/// the code that sets it.
class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key, required this.reloads});

  /// Bumped by the app bar's reload button.
  final Listenable reloads;

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _Palette {
  const _Palette(this.name, this.colors, this.code);
  final String name;
  final SkeletonColors colors;
  final String? code;
}

const _palettes = [
  _Palette('Default', SkeletonColors.light, null),
  _Palette(
    'Warm',
    SkeletonColors(base: Color(0x1F8A5A2B), highlight: Color(0xB3FFF6EA)),
    'SkeletonColors(base: Color(0x1F8A5A2B), highlight: Color(0xB3FFF6EA))',
  ),
  _Palette(
    'Indigo',
    SkeletonColors(base: Color(0x1F5B5BD6), highlight: Color(0xB3F4F4FF)),
    'SkeletonColors(base: Color(0x1F5B5BD6), highlight: Color(0xB3F4F4FF))',
  ),
];

class _OptionsPageState extends State<OptionsPage> {
  RevealMode reveal = RevealMode.sweep;
  SkeletonAnimation animation = SkeletonAnimation.shimmer;
  SkeletonSpeed speed = SkeletonSpeed.slow;
  double radius = 4;
  _Palette palette = _palettes.first;
  bool debug = false;
  bool holding = false;
  Post? post;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.reloads.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reloads.removeListener(_load);
    _timer?.cancel();
    super.dispose();
  }

  /// Shows the skeleton, then the post after a moment.
  void _load() {
    _timer?.cancel();
    setState(() => post = null);
    if (holding) return;
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => post = realPosts(1).first);
    });
  }

  void _hold(bool value) {
    setState(() => holding = value);
    if (value) {
      _timer?.cancel();
      setState(() => post = null);
    } else {
      _load();
    }
  }

  /// Changes a setting and replays the load so the change shows.
  void _set(VoidCallback change) {
    setState(change);
    _load();
  }

  String get _code {
    final theme = [
      if (animation != SkeletonAnimation.shimmer)
        'animation: SkeletonAnimation.${animation.name}',
      if (speed != SkeletonSpeed.slow) 'speed: SkeletonSpeed.${speed.name}',
      if (radius != 4) 'radius: ${radius.toStringAsFixed(0)}',
      if (palette.code != null) 'light: ${palette.code}',
    ];
    return [
      'SkulletProvider(',
      if (reveal != RevealMode.smart) '  reveal: RevealMode.${reveal.name},',
      if (debug) '  debug: true,',
      if (theme.isNotEmpty) ...[
        '  theme: SkulletTheme(',
        for (final line in theme) '    $line,',
        '  ),',
      ],
      '  child: MyApp(),',
      ')',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE6E6EE)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SkulletProvider(
              reveal: reveal,
              debug: debug,
              theme: SkulletTheme(
                light: palette.colors,
                animation: animation,
                speed: speed,
                radius: radius,
              ),
              child: Skeleton<Post>(
                data: post,
                sample: samplePosts.first,
                label: 'Loading post',
                builder: (context, post) => PostView(post: post),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.replay),
              label: const Text('Load again'),
            ),
            const Spacer(),
            const Text('Hold skeleton'),
            const SizedBox(width: 8),
            Switch(value: holding, onChanged: _hold),
          ],
        ),
        const SizedBox(height: 20),
        _Choice(
          label: 'reveal',
          help: 'How the content replaces the skeleton.',
          values: RevealMode.values,
          value: reveal,
          onChanged: (v) => _set(() => reveal = v),
        ),
        _Choice(
          label: 'animation',
          help: 'What the skeleton does while it waits.',
          values: SkeletonAnimation.values,
          value: animation,
          onChanged: (v) => _set(() => animation = v),
        ),
        _Choice(
          label: 'speed',
          help: 'How fast the shimmer or pulse goes.',
          values: SkeletonSpeed.values,
          value: speed,
          onChanged: (v) => _set(() => speed = v),
        ),
        _Choice(
          label: 'colours',
          help: 'The bones and the highlight that runs over them.',
          values: _palettes,
          value: palette,
          name: (p) => p.name,
          onChanged: (v) => _set(() => palette = v),
        ),
        Text('radius: ${radius.toStringAsFixed(0)}', style: _label(context)),
        Text('Corners of text bars.', style: _help(context)),
        Slider(
          value: radius,
          max: 12,
          divisions: 12,
          onChanged: (v) => setState(() => radius = v),
          onChangeEnd: (_) => _load(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('debug', style: _label(context)),
          subtitle: Text(
            "Outlines each skeleton, names where its shape came from, and "
            "turns red if the content didn't fit its space.",
            style: _help(context),
          ),
          value: debug,
          onChanged: (v) => _set(() => debug = v),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            _code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle? _label(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall?.copyWith(fontFamily: 'monospace');

TextStyle? _help(BuildContext context) => Theme.of(context).textTheme.bodySmall
    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.help,
    required this.values,
    required this.value,
    required this.onChanged,
    this.name,
  });

  final String label;
  final String help;
  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T value)? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _label(context)),
          Text(help, style: _help(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(name?.call(v) ?? (v as Enum).name),
                  selected: v == value,
                  onSelected: (_) => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

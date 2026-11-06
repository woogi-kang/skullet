import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

import 'api.dart';
import 'feed.dart';
import 'music.dart';
import 'options.dart';

export 'api.dart';

void main() => runApp(const DemoApp());

/// A light feed, a dark album page, and a page for trying each option. On
/// the web the URL sets the starting state, e.g.
/// `?tab=music&reveal=sweep&animation=pulse&debug=1`.
class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  static final _query = Uri.base.queryParameters;

  int tab = const [
    'feed',
    'music',
    'options',
  ].indexOf(_query['tab'] ?? '').clamp(0, 2);
  RevealMode reveal = RevealMode.values.firstWhere(
    (m) => m.name == _query['reveal'],
    orElse: () => RevealMode.smart,
  );
  SkeletonAnimation animation = SkeletonAnimation.values.firstWhere(
    (a) => a.name == _query['animation'],
    orElse: () => SkeletonAnimation.shimmer,
  );
  bool debug = _query['debug'] == '1';
  final reloads = _Reloads();

  bool get dark => tab == 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skullet',
      debugShowCheckedModeBanner: false,
      theme: dark ? _musicTheme : _feedTheme,
      home: SkulletProvider(
        reveal: reveal,
        debug: debug,
        mode: dark ? SkulletMode.dark : SkulletMode.light,
        theme: SkulletTheme(animation: animation),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(
                const ['Threadline', 'Library', 'Options'][tab],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  tooltip: 'Reload',
                  onPressed: reloads.bump,
                  icon: const Icon(Icons.refresh),
                ),
                if (tab != 2)
                  IconButton(
                    tooltip: 'Skeleton settings',
                    onPressed: () => _settings(context),
                    icon: const Icon(Icons.settings_outlined),
                  ),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: switch (tab) {
                  0 => FeedPage(key: const ValueKey('feed'), reloads: reloads),
                  1 => MusicPage(
                    key: const ValueKey('music'),
                    reloads: reloads,
                  ),
                  _ => OptionsPage(
                    key: const ValueKey('options'),
                    reloads: reloads,
                  ),
                },
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: Icon(Icons.dynamic_feed),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: Icon(Icons.album_outlined),
                  selectedIcon: Icon(Icons.album),
                  label: 'Music',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: 'Options',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _settings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // As tall as its choices, and scrolling on a short screen, rather than
      // capped at the default 9/16 of the screen and overflowing.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Choice<RevealMode>(
                  label: 'Reveal',
                  value: reveal,
                  values: RevealMode.values,
                  onChanged: (v) => update(() => reveal = v),
                ),
                _Choice<SkeletonAnimation>(
                  label: 'Animation',
                  value: animation,
                  values: SkeletonAnimation.values,
                  onChanged: (v) => update(() => animation = v),
                ),
                _Choice<int>(
                  label: 'Response time',
                  value: Api.latency.inMilliseconds,
                  values: const [80, 1200, 3000],
                  name: (ms) => ms < 1000 ? '${ms}ms' : '${ms / 1000}s',
                  onChanged: (v) =>
                      update(() => Api.latency = Duration(milliseconds: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Debug outlines'),
                  value: debug,
                  onChanged: (v) => update(() => debug = v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Reloads extends ChangeNotifier {
  void bump() => notifyListeners();
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.name,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String Function(T value)? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
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

final _feedTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5B5BD6),
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFFF7F7FA),
    indicatorColor: Color(0xFFE4E4FB),
  ),
);

final _musicTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: lime,
    brightness: Brightness.dark,
    primary: lime,
    onPrimary: const Color(0xFF0C0C10),
    surface: const Color(0xFF15151B),
  ),
  scaffoldBackgroundColor: const Color(0xFF15151B),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF15151B),
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFF0E0E12),
    indicatorColor: Color(0xFF2E3318),
  ),
);

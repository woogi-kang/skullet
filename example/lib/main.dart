import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  // Settable from the URL on the web, e.g. ?reveal=sweep&dark=1.
  RevealMode reveal = RevealMode.values.firstWhere(
    (m) => m.name == Uri.base.queryParameters['reveal'],
    orElse: () => RevealMode.smart,
  );
  SkeletonAnimation animation = SkeletonAnimation.values.firstWhere(
    (a) => a.name == Uri.base.queryParameters['animation'],
    orElse: () => SkeletonAnimation.shimmer,
  );
  bool dark = Uri.base.queryParameters['dark'] == '1';
  bool debug = Uri.base.queryParameters['debug'] == '1';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skullet',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: SkulletProvider(
        reveal: reveal,
        debug: debug,
        mode: dark ? SkulletMode.dark : SkulletMode.light,
        theme: SkulletTheme(animation: animation),
        child: DemoPage(
          controls: _Controls(
            reveal: reveal,
            animation: animation,
            dark: dark,
            debug: debug,
            onReveal: (v) => setState(() => reveal = v),
            onAnimation: (v) => setState(() => animation = v),
            onDark: (v) => setState(() => dark = v),
            onDebug: (v) => setState(() => debug = v),
          ),
        ),
      ),
    );
  }
}

/// Fake backend with an adjustable delay.
class Api {
  static Duration latency = const Duration(milliseconds: 1200);

  static Future<T> load<T>(T value) => Future.delayed(latency, () => value);
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, required this.controls});
  final Widget controls;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  User? user;
  List<Message>? inbox;
  List<Stat>? stats;
  List<Photo>? photos;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final mine = ++generation;
    setState(() {
      user = null;
      inbox = null;
      stats = null;
      photos = null;
    });
    final results = await Future.wait([
      Api.load(realUser),
      Api.load(realInbox),
      Api.load(realStats),
      Api.load(realPhotos(mine)),
    ]);
    if (!mounted || mine != generation) return;
    setState(() {
      user = results[0] as User;
      inbox = results[1] as List<Message>;
      stats = results[2] as List<Stat>;
      photos = results[3] as List<Photo>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('skullet'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          widget.controls,
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Skeleton<User>(
                    id: 'profile',
                    data: user,
                    sample: sampleUser,
                    label: 'Loading profile',
                    builder: (context, user) => ProfileCard(user: user),
                  ),
                  const SizedBox(height: 16),
                  Skeleton<List<Stat>>(
                    id: 'stats',
                    data: stats,
                    sample: sampleStats,
                    builder: (context, stats) => StatTiles(stats: stats),
                  ),
                  const SizedBox(height: 16),
                  Skeleton<List<Message>>(
                    id: 'inbox',
                    data: inbox,
                    sample: sampleInbox,
                    label: 'Loading messages',
                    builder: (context, inbox) => Inbox(messages: inbox),
                  ),
                  const SizedBox(height: 16),
                  Skeleton<List<Photo>>(
                    id: 'photos',
                    data: photos,
                    sample: samplePhotos,
                    builder: (context, photos) => Gallery(photos: photos),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.reveal,
    required this.animation,
    required this.dark,
    required this.debug,
    required this.onReveal,
    required this.onAnimation,
    required this.onDark,
    required this.onDebug,
  });

  final RevealMode reveal;
  final SkeletonAnimation animation;
  final bool dark;
  final bool debug;
  final ValueChanged<RevealMode> onReveal;
  final ValueChanged<SkeletonAnimation> onAnimation;
  final ValueChanged<bool> onDark;
  final ValueChanged<bool> onDebug;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<RevealMode>(
          value: reveal,
          onChanged: (v) => onReveal(v!),
          items: [
            for (final m in RevealMode.values)
              DropdownMenuItem(value: m, child: Text('reveal: ${m.name}')),
          ],
        ),
        DropdownButton<SkeletonAnimation>(
          value: animation,
          onChanged: (v) => onAnimation(v!),
          items: [
            for (final a in SkeletonAnimation.values)
              DropdownMenuItem(value: a, child: Text('animation: ${a.name}')),
          ],
        ),
        StatefulBuilder(
          builder: (context, setState) => DropdownButton<int>(
            value: Api.latency.inMilliseconds,
            onChanged: (v) =>
                setState(() => Api.latency = Duration(milliseconds: v!)),
            items: const [
              DropdownMenuItem(value: 80, child: Text('response: 80ms')),
              DropdownMenuItem(value: 1200, child: Text('response: 1.2s')),
              DropdownMenuItem(value: 3000, child: Text('response: 3s')),
            ],
          ),
        ),
        FilterChip(
          label: const Text('dark'),
          selected: dark,
          onSelected: onDark,
        ),
        FilterChip(
          label: const Text('debug'),
          selected: debug,
          onSelected: onDebug,
        ),
      ],
    );
  }
}

// Data ---------------------------------------------------------------------

class User {
  const User(this.name, this.handle, this.bio);
  final String name;
  final String handle;
  final String bio;
}

const sampleUser = User(
  'Sample Name',
  '@samplehandle',
  'A short bio that wraps over two lines of text, roughly as long as a real one tends to be.',
);
const realUser = User(
  'Ada Lovelace',
  '@ada',
  'Wrote the first published algorithm for a machine, and saw that it could do far more than arithmetic.',
);

class Message {
  const Message(this.from, this.subject, this.time);
  final String from;
  final String subject;
  final String time;
}

const sampleInbox = [
  Message('Sender name', 'A subject line of typical length', '9m'),
  Message('Sender', 'A shorter subject', '1h'),
  Message('Sender name', 'Another subject line, a little longer', '3h'),
  Message('Sender', 'Subject', '1d'),
];
const realInbox = [
  Message('Charles Babbage', 'Notes on the Analytical Engine', '4m'),
  Message('Mary Somerville', 'Dinner on Thursday?', '52m'),
  Message('Michael Faraday', 'The lecture went well, thank you', '2h'),
  Message('Lord Byron', 'Re: Greece', '1d'),
];

class Stat {
  const Stat(this.label, this.value);
  final String label;
  final String value;
}

const sampleStats = [
  Stat('Label', '00,000'),
  Stat('Label', '0,000'),
  Stat('Label', '0.0%'),
];
const realStats = [
  Stat('Revenue', r'$12,480'),
  Stat('Users', '1,204'),
  Stat('Churn', '2.1%'),
];

class Photo {
  const Photo(this.caption, this.hue, this.delay);
  final String caption;
  final double hue;
  final Duration delay;
}

const samplePhotos = [
  Photo('A caption', 0, Duration.zero),
  Photo('A caption', 0, Duration.zero),
];
List<Photo> realPhotos(int seed) {
  final random = math.Random(seed);
  return [
    Photo(
      'Sunrise over the harbour',
      20,
      Duration(milliseconds: 400 + random.nextInt(1600)),
    ),
    Photo('Low tide', 200, Duration(milliseconds: 400 + random.nextInt(1600))),
  ];
}

// Widgets ------------------------------------------------------------------

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        user.handle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(onPressed: () {}, child: const Text('Follow')),
              ],
            ),
            const SizedBox(height: 12),
            Text(user.bio),
          ],
        ),
      ),
    );
  }
}

class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.stats});
  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (i, stat) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.label, style: const TextStyle(fontSize: 12)),
                    Text(
                      stat.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class Inbox extends StatelessWidget {
  const Inbox({super.key, required this.messages});
  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final m in messages)
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(m.from),
              subtitle: Text(m.subject),
              trailing: Text(m.time, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class Gallery extends StatelessWidget {
  const Gallery({super.key, required this.photos});
  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, photo) in photos.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image(
                      image: SlowImage(photo.hue, photo.delay),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(photo.caption),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A generated picture that takes [delay] to "download", to show an image
/// keeping its own skeleton after the reveal.
@immutable
class SlowImage extends ImageProvider<SlowImage> {
  const SlowImage(this.hue, this.delay);
  final double hue;
  final Duration delay;

  @override
  Future<SlowImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(SlowImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load());

  Future<ImageInfo> _load() async {
    await Future<void>.delayed(delay);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 300);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(400, 300), [
          HSLColor.fromAHSL(1, hue, 0.7, 0.6).toColor(),
          HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.35).toColor(),
        ]),
    );
    canvas.drawCircle(
      const Offset(300, 90),
      40,
      Paint()..color = const Color(0xCCFFFFFF),
    );
    final image = await recorder.endRecording().toImage(400, 300);
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is SlowImage && other.hue == hue && other.delay == delay;

  @override
  int get hashCode => Object.hash(hue, delay);
}

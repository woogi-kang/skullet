import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

import 'api.dart';
import 'slow_image.dart';

const lime = Color(0xFFD9FF5C);
const _muted = Color(0xFFA3A3AD);

/// A dark album page: cover and title, then the track list.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key, required this.reloads});

  /// Bumped by the app bar's reload button.
  final Listenable reloads;

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  Album? album;
  List<Track>? tracks;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    widget.reloads.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reloads.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final mine = ++generation;
    setState(() {
      album = null;
      tracks = null;
    });
    final (a, t) = await (Api.load(realAlbum), Api.load(realTracks)).wait;
    if (!mounted || mine != generation) return;
    setState(() {
      album = a;
      tracks = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Skeleton<Album>(
          id: 'album',
          data: album,
          sample: sampleAlbum,
          label: 'Loading album',
          builder: (context, album) => AlbumHeader(album: album),
        ),
        const SizedBox(height: 12),
        Skeleton<List<Track>>(
          id: 'tracks',
          data: tracks,
          sample: sampleTracks,
          label: 'Loading tracks',
          builder: (context, tracks) =>
              Column(children: [for (final t in tracks) TrackRow(track: t)]),
        ),
      ],
    );
  }
}

// Data ---------------------------------------------------------------------

class Album {
  const Album(this.title, this.artist, this.year, this.count, this.cover);
  final String title;
  final String artist;
  final String year;
  final int count;
  final SlowImage cover;
}

const sampleAlbum = Album(
  'Album title',
  'Artist',
  '2026',
  9,
  SlowImage(Art.rings, [Colors.grey, Colors.grey, Colors.grey], Duration.zero),
);
const realAlbum = Album(
  'Night Signals',
  'Low Orbit',
  '2026',
  9,
  SlowImage(Art.rings, [
    Color(0xFF3B2F6B),
    Color(0xFF5A4A9C),
    lime,
  ], Duration(milliseconds: 900)),
);

class Track {
  const Track(this.number, this.title, this.length);
  final int number;
  final String title;
  final String length;
}

const sampleTracks = [
  Track(1, 'Track title', '0:00'),
  Track(2, 'Track', '0:00'),
  Track(3, 'A longer track title', '0:00'),
  Track(4, 'Title', '0:00'),
  Track(5, 'Track title here', '0:00'),
  Track(6, 'Track title', '0:00'),
  Track(7, 'Track', '0:00'),
];
const realTracks = [
  Track(1, 'Carrier Wave', '3:42'),
  Track(2, 'Static Bloom', '4:10'),
  Track(3, 'Under the Antenna', '3:58'),
  Track(4, 'Parallax', '2:51'),
  Track(5, 'Slow Telemetry', '5:04'),
  Track(6, 'Night Signals', '4:27'),
  Track(7, 'Afterglow', '3:15'),
];

// Widgets ------------------------------------------------------------------

class AlbumHeader extends StatelessWidget {
  const AlbumHeader({super.key, required this.album});
  final Album album;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 140,
                child: Image(image: album.cover, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALBUM · ${album.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${album.artist} · ${album.count} tracks',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC4C4CC),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            // One pill in the skeleton, though it holds an icon and a label.
            SkeletonBlock(
              radius: BorderRadius.circular(22),
              child: FilledButton.icon(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: const Color(0xFF0C0C10),
                  minimumSize: const Size(120, 44),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              tooltip: 'Shuffle',
              onPressed: () {},
              icon: const Icon(Icons.shuffle),
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              tooltip: 'Save',
              onPressed: () {},
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${track.number}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A95)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'Low Orbit',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Text(
            track.length,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }
}

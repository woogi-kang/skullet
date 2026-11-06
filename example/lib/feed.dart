import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

import 'api.dart';
import 'slow_image.dart';

const _accent = Color(0xFF5B5BD6);
const _muted = Color(0xFF6B6B76);
const _rule = Color(0xFFF0F0F4);

/// A light social feed: stories, then posts with text and pictures.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.reloads});

  /// Bumped by the app bar's reload button.
  final Listenable reloads;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Story>? stories;
  List<Post>? posts;
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
      stories = null;
      posts = null;
    });
    final (s, p) = await (
      Api.load(realStories),
      Api.load(realPosts(mine)),
    ).wait;
    if (!mounted || mine != generation) return;
    setState(() {
      stories = s;
      posts = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Skeleton<List<Story>>(
          id: 'stories',
          data: stories,
          sample: sampleStories,
          label: 'Loading stories',
          builder: (context, stories) => StoryRow(stories: stories),
        ),
        const Divider(height: 1, color: _rule),
        Skeleton<List<Post>>(
          id: 'posts',
          data: posts,
          sample: samplePosts,
          label: 'Loading posts',
          builder: (context, posts) => Column(
            children: [for (final post in posts) PostView(post: post)],
          ),
        ),
      ],
    );
  }
}

// Data ---------------------------------------------------------------------

class Story {
  const Story(this.name, this.color);
  final String name;
  final Color color;
}

const sampleStories = [
  Story('Name', Colors.grey),
  Story('Name', Colors.grey),
  Story('Name', Colors.grey),
  Story('Name', Colors.grey),
  Story('Name', Colors.grey),
];
const realStories = [
  Story('Ada', Color(0xFFE7D8FF)),
  Story('Grace', Color(0xFFD6ECFF)),
  Story('Alan', Color(0xFFFFE2D1)),
  Story('Hedy', Color(0xFFD9F2E3)),
  Story('Linus', Color(0xFFFFF1C7)),
];

class Post {
  const Post({
    required this.name,
    required this.meta,
    required this.avatar,
    required this.text,
    required this.likes,
    required this.replies,
    this.picture,
  });
  final String name;
  final String meta;
  final Color avatar;
  final String text;
  final String likes;
  final String replies;
  final SlowImage? picture;
}

const _placeholder = SlowImage(Art.hills, [
  Colors.grey,
  Colors.grey,
  Colors.grey,
], Duration.zero);

/// Shaped like a typical page of the feed, three posts with two pictures, so
/// the first load's skeleton takes the space the posts will.
const samplePosts = [
  Post(
    name: 'Sample name',
    meta: '@handle · 2h',
    avatar: Colors.grey,
    text: 'A post of typical length, long enough to wrap onto a second line.',
    likes: '000',
    replies: '00',
    picture: _placeholder,
  ),
  Post(
    name: 'Sample name',
    meta: '@handle · 4h',
    avatar: Colors.grey,
    text: 'A post of typical length, long enough to wrap onto a second line.',
    likes: '000',
    replies: '00',
  ),
  Post(
    name: 'Sample name',
    meta: '@handle · 5h',
    avatar: Colors.grey,
    text: 'A post of typical length, long enough to wrap onto a second line.',
    likes: '000',
    replies: '00',
    picture: _placeholder,
  ),
];

List<Post> realPosts(int seed) {
  final random = math.Random(seed);
  Duration delay() => Duration(milliseconds: 400 + random.nextInt(1400));
  return [
    Post(
      name: 'Grace Hopper',
      meta: '@grace · 2h',
      avatar: const Color(0xFFD6ECFF),
      text: 'Found the bug. It was, quite literally, a moth in relay 70.',
      likes: '1.2k',
      replies: '84',
      picture: SlowImage(Art.hills, const [
        Color(0xFFDDE3F6),
        Color(0xFF8E9BD8),
        Color(0xFFFFC98B),
      ], delay()),
    ),
    const Post(
      name: 'Hedy Lamarr',
      meta: '@hedy · 4h',
      avatar: Color(0xFFD9F2E3),
      text:
          'Hop between frequencies fast enough and nobody can jam the '
          'signal. Patent filed.',
      likes: '640',
      replies: '27',
    ),
    Post(
      name: 'Alan Turing',
      meta: '@alan · 5h',
      avatar: const Color(0xFFFFE2D1),
      text:
          'Can machines think? Asking for a friend who keeps beating me at '
          'chess.',
      likes: '892',
      replies: '41',
      picture: SlowImage(Art.dunes, const [
        Color(0xFFFBEADB),
        Color(0xFFF0B98D),
        Color(0xFFDB8A5E),
      ], delay()),
    ),
  ];
}

// Widgets ------------------------------------------------------------------

class StoryRow extends StatelessWidget {
  const StoryRow({super.key, required this.stories});
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          for (final story in stories)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  // One round block in the skeleton, not a ring around one.
                  SkeletonBlock(
                    radius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(3),
                      decoration: const ShapeDecoration(
                        shape: CircleBorder(
                          side: BorderSide(color: _accent, width: 2),
                        ),
                      ),
                      child: ClipOval(child: ColoredBox(color: story.color)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    story.name,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PostView extends StatelessWidget {
  const PostView({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final picture = post.picture;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 40,
                    child: ColoredBox(color: post.avatar),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      post.meta,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF2B2B33),
              ),
            ),
            if (picture != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image(image: picture, fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 18, color: _muted),
                const SizedBox(width: 6),
                Text(post.likes, style: _count),
                const SizedBox(width: 18),
                const Icon(Icons.chat_bubble_outline, size: 18, color: _muted),
                const SizedBox(width: 6),
                Text(post.replies, style: _count),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _count = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: _muted,
  );
}

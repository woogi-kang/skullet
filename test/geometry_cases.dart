// The geometry cases of skullet's own test suite (packages/test-cases),
// rebuilt as Flutter widgets. Expectations are marked with [Expect].
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

/// What a marked widget should be drawn as.
enum Expected { block, lines, clipped }

/// Marks [child] with what its skeleton should be.
class Expect extends StatelessWidget {
  const Expect(this.expected, this.child, {super.key});
  final Expected expected;
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class GeometryCase {
  const GeometryCase(this.label, this.description, this.width, this.build);
  final String label;
  final String description;
  final double width;
  final WidgetBuilder build;
}

Widget _avatar() => Expect(
  Expected.block,
  ClipOval(
    child: Image.memory(_pixel, width: 40, height: 40, fit: BoxFit.cover),
  ),
);

/// A 1x1 PNG.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, //
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _chip(String label, {Color color = const Color(0xFFEEEEEE)}) => Expect(
  Expected.block,
  DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(label),
    ),
  ),
);

final geometryCases = <GeometryCase>[
  GeometryCase(
    'Profile card',
    'A card keeps its surface; avatar, lines and chip get bones.',
    360,
    (_) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCCCCCC)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _avatar(),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expect(Expected.lines, Text('Lochie Axon')),
                  SizedBox(height: 2),
                  Expect(
                    Expected.lines,
                    Text('@lochieaxon', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const Spacer(),
              _chip('Follow', color: const Color(0xFF222222)),
            ],
          ),
        ),
      );
    },
  ),
  GeometryCase(
    'Chip split into pieces',
    'A chip whose one label is split across many widgets, as a text morph renders it, is still one block.',
    200,
    (_) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Expect(
          Expected.block,
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x264ADE80),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final c in '+1.64%'.split('')) Text(c)],
              ),
            ),
          ),
        ),
      );
    },
  ),
  GeometryCase(
    'Header over a divider',
    'A rule along one side divides rather than paints: the avatar and name inside get bones of their own.',
    300,
    (_) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _avatar(),
              const SizedBox(width: 10),
              const Expect(Expected.lines, Text('Alex')),
            ],
          ),
        ),
      );
    },
  ),
  GeometryCase(
    'Wrapped bubble',
    'A painted bubble whose one label wraps onto two lines is still one label, so one block.',
    200,
    (_) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Expect(
          Expected.block,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('Did the skeleton just guess my bubble widths?'),
              ),
            ),
          ),
        ),
      );
    },
  ),
  GeometryCase(
    'Wrapping paragraph',
    'One bar per line, each as wide as its line.',
    240,
    (_) {
      return const Expect(
        Expected.lines,
        Text(
          'Skeletons should follow the content they stand in for, line by line, so nothing moves when it arrives.',
          style: TextStyle(height: 1.5),
        ),
      );
    },
  ),
  GeometryCase(
    'Inline runs',
    'Text split across inline spans on one line is one bar.',
    400,
    (_) {
      return const Expect(
        Expected.lines,
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Posted by '),
              TextSpan(
                text: 'Jack',
                style: TextStyle(color: Colors.blue),
              ),
              TextSpan(text: ' in '),
              TextSpan(
                text: 'Design',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' · 3h'),
            ],
          ),
        ),
      );
    },
  ),
  GeometryCase(
    'Centered heading',
    'Bars follow centered text rather than the box around it.',
    360,
    (_) {
      return const SizedBox(
        width: double.infinity,
        child: Expect(
          Expected.lines,
          Text(
            'A centered title',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28),
          ),
        ),
      );
    },
  ),
  GeometryCase(
    'Article',
    'Heading, wrapped body and a button, each at its own size.',
    320,
    (_) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expect(
            Expected.lines,
            Text('Designing for the wait', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 8),
          const Expect(
            Expected.lines,
            Text(
              'Loading states are the first thing people see, and the thing they see most often on a slow connection.',
              style: TextStyle(height: 1.6),
            ),
          ),
          const SizedBox(height: 8),
          Expect(
            Expected.block,
            FilledButton(
              // The block is the button as painted; its larger tap target is not.
              style: FilledButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {},
              child: const Text('Read more'),
            ),
          ),
        ],
      );
    },
  ),
  GeometryCase(
    'List rows',
    "Icons are blocks; each row's title and meta get their own bars.",
    320,
    (_) {
      return Column(
        children: [
          for (final (i, title) in [
            'Invoice paid',
            'New comment',
            'Deploy finished',
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Expect(Expected.block, Icon(Icons.circle, size: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Expect(Expected.lines, Text(title)),
                    ),
                  ),
                  Expect(
                    Expected.lines,
                    Text('${i + 2}m ago', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  ),
  GeometryCase(
    'Chips',
    'Each painted chip around a single label is one block.',
    360,
    (_) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in ['Design', 'Engineering', 'Research']) _chip(l),
        ],
      );
    },
  ),
  GeometryCase(
    'Stat tiles',
    'Tiles with two labels keep their surface; their text gets bars.',
    360,
    (_) {
      return Row(
        children: [
          for (final (i, tile) in [
            'Revenue|\$12,480',
            'Users|1,204',
            'Churn|2.1%',
          ].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expect(
                        Expected.lines,
                        Text(
                          tile.split('|')[0],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expect(
                        Expected.lines,
                        Text(
                          tile.split('|')[1],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
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
    },
  ),
  GeometryCase(
    'Form',
    'Controls are blocks at their own size; labels are bars.',
    320,
    (_) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expect(Expected.lines, Text('Email')),
          const SizedBox(height: 6),
          const Expect(
            Expected.block,
            InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text('ada@example.com'),
            ),
          ),
          const SizedBox(height: 6),
          const Expect(Expected.lines, Text('Message')),
          const SizedBox(height: 6),
          const Expect(
            Expected.block,
            TextField(
              maxLines: 3,
              decoration: InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 6),
          Expect(Expected.block, Switch(value: true, onChanged: (_) {})),
        ],
      );
    },
  ),
  GeometryCase(
    'Media card',
    'An image sized by aspect ratio is one block above its caption.',
    300,
    (_) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expect(
            Expected.block,
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(_pixel, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Expect(Expected.lines, Text('Sunrise over the harbour')),
        ],
      );
    },
  ),
  GeometryCase('Table', "Every cell's text is a bar.", 320, (_) {
    Widget cell(String text, {bool right = false, bool head = false}) => Expect(
      Expected.lines,
      Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: head ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
    );
    return Table(
      children: [
        TableRow(
          children: [
            cell('Name', head: true),
            cell('Amount', right: true, head: true),
          ],
        ),
        TableRow(children: [cell('Coffee'), cell('\$4.50', right: true)]),
        TableRow(children: [cell('Lunch'), cell('\$12.00', right: true)]),
      ],
    );
  }),
  GeometryCase(
    'Truncated text',
    'Text cut off by an ellipsis is drawn only as far as it shows.',
    200,
    (_) {
      return const Expect(
        Expected.clipped,
        Text(
          'A preview far too long to fit on the one line it is given',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    },
  ),
  GeometryCase(
    'Sized empty box',
    'A box sized into a dot keeps its size, though it holds no text.',
    240,
    (_) {
      return const Row(
        children: [
          Expect(
            Expected.block,
            SizedBox(
              width: 12,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expect(Expected.lines, Text('Deploy finished')),
        ],
      );
    },
  ),
  GeometryCase(
    'Hints',
    '`SkeletonBlock` forces a block; `SkeletonIgnore` draws nothing.',
    320,
    (_) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expect(
            Expected.block,
            SkeletonBlock(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Drawn'), Text(' as one')],
              ),
            ),
          ),
          SizedBox(height: 8),
          SkeletonIgnore(child: Text('Not drawn at all')),
        ],
      );
    },
  ),
];

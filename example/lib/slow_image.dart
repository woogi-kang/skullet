import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The pictures the demo draws for itself, so it needs no network.
enum Art { hills, dunes, rings }

/// A generated picture that takes [delay] to "download", to show an image
/// keeping its own skeleton after the content has come in.
@immutable
class SlowImage extends ImageProvider<SlowImage> {
  const SlowImage(this.art, this.palette, this.delay);

  final Art art;

  /// Background, then two shapes.
  final List<Color> palette;
  final Duration delay;

  @override
  Future<SlowImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(SlowImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load());

  Future<ImageInfo> _load() async {
    await Future<void>.delayed(delay);
    const size = Size(600, 400);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final [ground, first, second] = palette;
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    switch (art) {
      case Art.hills:
        canvas.drawCircle(const Offset(460, 110), 46, Paint()..color = second);
        canvas.drawPath(
          Path()
            ..moveTo(0, 300)
            ..quadraticBezierTo(170, 190, 340, 290)
            ..quadraticBezierTo(470, 360, 600, 260)
            ..lineTo(600, 400)
            ..lineTo(0, 400)
            ..close(),
          Paint()..color = first,
        );
      case Art.dunes:
        for (var i = 0; i < 3; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(0, 220.0 + i * 60)
              ..cubicTo(
                200,
                160.0 + i * 60,
                380,
                300.0 + i * 50,
                600,
                210.0 + i * 60,
              )
              ..lineTo(600, 400)
              ..lineTo(0, 400)
              ..close(),
            Paint()..color = (i.isEven ? first : second),
          );
        }
      case Art.rings:
        final rings = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = first;
        for (var r = 40.0; r < 400; r += 36) {
          canvas.drawCircle(const Offset(420, 300), r, rings);
        }
        canvas.drawCircle(const Offset(420, 300), 22, Paint()..color = second);
    }
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is SlowImage &&
      other.art == art &&
      listEquals(other.palette, palette) &&
      other.delay == delay;

  @override
  int get hashCode => Object.hash(art, Object.hashAll(palette), delay);
}

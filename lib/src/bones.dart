import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// What a [Bone] stands for.
enum BoneKind {
  /// One line of text.
  text,

  /// An image, icon, control or chip, drawn as one block.
  block,

  /// A painted surface, such as a card, drawn as it is.
  surface,
}

/// One measured piece of a skeleton, in the coordinates of the measured root.
@immutable
class Bone {
  /// Creates a bone.
  const Bone(
    this.kind,
    this.rect, {
    this.radius = BorderRadius.zero,
    this.decoration,
    this.piece = 0,
    this.fontSize = 0,
    this.unit,
  });

  /// What it stands for.
  final BoneKind kind;

  /// Where it is.
  final Rect rect;

  /// Its corners.
  final BorderRadius radius;

  /// For a [BoneKind.surface], the decoration painted as it is.
  final Decoration? decoration;

  /// Bones of one piece of content (the lines of one paragraph, say) share
  /// this number, so a reveal can bring them in together.
  final int piece;

  /// The font size of a line of text; 0 for anything else.
  final double fontSize;

  /// The row or card this bone sits in: the nearest ancestor with two or
  /// more siblings like it. Null when there is none.
  final Rect? unit;

  /// The layout of this bone, without its decoration, for storing.
  Map<String, Object?> toJson() => {
    'k': kind.index,
    'r': [rect.left, rect.top, rect.width, rect.height],
    'c': [
      radius.topLeft.x,
      radius.topRight.x,
      radius.bottomRight.x,
      radius.bottomLeft.x,
    ],
    'p': piece,
    'f': fontSize,
    if (unit != null) 'u': [unit!.left, unit!.top, unit!.width, unit!.height],
  };

  /// Reads a bone written by [toJson]. A stored surface comes back as a plain
  /// block outline, since decorations are not stored.
  static Bone fromJson(Map<String, Object?> json) {
    List<double> numbers(Object? value) =>
        (value! as List).map((n) => (n! as num).toDouble()).toList();
    final r = numbers(json['r']);
    final c = numbers(json['c']);
    final u = json['u'] == null ? null : numbers(json['u']);
    final kind = BoneKind.values[(json['k']! as num).toInt()];
    return Bone(
      kind,
      Rect.fromLTWH(r[0], r[1], r[2], r[3]),
      radius: BorderRadius.only(
        topLeft: Radius.circular(c[0]),
        topRight: Radius.circular(c[1]),
        bottomRight: Radius.circular(c[2]),
        bottomLeft: Radius.circular(c[3]),
      ),
      decoration: kind == BoneKind.surface
          ? BoxDecoration(
              border: Border.all(color: const Color(0x14000000)),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(c[0]),
                topRight: Radius.circular(c[1]),
                bottomRight: Radius.circular(c[2]),
                bottomLeft: Radius.circular(c[3]),
              ),
            )
          : null,
      piece: (json['p']! as num).toInt(),
      fontSize: (json['f']! as num).toDouble(),
      unit: u == null ? null : Rect.fromLTWH(u[0], u[1], u[2], u[3]),
    );
  }

  @override
  String toString() =>
      'Bone(${kind.name}, ${rect.left.toStringAsFixed(1)}, '
      '${rect.top.toStringAsFixed(1)}, ${rect.width.toStringAsFixed(1)} x '
      '${rect.height.toStringAsFixed(1)})';
}

/// A measured skeleton: the size of the content and its bones.
@immutable
class SkeletonShape {
  /// Creates a shape.
  const SkeletonShape(this.size, this.bones);

  /// The size of the content it was measured from.
  final Size size;

  /// Its bones, in paint order.
  final List<Bone> bones;

  /// The layout of this shape, for storing. Holds no text or media.
  Map<String, Object?> toJson() => {
    'w': size.width,
    'h': size.height,
    'b': [for (final bone in bones) bone.toJson()],
  };

  /// Reads a shape written by [toJson].
  static SkeletonShape fromJson(Map<String, Object?> json) => SkeletonShape(
    Size((json['w']! as num).toDouble(), (json['h']! as num).toDouble()),
    [
      for (final bone in json['b']! as List)
        Bone.fromJson((bone! as Map).cast<String, Object?>()),
    ],
  );
}

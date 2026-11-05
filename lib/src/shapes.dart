import 'bones.dart';

/// Where remembered shapes are kept between loads.
///
/// The default, [MemoryShapeStore], keeps them for the life of the app. To
/// keep them across launches, implement this over your own storage and save
/// [SkeletonShape.toJson]: it holds layout only, never text or media.
abstract class ShapeStore {
  /// Lets subclasses be constant.
  const ShapeStore();

  /// The shape stored under [key], if any.
  SkeletonShape? read(String key);

  /// Stores [shape] under [key].
  void write(String key, SkeletonShape shape);

  /// Forgets every shape.
  void clear();
}

/// Keeps shapes in memory.
class MemoryShapeStore implements ShapeStore {
  /// Creates an empty store.
  MemoryShapeStore();

  final Map<String, SkeletonShape> _shapes = {};

  @override
  SkeletonShape? read(String key) => _shapes[key];

  @override
  void write(String key, SkeletonShape shape) => _shapes[key] = shape;

  @override
  void clear() => _shapes.clear();
}

/// Global settings.
abstract final class Skullet {
  /// Where shapes are remembered. Replace before the first skeleton builds.
  static ShapeStore store = MemoryShapeStore();

  /// The data last shown under each id, for this run of the app only: a
  /// skeleton drawn from it is exact.
  static final Map<String, Object> lastData = {};
}

/// Forgets every remembered shape and the data last shown, as on sign-out:
/// otherwise the next person on the device would see the outline of the last
/// one's content.
void forgetShapes() {
  Skullet.store.clear();
  Skullet.lastData.clear();
}

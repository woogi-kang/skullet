import 'bones.dart';
import 'theme.dart' show SkulletProvider;

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
  /// skeleton drawn from it is exact. Holds the [lastDataLimit] ids shown
  /// most recently.
  static final Map<String, Object> lastData = {};

  /// How many ids [lastData] keeps, so a long session doesn't hold on to
  /// everything it ever showed.
  static int lastDataLimit = 64;

  /// Records [data] as the last shown under [id].
  static void remember(String id, Object data) {
    lastData.remove(id);
    lastData[id] = data;
    while (lastData.length > lastDataLimit) {
      lastData.remove(lastData.keys.first);
    }
  }
}

/// Forgets every remembered shape in [Skullet.store] and the data last
/// shown, as on sign-out: otherwise the next person on the device would see
/// the outline of the last one's content. A store given to a
/// [SkulletProvider] is cleared with its own [ShapeStore.clear].
void forgetShapes() {
  Skullet.store.clear();
  Skullet.lastData.clear();
}

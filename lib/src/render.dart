import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'bones.dart';
import 'environment.dart';
import 'measure.dart';
import 'paint.dart';
import 'plan.dart';
import 'shimmering.dart';
import 'theme.dart';

const _debugLoading = Color(0xFF3B82F6);
const _debugStill = Color(0xFF22C55E);
const _debugMoved = Color(0xFFEF4444);

void _debugOutline(Canvas canvas, Rect rect, Color color, String label) {
  canvas.drawRect(
    rect.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..color = color,
  );
  final text = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 10),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final tag = Rect.fromLTWH(
    rect.left,
    rect.top,
    text.width + 6,
    text.height + 2,
  );
  canvas.drawRect(tag, Paint()..color = color);
  text.paint(canvas, tag.topLeft + const Offset(3, 1));
  text.dispose();
}

/// The first child element of [element].
Element? _childOf(Element? element) {
  Element? child;
  element?.visitChildElements((e) => child ??= e);
  return child;
}

/// Lays its child out unseen and paints the child's bones instead.
class GhostLayer extends SingleChildRenderObjectWidget {
  /// Creates the ghost.
  const GhostLayer({
    super.key,
    required this.theme,
    required this.colors,
    required this.still,
    required this.hold,
    required this.onMeasured,
    required this.debugLabel,
    super.child,
  });

  /// The theme.
  final SkulletTheme theme;

  /// Its colours.
  final SkeletonColors colors;

  /// Hold still.
  final bool still;

  /// How long to wait before showing anything, so a fast load never flashes.
  final Duration hold;

  /// Called with each new measurement.
  final ValueChanged<SkeletonShape> onMeasured;

  /// Where the shape came from, for the debug overlay; null when off.
  final String? debugLabel;

  @override
  RenderGhost createRenderObject(BuildContext context) => RenderGhost(
    element: context as Element,
    theme: theme,
    colors: colors,
    still: still,
    hold: hold,
    onMeasured: onMeasured,
    debugLabel: debugLabel,
  );

  @override
  void updateRenderObject(BuildContext context, RenderGhost renderObject) {
    renderObject
      ..theme = theme
      ..colors = colors
      ..still = still
      ..hold = hold
      ..onMeasured = onMeasured
      ..debugLabel = debugLabel;
  }
}

/// Render object of [GhostLayer].
class RenderGhost extends RenderProxyBox with Shimmering {
  /// Creates it.
  RenderGhost({
    required this.element,
    required this.theme,
    required this.colors,
    required this.still,
    required this.hold,
    required this.onMeasured,
    required this.debugLabel,
  });

  /// Its element, to measure the child from.
  final Element element;

  @override
  SkulletTheme theme;

  @override
  SkeletonColors colors;

  @override
  bool still;

  /// See [GhostLayer.hold].
  Duration hold;

  /// See [GhostLayer.onMeasured].
  ValueChanged<SkeletonShape> onMeasured;

  /// See [GhostLayer.debugLabel].
  String? debugLabel;

  SkeletonShape? _shape;
  Duration? _shownAt;

  /// The last measurement.
  SkeletonShape? get shape => _shape;

  @override
  void performLayout() {
    super.performLayout();
    _shape = null; // Measured again on the next paint.
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    var shape = _shape;
    if (shape == null) {
      shape = _shape = SkeletonShape(
        Size(size.width, size.height),
        measureBones(_childOf(element)!, textRadius: theme.radius),
      );
      final measured = shape;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => onMeasured(measured),
      );
    }
    final now = frameClock;
    _shownAt ??= now;
    if (!still && now - _shownAt! < hold) {
      if (animationsAllowed) scheduleNextFrame();
    } else {
      paintShimmering(context, offset, shape.bones);
    }
    if (debugLabel != null) {
      _debugOutline(context.canvas, offset & size, _debugLoading, debugLabel!);
    }
  }
}

/// Paints a remembered shape as a skeleton.
class ShapeLayer extends LeafRenderObjectWidget {
  /// Creates the layer.
  const ShapeLayer({
    super.key,
    required this.shape,
    required this.theme,
    required this.colors,
    required this.still,
    required this.debugLabel,
  });

  /// The shape.
  final SkeletonShape shape;

  /// The theme.
  final SkulletTheme theme;

  /// Its colours.
  final SkeletonColors colors;

  /// Hold still.
  final bool still;

  /// For the debug overlay; null when off.
  final String? debugLabel;

  @override
  RenderShapeLayer createRenderObject(BuildContext context) =>
      RenderShapeLayer(shape, theme, colors, still, debugLabel);

  @override
  void updateRenderObject(BuildContext context, RenderShapeLayer renderObject) {
    renderObject
      ..shape = shape
      ..theme = theme
      ..colors = colors
      ..still = still
      ..debugLabel = debugLabel
      ..markNeedsLayout();
  }
}

/// Render object of [ShapeLayer].
class RenderShapeLayer extends RenderBox with Shimmering {
  /// Creates it.
  RenderShapeLayer(
    this.shape,
    this.theme,
    this.colors,
    this.still,
    this.debugLabel,
  );

  /// The shape.
  SkeletonShape shape;

  @override
  SkulletTheme theme;

  @override
  SkeletonColors colors;

  @override
  bool still;

  /// For the debug overlay.
  String? debugLabel;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(shape.size);

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    paintShimmering(context, offset, shape.bones);
    if (debugLabel != null) {
      _debugOutline(context.canvas, offset & size, _debugLoading, debugLabel!);
    }
  }
}

/// Shows its child, bringing it in over [skeleton] when there is one.
class RevealLayer extends SingleChildRenderObjectWidget {
  /// Creates the layer.
  const RevealLayer({
    super.key,
    required this.skeleton,
    required this.mode,
    required this.context,
    required this.theme,
    required this.colors,
    required this.still,
    required this.onMeasured,
    required this.onRevealed,
    required this.debug,
    super.child,
  });

  /// The skeleton the content replaces; null when there was none.
  final SkeletonShape? skeleton;

  /// The reveal mode.
  final RevealMode mode;

  /// What the reveal knows about how it loaded.
  final RevealContext context;

  /// The theme.
  final SkulletTheme theme;

  /// Its colours.
  final SkeletonColors colors;

  /// Reveal at once.
  final bool still;

  /// Called with each new measurement of the content.
  final ValueChanged<SkeletonShape> onMeasured;

  /// Called once the content is fully in.
  final VoidCallback onRevealed;

  /// Show the debug overlay.
  final bool debug;

  @override
  RenderReveal createRenderObject(BuildContext context) => RenderReveal(
    element: context as Element,
    skeleton: skeleton,
    mode: mode,
    revealContext: this.context,
    theme: theme,
    colors: colors,
    still: still,
    onMeasured: onMeasured,
    onRevealed: onRevealed,
    debug: debug,
  );

  @override
  void updateRenderObject(BuildContext context, RenderReveal renderObject) {
    renderObject
      ..theme = theme
      ..colors = colors
      ..onMeasured = onMeasured
      ..onRevealed = onRevealed
      ..debug = debug;
  }
}

enum _Phase { waiting, together, cascade, sweep, done }

/// Render object of [RevealLayer].
class RenderReveal extends RenderProxyBox with Shimmering {
  /// Creates it.
  RenderReveal({
    required this.element,
    required this.skeleton,
    required this.mode,
    required this.revealContext,
    required this.theme,
    required this.colors,
    required this.still,
    required this.onMeasured,
    required this.onRevealed,
    required this.debug,
  });

  /// Its element, to measure the content from.
  final Element element;

  /// The skeleton being replaced.
  final SkeletonShape? skeleton;

  /// The reveal mode asked for.
  final RevealMode mode;

  /// How it loaded.
  final RevealContext revealContext;

  @override
  SkulletTheme theme;

  @override
  SkeletonColors colors;

  @override
  bool still;

  /// See [RevealLayer.onMeasured].
  ValueChanged<SkeletonShape> onMeasured;

  /// See [RevealLayer.onRevealed].
  VoidCallback onRevealed;

  /// See [RevealLayer.debug].
  bool debug;

  _Phase _phase = _Phase.waiting;
  Duration _start = Duration.zero;
  Duration _length = Duration.zero;
  Duration _delay = Duration.zero;
  Duration? _lastFrame;
  Cascade? _cascade;
  List<Bone>? _content;
  bool _measured = false;
  ui.Image? _mask;
  final Map<RenderImage, Duration?> _images = {};
  Duration? _revealedAt;
  final LayerHandle<ShaderMaskLayer> _inLayer = LayerHandle();
  final LayerHandle<ShaderMaskLayer> _glossLayer = LayerHandle();
  final LayerHandle<ShaderMaskLayer> _outLayer = LayerHandle();
  final LayerHandle<ShaderMaskLayer> _maskLayer = LayerHandle();
  final LayerHandle<OpacityLayer> _fadeLayer = LayerHandle();

  /// Whether the reveal is still under way.
  @visibleForTesting
  bool get revealing => _phase != _Phase.done;

  /// The mode the reveal resolved to, once it has started.
  @visibleForTesting
  RevealMode? resolvedMode;

  @override
  void performLayout() {
    super.performLayout();
    _measured = false;
  }

  @override
  void dispose() {
    _inLayer.layer = null;
    _glossLayer.layer = null;
    _outLayer.layer = null;
    _maskLayer.layer = null;
    _fadeLayer.layer = null;
    _mask?.dispose();
    super.dispose();
  }

  void _measure() {
    if (_measured) return;
    _measured = true;
    final content = _childOf(element);
    if (content == null) return;
    final bones = measureBones(content, textRadius: theme.radius);
    _content = bones;
    _images.removeWhere((image, _) => !image.attached);
    _findImages(content);
    final shape = SkeletonShape(Size(size.width, size.height), bones);
    SchedulerBinding.instance.addPostFrameCallback((_) => onMeasured(shape));
  }

  void _findImages(Element root) {
    void visit(Element element) {
      if (element is RenderObjectElement &&
          element.renderObject is RenderImage) {
        final image = element.renderObject as RenderImage;
        _images.putIfAbsent(image, () => null);
        assert(() {
          if (image.image == null &&
              image.width == null &&
              image.height == null &&
              (!image.hasSize || image.size.isEmpty)) {
            debugPrint(
              'skullet: an image has no size until it loads, so its skeleton '
              'has no room for it. Give it a width and height, or an '
              'AspectRatio.',
            );
          }
          return true;
        }());
      }
      element.visitChildElements(visit);
    }

    visit(root);
  }

  void _begin(Duration now) {
    final skeleton = this.skeleton;
    _start = now;
    if (skeleton == null || still) {
      _finish(now, RevealMode.instant);
      return;
    }
    final pieces = {
      for (final bone in _content ?? const <Bone>[])
        if (bone.kind != BoneKind.surface) bone.piece,
    }.length;
    final context = RevealContext(
      waited: revealContext.waited,
      input: revealContext.input,
      refetch: revealContext.refetch,
      height: size.height,
      pieces: pieces,
    );
    var resolved = choose(mode, context);
    final screen = localToGlobal(Offset.zero);
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final screenSize = view == null
        ? const Size(1280, 800)
        : view.physicalSize / view.devicePixelRatio;
    if (resolved == RevealMode.sweep) {
      final box = (Offset.zero & size).expandToInclude(
        Offset.zero & skeleton.size,
      );
      if (box.width * box.height >
          screenSize.width * screenSize.height * maxSweepArea) {
        resolved = RevealMode.together;
      }
    }
    resolvedMode = resolved;
    switch (resolved) {
      case RevealMode.instant:
        _finish(now, resolved);
      case RevealMode.together:
        _phase = _Phase.together;
        _length = revealContext.refetch ? quickFade : fadeDuration;
      case RevealMode.smart || RevealMode.sequence:
        _phase = _Phase.cascade;
        _cascade = Cascade.plan(
          content: _content ?? const [],
          skeleton: skeleton.bones,
          size: size,
          screenTop: screen.dy,
          screenHeight: screenSize.height,
          byRow: resolved == RevealMode.smart,
        );
        _length = _cascade!.duration;
      case RevealMode.sweep:
        _phase = _Phase.sweep;
        final box = (screen & size).expandToInclude(screen & skeleton.size);
        final timing = SweepTiming.plan(
          box,
          now,
          theme.copyWith(animation: SkeletonAnimation.shimmer).period,
        );
        _delay = timing.delay;
        _length = timing.delay + timing.duration;
    }
  }

  void _finish(Duration now, RevealMode resolved) {
    resolvedMode ??= resolved;
    _phase = _Phase.done;
    _revealedAt = now;
    _mask?.dispose();
    _mask = null;
    _inLayer.layer = null;
    _glossLayer.layer = null;
    _outLayer.layer = null;
    _maskLayer.layer = null;
    _fadeLayer.layer = null;
    final skeleton = this.skeleton;
    if (skeleton != null) {
      assert(() {
        final moved = (skeleton.size.height - size.height).abs();
        if (moved >= 1) {
          debugPrint(
            'skullet: the skeleton was ${skeleton.size.height.toStringAsFixed(0)}px '
            'tall and its content ${size.height.toStringAsFixed(0)}px, so the '
            'page moved ${moved.toStringAsFixed(0)}px. Give the sample typical '
            'lengths.',
          );
        }
        return true;
      }());
      SchedulerBinding.instance.addPostFrameCallback((_) => onRevealed());
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    _measure();
    final now = frameClock;
    if (_phase == _Phase.waiting) _begin(now);

    if (_phase != _Phase.done && now - _start >= _length) {
      _finish(now, mode);
    }

    // A sweep that drops frames finishes as a crossfade.
    if (_phase == _Phase.sweep &&
        _lastFrame != null &&
        now - _lastFrame! > const Duration(milliseconds: 100) &&
        now - _start > _delay) {
      _phase = _Phase.together;
      _start = now;
      _length = fadeDuration;
    }
    _lastFrame = now;
    final elapsed = now - _start;

    switch (_phase) {
      case _Phase.waiting || _Phase.done:
        context.paintChild(child, offset);
      case _Phase.together:
        final t = ease(elapsed.inMicroseconds / _length.inMicroseconds);
        _fadeLayer.layer = context.pushOpacity(
          offset,
          (t * 255).round(),
          (c, o) => c.paintChild(child, o),
          oldLayer: _fadeLayer.layer,
        );
        paintShimmering(context, offset, skeleton!.bones, opacity: 1 - t);
      case _Phase.cascade:
        _paintCascade(context, offset, elapsed);
      case _Phase.sweep:
        final progress =
            ((elapsed - _delay).inMicroseconds /
                    (_length - _delay).inMicroseconds)
                .clamp(0.0, 1.0);
        _paintSweep(context, offset, progress);
    }
    if (_phase != _Phase.done) scheduleNextFrame();

    _paintImages(context, offset, now);

    if (debug && skeleton != null && _phase == _Phase.done) {
      final moved = (skeleton!.size.height - size.height).abs();
      _debugOutline(
        context.canvas,
        offset & size,
        moved < 1 ? _debugStill : _debugMoved,
        moved < 1 ? 'nothing moved' : 'moved ${moved.toStringAsFixed(0)}px',
      );
    }
  }

  void _paintCascade(PaintingContext context, Offset offset, Duration elapsed) {
    final cascade = _cascade!;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF000000));
    final pieces = <int, Rect>{};
    for (final bone in _content ?? const <Bone>[]) {
      if (bone.kind == BoneKind.surface) continue;
      pieces.update(
        bone.piece,
        (r) => r.expandToInclude(bone.rect),
        ifAbsent: () => bone.rect,
      );
    }
    for (final entry in pieces.entries) {
      final alpha = Cascade.opacityAt(cascade.pieceDelay[entry.key], elapsed);
      if (alpha >= 1) continue;
      canvas.drawRect(
        entry.value.inflate(1),
        Paint()
          ..blendMode = BlendMode.src
          ..color = Color.fromRGBO(0, 0, 0, alpha),
      );
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      math.max(1, size.width.ceil()),
      math.max(1, size.height.ceil()),
    );
    picture.dispose();
    _mask?.dispose();
    _mask = image;
    final layer = _maskLayer.layer ??= ShaderMaskLayer();
    layer
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      )
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer, (c, o) => c.paintChild(child!, o), offset);
    paintShimmering(
      context,
      offset,
      skeleton!.bones,
      boneOpacity: (i) => 1 - Cascade.opacityAt(cascade.boneDelay[i], elapsed),
    );
  }

  ({Offset from, Offset to}) _front(double progress, double lag) {
    final box = (Offset.zero & size).expandToInclude(
      Offset.zero & skeleton!.size,
    );
    final corners = [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ].map(SweepTiming.u);
    const feather = 40.0;
    final lo = corners.reduce(math.min) - feather;
    final hi = corners.reduce(math.max) + feather;
    final at = lo + (hi - lo) * progress - lag;
    return (
      from: slantNormal * (at - feather),
      to: slantNormal * (at + feather),
    );
  }

  Shader _ramp(double progress, {required bool incoming}) {
    final front = _front(progress, 0);
    final stops = [for (var i = 0; i <= steps; i++) i / steps];
    return ui.Gradient.linear(front.from, front.to, [
      for (final t in stops)
        Color.fromRGBO(0, 0, 0, incoming ? 1 - ease(t) : ease(t)),
    ], stops);
  }

  void _paintSweep(PaintingContext context, Offset offset, double progress) {
    const width = 320.0;
    const lift = 0.45;
    final band = _front(progress, 120);
    final normal = slantNormal;
    final centre = (band.from + band.to) / 2;
    final stops = [for (var i = 0; i <= steps; i++) i / steps];
    final gloss = ui.Gradient.linear(
      centre - normal * (width / 2),
      centre + normal * (width / 2),
      [
        for (final t in stops)
          Color.fromRGBO(255, 255, 255, lift * ease(1 - (t * 2 - 1).abs())),
      ],
      stops,
    );

    final incoming = _inLayer.layer ??= ShaderMaskLayer();
    incoming
      ..shader = _ramp(progress, incoming: true)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(incoming, (c, o) {
      c.paintChild(child!, o);
      // The band trailing the front lifts only what the content paints, its
      // text and images, toward white; never the surfaces around them.
      final glossLayer = _glossLayer.layer ??= ShaderMaskLayer();
      glossLayer
        ..shader = gloss
        ..maskRect = o & size
        ..blendMode = BlendMode.srcATop;
      c.pushLayer(glossLayer, (c2, o2) => _paintLeaves(c2, o2), o);
    }, offset);

    final outgoing = _outLayer.layer ??= ShaderMaskLayer();
    outgoing
      ..shader = _ramp(progress, incoming: false)
      ..maskRect =
          offset &
          (size.isEmpty
              ? skeleton!.size
              : Size(
                  math.max(size.width, skeleton!.size.width),
                  math.max(size.height, skeleton!.size.height),
                ))
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(
      outgoing,
      (c, o) => paintShimmering(c, o, skeleton!.bones),
      offset,
    );
  }

  /// Paints the content's text and images again, alone.
  void _paintLeaves(PaintingContext context, Offset offset) {
    final content = _childOf(element);
    if (content == null) return;
    void visit(Element element) {
      if (element is RenderObjectElement) {
        final object = element.renderObject;
        if ((object is RenderParagraph && object.childCount == 0) ||
            (object is RenderImage && object.image != null)) {
          final box = object as RenderBox;
          if (box.attached && box.hasSize) {
            context.pushTransform(
              needsCompositing,
              offset,
              box.getTransformTo(this),
              (c, o) => box.paint(c, o),
            );
          }
          return;
        }
      }
      element.visitChildElements(visit);
    }

    visit(content);
  }

  /// Each image still loading keeps a skeleton of its own until it has
  /// decoded, then fades in, whatever the reveal is doing.
  void _paintImages(PaintingContext context, Offset offset, Duration now) {
    if (_images.isEmpty) return;
    final revealedAt = _revealedAt ?? _start;
    final bones = <Bone>[];
    final alphas = <double>[];
    var pending = false;
    for (final entry in _images.entries.toList()) {
      final image = entry.key;
      if (!image.attached || !image.hasSize) continue;
      var loadedAt = entry.value;
      if (image.image != null && loadedAt == null) {
        loadedAt = _images[image] = now;
      }
      final timedOut = now - revealedAt > imageTimeout;
      double alpha;
      if (loadedAt == null) {
        alpha = timedOut ? 0 : 1;
        if (!timedOut) pending = true;
      } else {
        alpha =
            1 -
            ease((now - loadedAt).inMicroseconds / fadeDuration.inMicroseconds);
        if (alpha > 0) pending = true;
      }
      if (alpha <= 0 || skeleton == null) continue;
      final rect = MatrixUtils.transformRect(
        image.getTransformTo(this),
        Offset.zero & image.size,
      );
      bones.add(Bone(BoneKind.block, rect));
      alphas.add(alpha);
    }
    if (bones.isNotEmpty) {
      paintShimmering(context, offset, bones, boneOpacity: (i) => alphas[i]);
    }
    if (pending && animationsAllowed) scheduleNextFrame();
  }
}

import 'package:flutter/widgets.dart';

import 'bones.dart';
import 'environment.dart';
import 'hints.dart';
import 'plan.dart';
import 'render.dart';
import 'shapes.dart';
import 'theme.dart';

/// Builds content from data.
typedef SkeletonBuilder<T> = Widget Function(BuildContext context, T data);

/// Shows a skeleton of exactly what is about to load.
///
/// While [data] is null, [builder] renders [sample] unseen, and that layout
/// is measured into a skeleton: a bar for each line of text, a block for each
/// image, icon or control. Once [data] arrives the content replaces the
/// skeleton in its exact space, so nothing moves.
class Skeleton<T extends Object> extends StatefulWidget {
  /// Creates a skeleton that loads while [data] is null.
  const Skeleton({
    super.key,
    required this.data,
    required this.builder,
    this.sample,
    this.loading = false,
    this.id,
    this.label,
    this.skeleton,
    this.error,
    this.empty = false,
    this.emptyMessage,
    this.reveal,
    this.onReveal,
  });

  /// A skeleton you toggle yourself: [child] is measured as it is while
  /// [loading]. Empty text in it stands for a typical line.
  static Skeleton<Object> child({
    Key? key,
    required bool loading,
    required Widget child,
    String? id,
    String? label,
    RevealMode? reveal,
    VoidCallback? onReveal,
  }) => Skeleton<Object>(
    key: key,
    data: _present,
    loading: loading,
    sample: _present,
    id: id,
    label: label,
    reveal: reveal,
    onReveal: onReveal,
    builder: (context, _) => child,
  );

  static const Object _present = Object();

  /// Loading while null; passed to [builder] once set.
  final T? data;

  /// Builds the content. It only ever receives real data or [sample].
  final SkeletonBuilder<T> builder;

  /// Stands in for [data] to draw the first skeleton.
  final T? sample;

  /// Shows the skeleton even over [data], say while refetching.
  final bool loading;

  /// Remembers the skeleton's shape under this key, so the next load is
  /// exact without a [sample].
  final String? id;

  /// Read to screen readers while loading.
  final String? label;

  /// Shown while loading instead of the measured skeleton.
  final Widget? skeleton;

  /// Shown in place of the content when set.
  final Widget? error;

  /// Shows [emptyMessage] in place of the content.
  final bool empty;

  /// Shown while [empty]; the content if left out.
  final Widget? emptyMessage;

  /// How the content replaces the skeleton; the provider's by default.
  final RevealMode? reveal;

  /// Called once content has come in over a skeleton.
  final VoidCallback? onReveal;

  @override
  State<Skeleton<T>> createState() => _SkeletonState<T>();
}

class _SkeletonState<T extends Object> extends State<Skeleton<T>> {
  /// The shape of the skeleton on screen, for the reveal to replace.
  SkeletonShape? _shown;

  /// When the current load began, on the input tracker's clock.
  Duration? _loadingSince;
  bool _wasLoading = false;
  bool _refetch = false;
  int _reveals = 0;
  RevealContext _context = const RevealContext(
    waited: Duration.zero,
    input: false,
    refetch: false,
    height: 0,
    pieces: 0,
  );

  bool get _loading => widget.data == null || widget.loading;

  @override
  void initState() {
    super.initState();
    InputTracker.ensureListening();
    if (_loading) _startLoading();
  }

  void _startLoading() {
    _loadingSince = InputTracker.now;
    _refetch = widget.data != null;
    _wasLoading = true;
  }

  @override
  void didUpdateWidget(Skeleton<T> old) {
    super.didUpdateWidget(old);
    if (_loading && !_wasLoading) {
      _startLoading();
    } else if (!_loading && _wasLoading) {
      _wasLoading = false;
      _reveals++;
      _context = RevealContext(
        waited: InputTracker.now - (_loadingSince ?? InputTracker.now),
        input: InputTracker.recent(),
        refetch: _refetch,
        height: 0,
        pieces: 0,
      );
    }
  }

  String? get _storeKey {
    final id = widget.id;
    if (id == null) return null;
    final scale = MediaQuery.maybeTextScalerOf(context)?.scale(14) ?? 14;
    return '$id@${scale.toStringAsFixed(1)}';
  }

  void _measured(SkeletonShape shape) => _shown = shape;

  void _contentMeasured(SkeletonShape shape) {
    final key = _storeKey;
    final data = widget.data;
    if (key == null || data == null || widget.empty) return;
    Skullet.store.write(key, shape);
    Skullet.lastData[widget.id!] = data;
  }

  void _revealed() {
    if (mounted) widget.onReveal?.call();
  }

  @override
  Widget build(BuildContext context) {
    final provider = SkulletProvider.of(context);
    final colors = provider.colorsOf(context);
    final still = motionReduced(context);
    final mode = widget.reveal ?? provider.reveal;

    final Widget child;
    if (widget.error != null) {
      child = KeyedSubtree(key: const ValueKey('error'), child: widget.error!);
    } else if (_loading) {
      child = _buildLoading(context, provider, colors, still, mode);
    } else {
      final data = widget.data as T;
      final content = widget.empty
          ? (widget.emptyMessage ?? widget.builder(context, data))
          : widget.builder(context, data);
      child = RevealLayer(
        key: ValueKey(_reveals),
        skeleton: _reveals == 0 ? null : _shown,
        mode: mode,
        context: _context,
        theme: provider.theme,
        colors: colors,
        still: still,
        onMeasured: _contentMeasured,
        onRevealed: _revealed,
        debug: provider.debug,
        child: content,
      );
    }
    if (still) return child;
    // A skeleton drawn from old data might not match the new data's height:
    // ease to it rather than snap.
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.topStart,
      child: child,
    );
  }

  Widget _buildLoading(
    BuildContext context,
    SkulletProvider provider,
    SkeletonColors colors,
    bool still,
    RevealMode mode,
  ) {
    final hold =
        (mode == RevealMode.smart || mode == RevealMode.sweep) && !_refetch
        ? skeletonDelay
        : Duration.zero;
    Widget ghost;
    if (widget.skeleton != null) {
      _shown = null;
      ghost = widget.skeleton!;
    } else {
      final id = widget.id;
      final last = id == null ? null : Skullet.lastData[id];
      final key = _storeKey;
      final remembered = key == null ? null : Skullet.store.read(key);
      T? source;
      String label;
      if (widget.data != null) {
        source = widget.data;
        label = 'data on screen';
      } else if (last is T) {
        source = last;
        label = 'data last shown';
      } else if (remembered != null) {
        source = null;
        label = 'remembered shape';
      } else if (widget.sample != null) {
        source = widget.sample;
        label = 'sample';
      } else {
        source = null;
        label = 'fallback';
        assert(() {
          debugPrint(
            'skullet: nothing to measure${id == null ? '' : ' for "$id"'}. '
            'Pass a sample, or an id so the shape is remembered.',
          );
          return true;
        }());
      }
      final debugLabel = provider.debug ? label : null;
      if (source != null) {
        ghost = GhostLayer(
          key: const ValueKey('ghost'),
          theme: provider.theme,
          colors: colors,
          still: still,
          hold: hold,
          onMeasured: _measured,
          debugLabel: debugLabel,
          child: SkeletonScope(child: widget.builder(context, source)),
        );
      } else if (remembered != null) {
        _shown = remembered;
        ghost = ShapeLayer(
          key: const ValueKey('shape'),
          shape: remembered,
          theme: provider.theme,
          colors: colors,
          still: still,
          debugLabel: debugLabel,
        );
      } else {
        ghost = GhostLayer(
          key: const ValueKey('fallback'),
          theme: provider.theme,
          colors: colors,
          still: still,
          hold: hold,
          onMeasured: _measured,
          debugLabel: debugLabel,
          child: const _Fallback(),
        );
      }
    }
    return Semantics(
      key: const ValueKey('loading'),
      container: true,
      label: widget.label,
      child: ExcludeSemantics(child: IgnorePointer(child: ghost)),
    );
  }
}

/// A few generic lines, when there is nothing to measure.
class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    final size = DefaultTextStyle.of(context).style.fontSize ?? 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 300;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final factor in const [1.0, 0.9, 0.6])
              Padding(
                padding: EdgeInsets.symmetric(vertical: size * 0.5),
                child: SkeletonBox(width: width * factor, height: size * 0.75),
              ),
          ],
        );
      },
    );
  }
}

/// A [Skeleton] for a [Future]: loading until it completes, then its value,
/// or [error] if it fails.
class FutureSkeleton<T extends Object> extends StatelessWidget {
  /// Creates it.
  const FutureSkeleton({
    super.key,
    required this.future,
    required this.builder,
    this.sample,
    this.id,
    this.label,
    this.errorBuilder,
    this.onReveal,
  });

  /// The future.
  final Future<T>? future;

  /// Builds the content.
  final SkeletonBuilder<T> builder;

  /// Stands in for the value to draw the first skeleton.
  final T? sample;

  /// See [Skeleton.id].
  final String? id;

  /// See [Skeleton.label].
  final String? label;

  /// Builds what is shown when the future fails.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// See [Skeleton.onReveal].
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) => Skeleton<T>(
        data: snapshot.data,
        loading: snapshot.connectionState == ConnectionState.waiting,
        sample: sample,
        id: id,
        label: label,
        onReveal: onReveal,
        error: snapshot.hasError
            ? (errorBuilder?.call(context, snapshot.error!) ??
                  const SizedBox.shrink())
            : null,
        builder: builder,
      ),
    );
  }
}

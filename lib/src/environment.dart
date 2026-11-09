import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'env_stub.dart' if (dart.library.io) 'env_io.dart';

/// Whether skeletons animate and reveals play under `flutter test`.
///
/// Off by default, as skullet's web version does under jsdom: a shimmer that
/// repaints every frame would keep `pumpAndSettle` from ever settling, so in
/// tests skeletons hold still and every reveal is instant. Turn it on to test
/// the animations themselves.
bool debugSkulletAnimateInTests = false;

/// Whether skeletons should hold still and reveals be instant for [context].
///
/// They also hold still where tickers are off ([TickerMode]): a route behind
/// another, a tab out of sight, or the content measured for a skeleton. A
/// skeleton nobody can see shouldn't ask for frames.
bool motionReduced(BuildContext context) {
  if (runningInFlutterTest && !debugSkulletAnimateInTests) return true;
  // TickerMode.valuesOf replaces this from Flutter 3.35; 3.32 is supported.
  // ignore: deprecated_member_use
  if (!TickerMode.of(context)) return true;
  return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Whether frames should be driven at all under the current environment.
bool get animationsAllowed =>
    !(runningInFlutterTest && !debugSkulletAnimateInTests);

/// The shared clock every skeleton's animation is timed by, so all of them
/// keep one phase however late they mount.
Duration get frameClock {
  final binding = SchedulerBinding.instance;
  return binding.schedulerPhase == SchedulerPhase.idle
      ? Duration.zero
      : binding.currentFrameTimeStamp;
}

/// Tracks recent input: someone mid-gesture should see content at once.
class InputTracker {
  InputTracker._();

  static Duration? _last;
  static bool _listening = false;

  /// The time of the latest frame: the clock loads and input are timed by.
  static Duration get now =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp;

  /// Starts listening, once.
  static void ensureListening() {
    if (_listening) return;
    _listening = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static void _onPointer(PointerEvent event) {
    // A drag or a wheel, not a tap: a tap doesn't move what's being read.
    if (event is PointerMoveEvent ||
        event is PointerScrollEvent ||
        event is PointerPanZoomUpdateEvent) {
      _last = now;
    }
  }

  static bool _onKey(KeyEvent event) {
    _last = now;
    return false;
  }

  /// Whether there was input in the last [window].
  static bool recent([Duration window = activeWindow]) {
    final last = _last;
    return last != null && now - last < window;
  }

  /// Marks input now, for tests.
  @visibleForTesting
  static void markInput() => _last = now;

  /// Resets the tracker, for tests.
  @visibleForTesting
  static void reset() => _last = null;

  /// Input this recent means someone is mid-gesture.
  static const activeWindow = Duration(milliseconds: 400);
}

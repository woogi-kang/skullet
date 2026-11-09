import 'dart:io';

/// Whether this runs under `flutter test`: the `FLUTTER_TEST` environment
/// variable, or `--dart-define=SKULLET_TEST=true`.
bool get runningInFlutterTest =>
    const bool.fromEnvironment('SKULLET_TEST') ||
    Platform.environment.containsKey('FLUTTER_TEST');

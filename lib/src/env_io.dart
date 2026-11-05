import 'dart:io';

/// Whether this runs under `flutter test`.
bool get runningInFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');

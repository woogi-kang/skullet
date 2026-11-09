/// Whether this runs under `flutter test`.
///
/// The web has no environment to read, so `flutter test --platform chrome`
/// says so with `--dart-define=SKULLET_TEST=true`.
const bool runningInFlutterTest = bool.fromEnvironment('SKULLET_TEST');

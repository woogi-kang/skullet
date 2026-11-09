import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'support/fonts_web.dart' if (dart.library.io) 'support/fonts_io.dart';

/// Loads real fonts (on the VM) and turns on leak tracking, so an image or
/// layer a reveal forgets to dispose fails its test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    createdByTestHelpers: true,
  );
  await loadFonts();
  await testMain();
}

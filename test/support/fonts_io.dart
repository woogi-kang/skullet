import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto and Material Icons from the Flutter SDK's own cache, so text
/// and icons measure and render as they would in an app. Nothing is bundled.
///
/// Fails rather than falling back to the test font, whose square glyphs would
/// quietly change every measurement.
Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set: run these tests with flutter.');
  }
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final file in files) {
      final f = File('$fonts/$file');
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
        any = true;
      }
    }
    if (!any) {
      throw StateError(
        'No $family font in $fonts: run `flutter precache` and try again.',
      );
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

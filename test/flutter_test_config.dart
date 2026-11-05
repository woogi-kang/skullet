import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto and Material Icons from the Flutter SDK's own cache, so text
/// and icons measure and render as they would in an app. Nothing is bundled.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      var any = false;
      for (final file in files) {
        final f = File('$fonts/$file');
        if (f.existsSync()) {
          loader.addFont(
            Future.value(ByteData.sublistView(f.readAsBytesSync())),
          );
          any = true;
        }
      }
      if (any) await loader.load();
    }

    await load('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  }
  await testMain();
}

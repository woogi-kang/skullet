// Runs the integration tests in a browser: `flutter drive -d web-server
// --driver test_driver/integration_test.dart --target integration_test/...`.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();

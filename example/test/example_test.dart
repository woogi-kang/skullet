import 'package:flutter_test/flutter_test.dart';
import 'package:skullet_example/main.dart';

void main() {
  testWidgets('shows skeletons, then the content', (tester) async {
    Api.latency = const Duration(milliseconds: 80);
    await tester.pumpWidget(const DemoApp());
    expect(find.text('Ada Lovelace'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Charles Babbage'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

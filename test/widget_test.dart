import 'package:flutter_test/flutter_test.dart';
import 'package:shotlog/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShotLogApp());
    expect(find.text('ShotLog'), findsOneWidget);

  });
}

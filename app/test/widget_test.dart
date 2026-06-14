import 'package:flutter_test/flutter_test.dart';
import 'package:gizen/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GizenApp());
    expect(find.text('GIZEN - IIT KGP'), findsOneWidget);
  });
}

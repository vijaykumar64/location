import 'package:flutter_test/flutter_test.dart';
import 'package:sender_app/main.dart';

void main() {
  testWidgets('SenderApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SenderApp());
    expect(find.text('Location Sender'), findsOneWidget);
  });
}

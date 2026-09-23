import 'package:flutter_test/flutter_test.dart';
import 'package:receiver_app/main.dart';
import 'package:receiver_app/services/socket_service.dart';

void main() {
  testWidgets('ReceiverApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ReceiverApp());
    expect(find.text('Live Location'), findsOneWidget);
    // Disconnect any active socket to clean up pending timers in test environment
    SocketService().disconnect();
    await tester.pumpAndSettle();
  });
}

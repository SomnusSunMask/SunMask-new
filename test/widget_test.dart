import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble2/main.dart';

void main() {
  testWidgets('App startet ohne Fehler', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.text('BLE Scanner'), findsOneWidget);
  });
}

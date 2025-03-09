import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble2/main.dart';

void main() {
  testWidgets('BLE App UI Test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Start Scan'), findsOneWidget);
    expect(find.text('Stop Scan'), findsOneWidget);
    
    await tester.tap(find.text('Start Scan'));
    await tester.pump();
    
    expect(find.text('Stop Scan'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble2/main.dart';

void main() {
  testWidgets('BLE HomePage Test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Prüfen, ob der Button existiert
    expect(find.text('Start Scan'), findsOneWidget);
    
    // Button klicken und Scan starten
    await tester.tap(find.text('Start Scan'));
    await tester.pump();

    // Nach dem Scan sollte "Scanning..." angezeigt werden
    expect(find.text('Scanning...'), findsOneWidget);
  });
}

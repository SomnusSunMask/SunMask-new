import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble2/main.dart';

void main() {
  testWidgets('App startet ohne Fehler', (WidgetTester tester) async {
    // App starten
    await tester.pumpWidget(const MyApp());

    // Prüfen, ob das Haupt-Widget existiert
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(BLEHomePage), findsOneWidget);
  });
}

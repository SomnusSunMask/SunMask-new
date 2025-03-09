import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble2/main.dart';

void main() {
  testWidgets('App startet ohne Fehler', (WidgetTester tester) async {
    // Versuche, die App zu starten
    await tester.pumpWidget(const BLEHomePage());

    // Prüfe, ob ein zentrales Widget der App vorhanden ist
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble2/main.dart';

void main() {
  testWidgets('App startet ohne Fehler', (WidgetTester tester) async {
    // Versuche, die App zu starten
    await tester.pumpWidget(const MyApp());

    // Prüfe, ob die App erfolgreich gestartet ist
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

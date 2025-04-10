import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:somnus/main.dart';

void main() {
  testWidgets('App startet ohne Fehler', (WidgetTester tester) async {
    // App starten
    await tester.pumpWidget(const MyApp());

    // Überprüfen, ob die App korrekt geladen wurde
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(BLEHomePage), findsOneWidget);
  });
}

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plugin-Test',
      theme: ThemeData.light(), // <--- Hell statt dark
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Test ohne Plugins'),
        ),
        body: const Center(
          child: Text(
            'Läuft die App jetzt?',
            style: TextStyle(fontSize: 20, color: Colors.black), // <--- explizit schwarz
          ),
        ),
      ),
    );
  }
}

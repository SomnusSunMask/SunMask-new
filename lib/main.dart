// main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      theme: ThemeData.dark(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd – kk:mm').format(now);

    return Scaffold(
      appBar: AppBar(title: const Text("INTL Test")),
      body: Center(
        child: Text(
          "Aktuelles Datum:\n$formattedDate",
          style: const TextStyle(fontSize: 22),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

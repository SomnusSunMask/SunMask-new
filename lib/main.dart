// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test SharedPreferences',
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String savedValue = "Noch nichts gespeichert";

  Future<void> saveValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('key', 'Hallo Welt');
    setState(() {
      savedValue = 'Gespeichert: Hallo Welt';
    });
  }

  Future<void> loadValue() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('key');
    setState(() {
      savedValue = value ?? 'Kein Wert gefunden';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('SharedPreferences Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(savedValue, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveValue,
              child: const Text('Wert speichern'),
            ),
            ElevatedButton(
              onPressed: loadValue,
              child: const Text('Wert laden'),
            ),
          ],
        ),
      ),
    );
  }
}

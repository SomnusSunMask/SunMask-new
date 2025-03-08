import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Korrektur des Key-Parameters

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BLEHomePage(),
    );
  }
}

// Klasse öffentlich machen, falls sie vorher privat war
class BLEHomePage extends StatefulWidget {
  const BLEHomePage({super.key});

  @override
  BLEHomePageState createState() => BLEHomePageState();
}

class BLEHomePageState extends State<BLEHomePage> {
  int counter = 0;

  void _incrementCounter() {
    setState(() {
      counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Test App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Counter: $counter',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

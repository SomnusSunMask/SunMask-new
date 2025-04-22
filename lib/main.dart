import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red, // kräftige Hintergrundfarbe
        body: Center(
          child: Container(
            width: 200,
            height: 100,
            color: Colors.white,
            child: const Center(
              child: Text(
                'TEST',
                style: TextStyle(fontSize: 24, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

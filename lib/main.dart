import 'package:flutter/material.dart';

void main() {
  runApp(const MyTestApp());
}

class MyTestApp extends StatelessWidget {
  const MyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test iOS',
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Hallo iOS',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

// main.dart
import 'package:flutter/material.dart';

void main() {
  debugPrint(">>> MAIN WIRD AUSGEFÜHRT <<<");
  runApp(MyTestApp());
}

class MyTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    debugPrint(">>> BUILD WIRD AUSGEFÜHRT <<<");

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.yellow,
        body: Center(
          child: Text(
            "Hello iOS!",
            style: TextStyle(fontSize: 32, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

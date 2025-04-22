import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeFormatted = DateFormat.Hm().format(now);

    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin-Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Aktuelle Uhrzeit: $timeFormatted'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final status = await Permission.location.request();
                  debugPrint("Standort-Erlaubnis: ${status.name}");
                  final pos = await Geolocator.getCurrentPosition();
                  debugPrint("Position: ${pos.latitude}, ${pos.longitude}");
                },
                child: const Text("Berechtigung & Ort testen"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

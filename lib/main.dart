import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

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
                  LocationPermission permission = await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                  }

                  if (permission == LocationPermission.always ||
                      permission == LocationPermission.whileInUse) {
                    Position position = await Geolocator.getCurrentPosition();
                    // ignore: use_build_context_synchronously
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Standort'),
                        content: Text(
                            'Latitude: ${position.latitude}\nLongitude: ${position.longitude}'),
                      ),
                    );
                  }
                },
                child: const Text('Standort abfragen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // 🔹 `super.key` korrekt übergeben

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  const BLEHomePage({super.key});

  @override
  _BLEHomePageState createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  final List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults.clear();
        scanResults.addAll(results);
      });
    });
  }

  void startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Geräte')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: const Text("Start Scan"),
          ),
          ElevatedButton(
            onPressed: stopScan,
            child: const Text("Stop Scan"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  title: Text(device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

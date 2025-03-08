import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const BLEApp());
}

class BLEApp extends StatelessWidget {
  const BLEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Scanner',
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
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  void startScan() {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    Future.delayed(const Duration(seconds: 5), () {
      FlutterBluePlus.stopScan();
      setState(() {
        isScanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Scanner")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: const Text("Scan nach Geräten"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final result = scanResults[index];
                return ListTile(
                  title: Text(result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : "Unbekanntes Gerät"),
                  subtitle: Text(result.device.remoteId.toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

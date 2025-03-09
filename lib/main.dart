import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key); // Key hinzugefügt

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  const BLEHomePage({Key? key}) : super(key: key); // Key hinzugefügt

  @override
  State<BLEHomePage> createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  List<BluetoothDevice> devices = [];

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)); // Statische Methode

    FlutterBluePlus.scanResults.listen((results) { // Statische Eigenschaft
      setState(() {
        devices = results.map((r) => r.device).toList();
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    FlutterBluePlus.stopScan(); // Statische Methode
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Geräte'),
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.platformName), // `name` durch `platformName` ersetzt
            subtitle: Text(device.remoteId.toString()), // `id` durch `remoteId` ersetzt
            onTap: () {
              debugPrint("Gerät ausgewählt: ${device.platformName}"); // `print` ersetzt
            },
          );
        },
      ),
    );
  }
}

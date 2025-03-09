import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  const BLEHomePage({super.key});

  @override
  State<BLEHomePage> createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  final List<BluetoothDevice> devices = [];

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devices.clear();
        for (var result in results) {
          if (!devices.contains(result.device)) {
            devices.add(result.device);
          }
        }
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint("Verbinde mit: ${device.platformName}");
      await device.connect();
      debugPrint("${device.platformName} erfolgreich verbunden!");

      // UI aktualisieren und eine Rückmeldung geben
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${device.platformName} verbunden!")),
      );
    } catch (e) {
      debugPrint("Fehler beim Verbinden: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler: ${device.platformName} konnte nicht verbunden werden.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Geräte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: scanForDevices,
          ),
        ],
      ),
      body: devices.isEmpty
          ? const Center(child: Text("Keine BLE-Geräte gefunden"))
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () => connectToDevice(device),
                );
              },
            ),
    );
  }
}

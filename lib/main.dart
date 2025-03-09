import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

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
  BluetoothDevice? selectedDevice;
  BluetoothCharacteristic? timerCharacteristic;
  bool isConnected = false;

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

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      selectedDevice = device;
      isConnected = true;
    });

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "abcdef01-1234-5678-1234-56789abcdef0") {
          timerCharacteristic = characteristic;
          debugPrint("Timer-Charakteristik gefunden!");
        }
      }
    }
  }

  void sendTimerToESP() async {
    if (timerCharacteristic != null && isConnected) {
      List<int> timerValue = utf8.encode("30"); // Sendet "30" als Text
      await timerCharacteristic!.write(timerValue);
      debugPrint("30 Sekunden Timer gesendet!");
    } else {
      debugPrint("Keine Verbindung oder Charakteristik nicht gefunden.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Geräte'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () {
                    connectToDevice(device);
                    debugPrint("Gerät ausgewählt: ${device.platformName}");
                  },
                );
              },
            ),
          ),
          if (isConnected) // Button nur anzeigen, wenn verbunden
            ElevatedButton(
              onPressed: sendTimerToESP,
              child: const Text("30 Sekunden Timer senden"),
            ),
        ],
      ),
    );
  }
}

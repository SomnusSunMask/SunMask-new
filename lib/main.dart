import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Weckzeit',
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
  BluetoothCharacteristic? alarmCharacteristic;
  bool isConnected = false;
  TimeOfDay selectedWakeTime = TimeOfDay.now();

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
        if (characteristic.uuid.toString() == "abcdef02-1234-5678-1234-56789abcdef0") {
          alarmCharacteristic = characteristic;
          debugPrint("Weckzeit-Charakteristik gefunden!");
        }
      }
    }
  }

  void sendWakeTimeToESP() async {
    if (alarmCharacteristic != null && isConnected) {
      // Aktuelle Uhrzeit holen
      String currentTime = DateFormat("HH:mm").format(DateTime.now());
      // Weckzeit holen
      String wakeTime = "${selectedWakeTime.hour}:${selectedWakeTime.minute}";

      // Format: "HH:MM|HH:MM" → "Aktuelle Zeit | Weckzeit"
      String combinedData = "$currentTime|$wakeTime";

      await alarmCharacteristic!.write(utf8.encode(combinedData));
      debugPrint("Weckzeit und aktuelle Uhrzeit gesendet: $combinedData");
    } else {
      debugPrint("Keine Verbindung oder Charakteristik nicht gefunden.");
    }
  }

  void disconnectFromDevice() async {
    if (selectedDevice != null) {
      await selectedDevice!.disconnect();
      setState(() {
        selectedDevice = null;
        isConnected = false;
      });
      debugPrint("Verbindung getrennt.");
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
          if (isConnected)
            Column(
              children: [
                ElevatedButton(
                  onPressed: sendWakeTimeToESP,
                  child: const Text("Weckzeit senden"),
                ),
                ElevatedButton(
                  onPressed: disconnectFromDevice,
                  child: const Text("Verbindung trennen"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

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
      title: 'BLE Weckzeit & Timer',
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
  BluetoothCharacteristic? timerCharacteristic;
  bool isConnected = false;
  TimeOfDay selectedWakeTime = TimeOfDay.now();
  int selectedTimerMinutes = 30; // Standardwert

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
        if (characteristic.uuid.toString() == "abcdef03-1234-5678-1234-56789abcdef0") {
          alarmCharacteristic = characteristic;
          debugPrint("Weckzeit-Charakteristik gefunden!");
        }
        if (characteristic.uuid.toString() == "abcdef04-1234-5678-1234-56789abcdef0") {
          timerCharacteristic = characteristic;
          debugPrint("Timer-Charakteristik gefunden!");
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

  void sendTimerToESP() async {
    if (timerCharacteristic != null && isConnected) {
      String timerValue = selectedTimerMinutes.toString();
      await timerCharacteristic!.write(utf8.encode(timerValue));
      debugPrint("Direkter Timer gesendet: $timerValue Minuten");
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

  Future<void> selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedWakeTime,
    );
    if (picked != null && picked != selectedWakeTime) {
      setState(() {
        selectedWakeTime = picked;
      });
    }
  }

  Future<void> selectTimer(BuildContext context) async {
    int? minutes = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Timer einstellen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Dauer in Minuten:"),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  selectedTimerMinutes = int.tryParse(value) ?? 30;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(selectedTimerMinutes);
              },
            ),
          ],
        );
      },
    );

    if (minutes != null) {
      setState(() {
        selectedTimerMinutes = minutes;
      });
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
          if (isConnected) // Buttons nur anzeigen, wenn verbunden
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => selectWakeTime(context),
                  child: Text("Weckzeit wählen: ${selectedWakeTime.format(context)}"),
                ),
                ElevatedButton(
                  onPressed: sendWakeTimeToESP,
                  child: const Text("Weckzeit senden"),
                ),
                ElevatedButton(
                  onPressed: () => selectTimer(context),
                  child: Text("Timer einstellen: $selectedTimerMinutes Minuten"),
                ),
                ElevatedButton(
                  onPressed: sendTimerToESP,
                  child: const Text("Timer starten"),
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

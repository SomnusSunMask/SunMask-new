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
      title: 'BLE Schlafmaske',
      theme: ThemeData(primarySwatch: Colors.blue),
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
    BluetoothCharacteristic? alarmCharacteristic;
    BluetoothCharacteristic? timerCharacteristic;

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "abcdef03-1234-5678-1234-56789abcdef0") {
          alarmCharacteristic = characteristic;
          debugPrint("✅ Weckzeit-Charakteristik gefunden!");
        }
        if (characteristic.uuid.toString() == "abcdef02-1234-5678-1234-56789abcdef0") {
          timerCharacteristic = characteristic;
          debugPrint("✅ Timer-Charakteristik gefunden!");
        }
      }
    }

    // Navigiere zur Steuerungsseite mit BLE-Charakteristiken
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceControlPage(
          device: selectedDevice!,
          alarmCharacteristic: alarmCharacteristic,
          timerCharacteristic: timerCharacteristic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Geräte')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.platformName),
            subtitle: Text(device.remoteId.toString()),
            onTap: () {
              connectToDevice(device);
              debugPrint("📡 Gerät ausgewählt: ${device.platformName}");
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------
// 🟢 Geräte-Steuerungsseite (Neue Seite nach Verbindung)
// ----------------------------------------

class DeviceControlPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic? alarmCharacteristic;
  final BluetoothCharacteristic? timerCharacteristic;

  const DeviceControlPage({
    required this.device,
    this.alarmCharacteristic,
    this.timerCharacteristic,
    Key? key,
  }) : super(key: key);

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  TimeOfDay selectedWakeTime = TimeOfDay.now();
  int selectedTimerMinutes = 30;

  void sendWakeTimeToESP() async {
    if (widget.alarmCharacteristic != null) {
      String currentTime = DateFormat("HH:mm").format(DateTime.now());
      String wakeTime = "${selectedWakeTime.hour}:${selectedWakeTime.minute}";
      String combinedData = "$currentTime|$wakeTime";

      await widget.alarmCharacteristic!.write(utf8.encode(combinedData));
      debugPrint("✅ Weckzeit & aktuelle Uhrzeit gesendet: $combinedData");
    } else {
      debugPrint("❌ Fehler: Keine gültige Weckzeit-Charakteristik!");
    }
  }

  void sendTimerToESP() async {
    if (widget.timerCharacteristic != null) {
      String timerValue = selectedTimerMinutes.toString();
      await widget.timerCharacteristic!.write(utf8.encode(timerValue));
      debugPrint("✅ Timer gesendet: $timerValue Minuten");
    } else {
      debugPrint("❌ Fehler: Keine gültige Timer-Charakteristik vorhanden!");
    }
  }

  void disconnectFromDevice() async {
    await widget.device.disconnect();
    Navigator.pop(context);
    debugPrint("🔌 Verbindung getrennt.");
  }

  Future<void> selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedWakeTime,
    );
    if (picked != null) {
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
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              selectedTimerMinutes = int.tryParse(value) ?? 30;
            },
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
      appBar: AppBar(title: Text(widget.device.platformName)),
      body: Column(
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
    );
  }
}

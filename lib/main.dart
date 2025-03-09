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

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          devices.clear();
          for (var result in results) {
            if (!devices.contains(result.device)) {
              devices.add(result.device);
            }
          }
        });
      }
    });

    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceControlPage(device: device),
        ),
      );
    }
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
            title: Text(device.platformName),
            subtitle: Text(device.remoteId.toString()),
            onTap: () {
              connectToDevice(device);
              debugPrint("Gerät ausgewählt: ${device.platformName}");
            },
          );
        },
      ),
    );
  }
}

class DeviceControlPage extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceControlPage({super.key, required this.device});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  BluetoothCharacteristic? timerCharacteristic;
  bool isConnected = false;
  int selectedHour = 0;
  int selectedMinute = 0;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  void connectToDevice() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "abcdef01-1234-5678-1234-56789abcdef0") {
          timerCharacteristic = characteristic;
          if (mounted) {
            setState(() {
              isConnected = true;
            });
          }
          debugPrint("Timer-Charakteristik gefunden!");
        }
      }
    }
  }

  void sendTimerToESP() async {
    if (timerCharacteristic != null && isConnected) {
      int totalSeconds = (selectedHour * 3600) + (selectedMinute * 60);
      List<int> timerValue = utf8.encode(totalSeconds.toString());
      await timerCharacteristic!.write(timerValue);
      debugPrint("Timer gesendet: $totalSeconds Sekunden");
    } else {
      debugPrint("Keine Verbindung oder Charakteristik nicht gefunden.");
    }
  }

  void disconnectFromDevice() async {
    await widget.device.disconnect();

    if (mounted) {
      Navigator.pop(context); // Zurück zur Geräteliste
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verbunden mit ${widget.device.platformName}"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Timer einstellen:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: selectedHour,
                items: List.generate(24, (index) => index)
                    .map((hour) => DropdownMenuItem(
                          value: hour,
                          child: Text("$hour h"),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedHour = value!;
                  });
                },
              ),
              const SizedBox(width: 20),
              DropdownButton<int>(
                value: selectedMinute,
                items: List.generate(60, (index) => index)
                    .map((minute) => DropdownMenuItem(
                          value: minute,
                          child: Text("$minute min"),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedMinute = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: sendTimerToESP,
            child: const Text("Timer senden"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: disconnectFromDevice,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Verbindung trennen"),
          ),
        ],
      ),
    );
  }
}

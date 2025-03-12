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
      title: 'SunMask',
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
          final deviceName = result.device.platformName;
          if (!devices.contains(result.device) &&
              (deviceName == "ESP32_Schlafmaske" || deviceName == "SunMask")) {
            devices.add(result.device);
          }
        }
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
  }

  void connectToDevice(BluetoothDevice device, BuildContext context) async {
    await device.connect();
    BluetoothCharacteristic? alarmCharacteristic;
    BluetoothCharacteristic? timerCharacteristic;

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "abcdef03-1234-5678-1234-56789abcdef0") {
          alarmCharacteristic = characteristic;
        }
        if (characteristic.uuid.toString() == "abcdef04-1234-5678-1234-56789abcdef0") {
          timerCharacteristic = characteristic;
        }
      }
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceControlPage(
            device: device,
            alarmCharacteristic: alarmCharacteristic,
            timerCharacteristic: timerCharacteristic,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SunMask Geräte'),
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.platformName),
            subtitle: Text(device.remoteId.toString()),
            onTap: () {
              connectToDevice(device, context);
            },
          );
        },
      ),
    );
  }
}

class DeviceControlPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic? alarmCharacteristic;
  final BluetoothCharacteristic? timerCharacteristic;

  const DeviceControlPage({
    super.key,
    required this.device,
    this.alarmCharacteristic,
    this.timerCharacteristic,
  });

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  TimeOfDay selectedWakeTime = TimeOfDay.now();
  int selectedTimerMinutes = 30;
  bool isConnected = true;
  double buttonWidth = 250; // Einheitliche Button-Größe

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
              const Text("Dauer in Minuten:", style: TextStyle(fontSize: 20)),
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
              child: const Text("OK", style: TextStyle(fontSize: 20)),
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

  void sendWakeTimeToESP() async {
    if (widget.alarmCharacteristic != null) {
      String currentTime = DateFormat("HH:mm").format(DateTime.now());
      String wakeTime = "${selectedWakeTime.hour}:${selectedWakeTime.minute}";

      String combinedData = "$currentTime|$wakeTime";

      await widget.alarmCharacteristic!.write(utf8.encode(combinedData));
      debugPrint("✅ Weckzeit gesendet: $combinedData");
    } else {
      debugPrint("⚠️ Weckzeit-Charakteristik nicht gefunden.");
    }
  }

  void sendTimerToESP() async {
    if (widget.timerCharacteristic != null) {
      String timerValue = selectedTimerMinutes.toString();
      await widget.timerCharacteristic!.write(utf8.encode(timerValue));
      debugPrint("✅ Timer gesendet: $timerValue Minuten");
    } else {
      debugPrint("⚠️ Timer-Charakteristik nicht gefunden.");
    }
  }

  void disconnectFromDevice() async {
    await widget.device.disconnect();
    setState(() {
      isConnected = false;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerät verbunden'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                const Text("Weckzeit", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Letzte Weckzeit: ${selectedWakeTime.format(context)}", style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: () => selectWakeTime(context),
                    child: Text("Weckzeit wählen: ${selectedWakeTime.format(context)}", style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: sendWakeTimeToESP,
                    child: const Text("Weckzeit senden", style: TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Column(
              children: [
                const Text("Timer", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Letzter Timer: $selectedTimerMinutes Minuten", style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: () => selectTimer(context),
                    child: Text("Timer einstellen: $selectedTimerMinutes Minuten", style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: sendTimerToESP,
                    child: const Text("Timer starten", style: TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50), // Mehr Abstand nach unten
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: disconnectFromDevice,
                child: const Text("Verbindung trennen", style: TextStyle(fontSize: 22)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

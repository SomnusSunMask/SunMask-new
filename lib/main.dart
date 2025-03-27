import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Weckzeit & Timer',
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
  final Set<BluetoothDevice> loadingDevices = {};
  BluetoothDevice? selectedDevice;

  bool isShowingConnectionError = false;
  DateTime lastConnectionErrorTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() async {
    setState(() {
      devices.clear();
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        devices.clear();
        for (var result in results) {
          if (!devices.contains(result.device) && result.device.platformName == "SunMask") {
            devices.add(result.device);
          }
        }
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
  }
  void connectToDevice(BluetoothDevice device) async {
    if (!mounted) return;

    setState(() {
      loadingDevices.add(device);
    });

    try {
      await device.connect().timeout(const Duration(seconds: 2));

      BluetoothCharacteristic? alarmCharacteristic;
      BluetoothCharacteristic? timerCharacteristic;
      BluetoothCharacteristic? batteryCharacteristic;

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toString();
          if (uuid == "abcdef03-1234-5678-1234-56789abcdef0") {
            alarmCharacteristic = characteristic;
          } else if (uuid == "abcdef04-1234-5678-1234-56789abcdef0") {
            timerCharacteristic = characteristic;
          } else if (uuid == "abcdef06-1234-5678-1234-56789abcdef0") {
            batteryCharacteristic = characteristic;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        loadingDevices.remove(device);
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceControlPage(
            device: device,
            alarmCharacteristic: alarmCharacteristic,
            timerCharacteristic: timerCharacteristic,
            batteryCharacteristic: batteryCharacteristic,
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Verbindung fehlgeschlagen: $e");
      if (!mounted) return;
      setState(() {
        loadingDevices.remove(device);
      });
      showErrorSnackbar("❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask und versuche es erneut.");
    }
  }

  void showErrorSnackbar(String message) {
    if (!mounted) return;
    final currentTime = DateTime.now();
    if (isShowingConnectionError && currentTime.difference(lastConnectionErrorTime).inSeconds < 5) return;

    isShowingConnectionError = true;
    lastConnectionErrorTime = currentTime;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        isShowingConnectionError = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Somnus-Geräte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: scanForDevices,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(device.platformName),
                if (loadingDevices.contains(device))
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            subtitle: Text(device.remoteId.toString()),
            onTap: () {
              if (!loadingDevices.contains(device)) {
                connectToDevice(device);
              }
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
  final BluetoothCharacteristic? batteryCharacteristic;

  const DeviceControlPage({
    super.key,
    required this.device,
    this.alarmCharacteristic,
    this.timerCharacteristic,
    this.batteryCharacteristic,
  });

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  TimeOfDay? selectedWakeTime;
  int? selectedTimerMinutes;
  TimeOfDay? sentWakeTime;
  int? sentTimerMinutes;
  bool isConnected = true;
  double buttonWidth = double.infinity;

  int? batteryLevel;

  final String batteryUuid = "abcdef06-1234-5678-1234-56789abcdef0";

  @override
  void initState() {
    super.initState();
    readBatteryLevel();
    discoverBatteryCharacteristic();
  }

  Future<void> readBatteryLevel() async {
    try {
      if (widget.batteryCharacteristic != null) {
        await widget.batteryCharacteristic!.read();
        final value = widget.batteryCharacteristic!.lastValue;
        if (value.isNotEmpty) {
          final percent = int.tryParse(utf8.decode(value));
          if (percent != null && mounted) {
            setState(() {
              batteryLevel = percent;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Fehler beim Lesen der Batterie: $e");
    }
  }

  void discoverBatteryCharacteristic() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == batteryUuid) {
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              final decoded = utf8.decode(value);
              final parsed = int.tryParse(decoded);
              if (parsed != null && mounted) {
                setState(() {
                  batteryLevel = parsed;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Fehler beim Entdecken der Battery-Characteristic: $e");
    }
  }

  bool isShowingError = false;
  DateTime lastErrorTime = DateTime.now().subtract(const Duration(seconds: 5));

  String get wakeTimeText => sentWakeTime != null
      ? "${sentWakeTime!.hour.toString().padLeft(2, '0')}:${sentWakeTime!.minute.toString().padLeft(2, '0')}"
      : "Nicht aktiv";

  String get timerText =>
      sentTimerMinutes != null ? "$sentTimerMinutes Minuten" : "Nicht aktiv";

  String get wakeTimeButtonText => selectedWakeTime != null
      ? "Weckzeit wählen – ${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}"
      : "Weckzeit wählen";

  String get timerButtonText => selectedTimerMinutes != null
      ? "Timer wählen – $selectedTimerMinutes Minuten"
      : "Timer wählen";
  Future<void> selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedWakeTime ?? TimeOfDay.now(),
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
          title: const Text("Timer wählen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Dauer in Minuten:", style: TextStyle(fontSize: 18)),
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
              child: const Text("OK", style: TextStyle(fontSize: 18)),
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

  void showErrorAndReturnToList(String message) {
    final currentTime = DateTime.now();

    if (currentTime.difference(lastErrorTime).inSeconds < 5) return;

    isShowingError = true;
    lastErrorTime = currentTime;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          isShowingError = false;
          Navigator.pop(context);
        }
      });
    }
  }

  void sendWakeTimeToESP() async {
    if (widget.alarmCharacteristic != null && selectedWakeTime != null) {
      try {
        String currentTime = DateFormat("HH:mm").format(DateTime.now());
        String wakeTime = "${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}";
        String combinedData = "$currentTime|$wakeTime";

        await widget.alarmCharacteristic!.write(utf8.encode(combinedData));

        if (mounted) {
          setState(() {
            sentWakeTime = selectedWakeTime;
            sentTimerMinutes = null;
          });
        }

        debugPrint("✅ Weckzeit gesendet: $combinedData");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
        showErrorAndReturnToList("❌ Senden fehlgeschlagen! Verbinde die SunMask neu.");
      }
    } else {
      debugPrint("⚠️ Weckzeit-Charakteristik nicht gefunden oder keine Weckzeit gesetzt.");
    }
  }

  void sendTimerToESP() async {
    if (widget.timerCharacteristic != null && selectedTimerMinutes != null) {
      try {
        String currentTime = DateFormat("HH:mm").format(DateTime.now());
        String timerValue = selectedTimerMinutes.toString();
        String combinedData = "$currentTime|$timerValue";

        await widget.timerCharacteristic!.write(utf8.encode(combinedData));

        if (mounted) {
          setState(() {
            sentTimerMinutes = selectedTimerMinutes;
            sentWakeTime = null;
          });
        }

        debugPrint("✅ Timer gesendet: $combinedData");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
        showErrorAndReturnToList("❌ Senden fehlgeschlagen! Verbinde die SunMask neu.");
      }
    } else {
      debugPrint("⚠️ Timer-Charakteristik nicht gefunden oder kein Timer gesetzt.");
    }
  }

  void clearWakeTimeOrTimer() async {
    if (widget.alarmCharacteristic != null || widget.timerCharacteristic != null) {
      try {
        await widget.alarmCharacteristic?.write(utf8.encode("CLEAR"));
        await widget.timerCharacteristic?.write(utf8.encode("CLEAR"));

        if (mounted) {
          setState(() {
            sentWakeTime = null;
            sentTimerMinutes = null;
          });
        }

        debugPrint("✅ Weckzeit/Timer gelöscht");
      } catch (e) {
        debugPrint("⚠️ Löschen fehlgeschlagen: $e");
        showErrorAndReturnToList("❌ Löschen fehlgeschlagen! Verbinde die SunMask neu.");
      }
    } else {
      debugPrint("⚠️ Keine gültige Verbindung zur Löschung vorhanden.");
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'Lichtwecker einstellen',
        style: TextStyle(fontSize: 17), // Schriftgröße angepasst
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: Text(
              batteryLevel != null ? 'Akku: $batteryLevel%' : '...',
              style: const TextStyle(fontSize: 16), // Schriftgröße angepasst
            ),
          ),
        ),
      ],
    ),
    body: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            const Text("Weckzeit", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Aktuelle Weckzeit: $wakeTimeText", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: () => selectWakeTime(context),
                child: Text(wakeTimeButtonText, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: sendWakeTimeToESP,
                child: const Text("Weckzeit senden", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            const Text("Timer", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Aktueller Timer: $timerText", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: () => selectTimer(context),
                child: Text(timerButtonText, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: sendTimerToESP,
                child: const Text("Timer senden", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: buttonWidth,
          child: ElevatedButton(
            onPressed: clearWakeTimeOrTimer,
            child: const Text("Weckzeit/Timer löschen", style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    ),
  );
}


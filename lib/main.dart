// Dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<String, String> storedDeviceNames = {};
  final Map<String, Map<String, dynamic>> storedDeviceData = {};

  BluetoothDevice? selectedDevice;
  bool isShowingConnectionError = false;
  DateTime lastConnectionErrorTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    loadStoredDevices();
    scanForDevices();
  }

  void loadStoredDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceIds = prefs.getStringList('knownDeviceIds') ?? [];

    for (var id in deviceIds) {
      final name = prefs.getString('deviceName_$id');
      final wakeTime = prefs.getString('wakeTime_$id');
      final timerMinutes = prefs.getInt('timerMinutes_$id');

      if (name != null) {
        storedDeviceNames[id] = name;
      }
      storedDeviceData[id] = {
        'wakeTime': wakeTime,
        'timerMinutes': timerMinutes,
      };
    }
    setState(() {});
  }

  Future<void> saveKnownDevice(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> deviceIds = prefs.getStringList('knownDeviceIds') ?? [];

    if (!deviceIds.contains(id)) {
      deviceIds.add(id);
      await prefs.setStringList('knownDeviceIds', deviceIds);
    }
    await prefs.setString('deviceName_$id', name);
    setState(() {
      storedDeviceNames[id] = name;
    });
  }

  void updateStoredDeviceData(String id, String? wakeTime, int? timerMinutes) async {
    final prefs = await SharedPreferences.getInstance();

    if (wakeTime != null) {
      await prefs.setString('wakeTime_$id', wakeTime);
    } else {
      await prefs.remove('wakeTime_$id');
    }

    if (timerMinutes != null) {
      await prefs.setInt('timerMinutes_$id', timerMinutes);
    } else {
      await prefs.remove('timerMinutes_$id');
    }

    setState(() {
      storedDeviceData[id] = {
        'wakeTime': wakeTime,
        'timerMinutes': timerMinutes,
      };
    });
  }

  void deleteKnownDevice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> deviceIds = prefs.getStringList('knownDeviceIds') ?? [];

    deviceIds.remove(id);
    await prefs.setStringList('knownDeviceIds', deviceIds);

    await prefs.remove('deviceName_$id');
    await prefs.remove('wakeTime_$id');
    await prefs.remove('timerMinutes_$id');

    setState(() {
      storedDeviceNames.remove(id);
      storedDeviceData.remove(id);
    });
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
          final id = result.device.remoteId.str;
          final name = result.device.platformName;
          if (name == "SunMask") {
            if (!devices.contains(result.device)) {
              devices.add(result.device);
              if (name.isNotEmpty && !storedDeviceNames.containsKey(id)) {
                storedDeviceNames[id] = name;
              }
            }
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

      await saveKnownDevice(device.remoteId.str, device.platformName);

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
            onDataUpdated: (wakeTime, timerMinutes) {
              updateStoredDeviceData(device.remoteId.str, wakeTime, timerMinutes);
            },
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
  void openStoredDeviceOverview(String id) {
    final data = deviceData[id];
    final wakeTime = data?['wakeTime'];
    final timerMinutes = data?['timerMinutes'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoredDeviceOverviewPage(
          deviceId: id,
          name: storedDeviceNames[id] ?? "Unbekannt",
          wakeTime: wakeTime,
          timerMinutes: timerMinutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDeviceIds = <String>{};
    for (var device in devices) {
      allDeviceIds.add(device.remoteId.str);
    }
    allDeviceIds.addAll(knownDeviceIds);

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
      body: ListView(
        children: allDeviceIds.map((id) {
          final device = devices.firstWhere(
            (d) => d.remoteId.str == id,
            orElse: () => BluetoothDevice(remoteId: DeviceIdentifier(id)),
          );

          final name = storedDeviceNames[id] ?? "Unbekannt";
          final isAvailable = devices.any((d) => d.remoteId.str == id);

          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$name (${isAvailable ? 'verfügbar' : 'nicht verfügbar'})"),
                if (loadingDevices.contains(device))
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (!loadingDevices.contains(device))
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      deleteKnownDevice(id);
                      scanForDevices(); // Liste nach dem Löschen aktualisieren
                    },
                  ),
              ],
            ),
            subtitle: Text(id),
            onTap: () {
              if (isAvailable) {
                connectToDevice(device);
              } else {
                openStoredDeviceOverview(id);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
class StoredDeviceOverviewPage extends StatelessWidget {
  final String deviceId;
  final String name;
  final String? wakeTime;
  final int? timerMinutes;

  const StoredDeviceOverviewPage({
    super.key,
    required this.deviceId,
    required this.name,
    this.wakeTime,
    this.timerMinutes,
  });

  @override
  Widget build(BuildContext context) {
    String wakeText = wakeTime != null ? wakeTime! : "Nicht aktiv";
    String timerText = timerMinutes != null ? "$timerMinutes Minuten" : "Nicht aktiv";

    return Scaffold(
      appBar: AppBar(
        title: Text('Übersicht – $name'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Letzte bekannte Einstellungen", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Text("Weckzeit: $wakeText", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            Text("Timer: $timerText", style: const TextStyle(fontSize: 20)),
          ],
        ),
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
  int? batteryLevel;
  double buttonWidth = double.infinity;

  final String batteryUuid = "abcdef06-1234-5678-1234-56789abcdef0";

  @override
  void initState() {
    super.initState();
    readBatteryLevel();
    listenToBatteryNotifications();
  }

  void readBatteryLevel() async {
    if (widget.batteryCharacteristic != null) {
      try {
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
      } catch (e) {
        debugPrint("⚠️ Akku lesen fehlgeschlagen: $e");
      }
    }
  }

  void listenToBatteryNotifications() async {
    if (widget.batteryCharacteristic != null) {
      try {
        await widget.batteryCharacteristic!.setNotifyValue(true);
        widget.batteryCharacteristic!.onValueReceived.listen((value) {
          final percent = int.tryParse(utf8.decode(value));
          if (percent != null && mounted) {
            setState(() {
              batteryLevel = percent;
            });
          }
        });
      } catch (e) {
        debugPrint("⚠️ Akku-Benachrichtigungen fehlgeschlagen: $e");
      }
    }
  }

  String get wakeTimeText => sentWakeTime != null
      ? "${sentWakeTime!.hour.toString().padLeft(2, '0')}:${sentWakeTime!.minute.toString().padLeft(2, '0')}"
      : "Nicht aktiv";

  String get timerText => sentTimerMinutes != null
      ? "$sentTimerMinutes Minuten"
      : "Nicht aktiv";

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

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("${widget.device.remoteId}_wake", wakeTime);
        await prefs.remove("${widget.device.remoteId}_timer");

        debugPrint("✅ Weckzeit gesendet: $combinedData");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
        Navigator.pop(context);
      }
    }
  }

  void sendTimerToESP() async {
    if (widget.timerCharacteristic != null && selectedTimerMinutes != null) {
      try {
        String timerValue = selectedTimerMinutes.toString();
        await widget.timerCharacteristic!.write(utf8.encode(timerValue));

        if (mounted) {
          setState(() {
            sentTimerMinutes = selectedTimerMinutes;
            sentWakeTime = null;
          });
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt("${widget.device.remoteId}_timer", selectedTimerMinutes!);
        await prefs.remove("${widget.device.remoteId}_wake");

        debugPrint("✅ Timer gesendet: $timerValue Minuten");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
        Navigator.pop(context);
      }
    }
  }

  void clearWakeTimeOrTimer() async {
    try {
      await widget.alarmCharacteristic?.write(utf8.encode("CLEAR"));
      await widget.timerCharacteristic?.write(utf8.encode("CLEAR"));

      setState(() {
        sentWakeTime = null;
        sentTimerMinutes = null;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("${widget.device.remoteId}_wake");
      await prefs.remove("${widget.device.remoteId}_timer");

      debugPrint("✅ Weckzeit/Timer gelöscht");
    } catch (e) {
      debugPrint("⚠️ Löschen fehlgeschlagen: $e");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lichtwecker einstellen', style: TextStyle(fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                batteryLevel != null ? 'Akku: $batteryLevel%' : '...',
                style: const TextStyle(fontSize: 16),
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
}

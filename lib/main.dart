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
  List<String> storedDevices = [];
  Map<String, String> storedDeviceNames = {};
  BluetoothDevice? selectedDevice;

  bool isShowingConnectionError = false;
  DateTime lastConnectionErrorTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    loadKnownDevices();
    scanForDevices();
  }

  Future<void> loadKnownDevices() async {
    final prefs = await SharedPreferences.getInstance();
    storedDevices = prefs.getStringList('storedDevices') ?? [];
    final nameMap = prefs.getString('deviceNameMap');
    if (nameMap != null) {
      storedDeviceNames = Map<String, String>.from(jsonDecode(nameMap));
    }
    setState(() {});
  }

  Future<void> saveKnownDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('storedDevices', storedDevices);
    await prefs.setString('deviceNameMap', jsonEncode(storedDeviceNames));
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

          if (name == "SunMask" && !devices.contains(result.device)) {
            devices.add(result.device);
          }

          if (name.isNotEmpty && !storedDeviceNames.containsKey(id)) {
            storedDeviceNames[id] = name;
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

      final id = device.remoteId.str;
      if (!storedDevices.contains(id)) {
        storedDevices.add(id);
      }
      storedDeviceNames[id] = device.platformName;
      await saveKnownDevices();

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

  void removeStoredDevice(String deviceId) async {
    storedDevices.remove(deviceId);
    storedDeviceNames.remove(deviceId);
    await saveKnownDevices();
    setState(() {});
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
    List<String> allDeviceIds = {
      ...devices.map((d) => d.remoteId.str),
      ...storedDevices
    }.toList();

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
        itemCount: allDeviceIds.length,
        itemBuilder: (context, index) {
          final id = allDeviceIds[index];
          final device = devices.firstWhere(
              (d) => d.remoteId.str == id,
              orElse: () => BluetoothDevice(remoteId: DeviceIdentifier(id)));
          final isAvailable = devices.any((d) => d.remoteId.str == id);
          final name = isAvailable
              ? device.platformName
              : (storedDeviceNames[id] ?? "Unbekanntes Gerät");

          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "$name (${isAvailable ? 'verfügbar' : 'nicht verfügbar'})",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (loadingDevices.contains(device))
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (storedDevices.contains(id))
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => removeStoredDevice(id),
                  ),
              ],
            ),
            subtitle: Text(id),
            onTap: () async {
              if (isAvailable && !loadingDevices.contains(device)) {
                connectToDevice(device);
              } else if (storedDevices.contains(id)) {
                final prefs = await SharedPreferences.getInstance();
                final wakeTime = prefs.getString('lastWakeTime_$id');
                final timerMinutes = prefs.getInt('lastTimerMinutes_$id');
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceOverviewPage(
                      deviceId: id,
                      lastWakeTime: wakeTime,
                      lastTimerMinutes: timerMinutes,
                    ),
                  ),
                );
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
  int? batteryLevel;
  double buttonWidth = double.infinity;

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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastWakeTime_${widget.device.remoteId.str}', wakeTime);
        await prefs.remove('lastTimerMinutes_${widget.device.remoteId.str}');

        if (mounted) {
          setState(() {
            sentWakeTime = selectedWakeTime;
            sentTimerMinutes = null;
          });
        }

        debugPrint("✅ Weckzeit gesendet: $combinedData");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
      }
    }
  }

  void sendTimerToESP() async {
    if (widget.timerCharacteristic != null && selectedTimerMinutes != null) {
      try {
        String timerValue = selectedTimerMinutes.toString();
        await widget.timerCharacteristic!.write(utf8.encode(timerValue));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastTimerMinutes_${widget.device.remoteId.str}', selectedTimerMinutes!);
        await prefs.remove('lastWakeTime_${widget.device.remoteId.str}');

        if (mounted) {
          setState(() {
            sentTimerMinutes = selectedTimerMinutes;
            sentWakeTime = null;
          });
        }

        debugPrint("✅ Timer gesendet: $timerValue Minuten");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
      }
    }
  }

  void clearWakeTimeOrTimer() async {
    try {
      await widget.alarmCharacteristic?.write(utf8.encode("CLEAR"));
      await widget.timerCharacteristic?.write(utf8.encode("CLEAR"));

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastWakeTime_${widget.device.remoteId.str}');
      await prefs.remove('lastTimerMinutes_${widget.device.remoteId.str}');

      if (mounted) {
        setState(() {
          sentWakeTime = null;
          sentTimerMinutes = null;
        });
      }

      debugPrint("✅ Weckzeit/Timer gelöscht");
    } catch (e) {
      debugPrint("⚠️ Löschen fehlgeschlagen: $e");
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
class DeviceOverviewPage extends StatefulWidget {
  final String deviceId;
  final String? lastWakeTime;
  final int? lastTimerMinutes;

  const DeviceOverviewPage({
    super.key,
    required this.deviceId,
    this.lastWakeTime,
    this.lastTimerMinutes,
  });

  @override
  State<DeviceOverviewPage> createState() => _DeviceOverviewPageState();
}

class _DeviceOverviewPageState extends State<DeviceOverviewPage> {
  bool isConnecting = false;

  String get wakeTimeText =>
      widget.lastWakeTime != null ? widget.lastWakeTime! : "Nicht aktiv";

  String get timerText =>
      widget.lastTimerMinutes != null ? "${widget.lastTimerMinutes} Minuten" : "Nicht aktiv";

  void showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void connectToDeviceById() async {
    setState(() {
      isConnecting = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      BluetoothDevice? targetDevice;

      final results = await FlutterBluePlus.scanResults.first;
      for (var result in results) {
        if (result.device.remoteId.str == widget.deviceId) {
          targetDevice = result.device;
          break;
        }
      }

      await FlutterBluePlus.stopScan();

      if (targetDevice == null) {
        throw Exception("Gerät nicht gefunden");
      }

      await targetDevice.connect(timeout: const Duration(seconds: 6));
      List<BluetoothService> services = await targetDevice.discoverServices();

      BluetoothCharacteristic? alarmCharacteristic;
      BluetoothCharacteristic? timerCharacteristic;
      BluetoothCharacteristic? batteryCharacteristic;

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

      if (alarmCharacteristic == null || timerCharacteristic == null) {
        throw Exception("Charakteristiken nicht gefunden");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceControlPage(
            device: targetDevice!,
            alarmCharacteristic: alarmCharacteristic,
            timerCharacteristic: timerCharacteristic,
            batteryCharacteristic: batteryCharacteristic,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showErrorSnackbar("❌ Verbindung fehlgeschlagen! Starte die SunMask neu.");
    } finally {
      if (mounted) {
        setState(() {
          isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Übersicht – SunMask', style: TextStyle(fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Weckzeit", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Aktuelle Weckzeit: $wakeTimeText", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 48),
            const Text("Timer", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Aktueller Timer: $timerText", style: const TextStyle(fontSize: 20)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConnecting ? null : connectToDeviceById,
                child: Text(
                  isConnecting ? "Verbinden..." : "SunMask verbinden",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

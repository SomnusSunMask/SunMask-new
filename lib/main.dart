import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import für die Bildschirmrotation-Kontrolle
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Stellt sicher, dass alles initialisiert ist
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Nur Hochformat erlaubt
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
  final Set<BluetoothDevice> loadingDevices = {}; // 🔄 Trackt Geräte, die sich verbinden
  BluetoothDevice? selectedDevice;

  bool isShowingConnectionError = false; // 🔹 Fehlerblocker für 5 Sekunden
  DateTime lastConnectionErrorTime = DateTime.fromMillisecondsSinceEpoch(0); // 🔹 Zeitpunkt letzter Fehler

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
    final currentContext = context; // 🔹 Speichert `context`, um Fehler zu vermeiden

    if (isShowingConnectionError &&
        DateTime.now().difference(lastConnectionErrorTime).inSeconds < 5) {
      return; // ⛔ Verhindert mehrfach auftretende Fehlermeldungen
    }

    setState(() {
      loadingDevices.add(device); // 🔄 Ladeanimation aktivieren
    });

    try {
      await device.connect().timeout(const Duration(seconds: 2)); // ⏳ Verbindung mit Timeout

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

      setState(() {
        loadingDevices.remove(device); // 🔄 Ladeanimation stoppen
      });

      if (mounted) {
        Navigator.push(
          currentContext,
          MaterialPageRoute(
            builder: (context) => DeviceControlPage(
              device: device,
              alarmCharacteristic: alarmCharacteristic,
              timerCharacteristic: timerCharacteristic,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Verbindung fehlgeschlagen: $e");

      setState(() {
        loadingDevices.remove(device); // 🔄 Ladeanimation stoppen
      });

      if (mounted) {
        showErrorSnackbar(currentContext, "❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask und versuche es erneut.");
      }
    }
  }

  void showErrorSnackbar(BuildContext context, String message) {
    final currentTime = DateTime.now();
    if (isShowingConnectionError && currentTime.difference(lastConnectionErrorTime).inSeconds < 5) return;

    isShowingConnectionError = true;
    lastConnectionErrorTime = currentTime; // 🔹 Speichert die Zeit des Fehlers

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5), // ⏳ 5 Sekunden Fehlermeldung
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      isShowingConnectionError = false; // 🔓 Sperre nach 5 Sekunden aufheben
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🔹 Gerät links, Ladekreis rechts
              children: [
                Text(device.platformName),
                if (loadingDevices.contains(device)) // 🔄 Ladeanimation nur für aktuelles Gerät
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
  TimeOfDay? selectedWakeTime;
  int? selectedTimerMinutes;
  TimeOfDay? sentWakeTime;
  int? sentTimerMinutes;
  bool isConnected = true;
  double buttonWidth = double.infinity;

  bool isShowingError = false; // 🛑 Verhindert doppelte Fehlermeldungen
  DateTime lastErrorTime = DateTime.now().subtract(const Duration(seconds: 5)); // ⏳ Startwert: keine Sperre

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

    if (currentTime.difference(lastErrorTime).inSeconds < 5) return; // 🚫 Sperrt neue Fehler für 5 Sekunden

    isShowingError = true; // 🛑 Sperre aktivieren
    lastErrorTime = currentTime; // 🕒 Fehlerzeitpunkt speichern

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5), // ⏳ 5 Sekunden Fehleranzeige
        ),
      );

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          isShowingError = false; // ✅ Sperre nach 5 Sek. wirklich aufheben
          Navigator.pop(context); // 🔄 Zurück zur Geräteliste
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
            sentTimerMinutes = null; // Timer zurücksetzen
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
        String timerValue = selectedTimerMinutes.toString();
        await widget.timerCharacteristic!.write(utf8.encode(timerValue));

        if (mounted) {
          setState(() {
            sentTimerMinutes = selectedTimerMinutes;
            sentWakeTime = null; // Weckzeit zurücksetzen
          });
        }

        debugPrint("✅ Timer gesendet: $timerValue Minuten");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
        showErrorAndReturnToList("❌ Senden fehlgeschlagen! Verbinde die SunMask neu.");
      }
    } else {
      debugPrint("⚠️ Timer-Charakteristik nicht gefunden oder kein Timer gesetzt.");
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
        title: const Text('Lichtwecker einstellen'),
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
              onPressed: disconnectFromDevice,
              child: const Text("Verbindung trennen", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

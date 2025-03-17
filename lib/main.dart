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
 
   @override
void initState() {
  super.initState();
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
 
   void connectToDevice(BluetoothDevice device, BuildContext context) async {
     setState(() {
       loadingDevices.add(device); // 🔄 Ladeanimation aktivieren
     });
 
     try {
       await device.connect().timeout(Duration(seconds: 2)); // ⏳ Verbindung mit Timeout
 
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
     } catch (e) {
       debugPrint("⚠️ Verbindung fehlgeschlagen: $e");
 
       setState(() {
         loadingDevices.remove(device); // 🔄 Ladeanimation stoppen
       });
 
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('❌ Verbindung fehlgeschlagen! Bitte erneut versuchen.'),
             duration: Duration(seconds: 3),
           ),
         );
       }
     }
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
                 connectToDevice(device, context);
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

  BluetoothCharacteristic? _alarmCharacteristic;
  BluetoothCharacteristic? _timerCharacteristic;

  @override
  void initState() {
    super.initState();
    _alarmCharacteristic = widget.alarmCharacteristic;
    _timerCharacteristic = widget.timerCharacteristic;
  }
}


 
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
 
 void sendWakeTimeToESP() async {
   if (_alarmCharacteristic != null && selectedWakeTime != null) {
     try {
       String currentTime = DateFormat("HH:mm").format(DateTime.now());
       String wakeTime = "${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}";
 
       String combinedData = "$currentTime|$wakeTime";
 
       await _alarmCharacteristic!.write(utf8.encode(combinedData)); // 🔹 Daten senden
 
       if (mounted) {
         setState(() {
           sentWakeTime = selectedWakeTime;
           sentTimerMinutes = null; // Timer zurücksetzen
         });
       }
 
       debugPrint("✅ Weckzeit gesendet: $combinedData");
     } catch (e) {
       debugPrint("⚠️ Senden fehlgeschlagen: $e");
 
       if (!mounted) return;
       final messenger = ScaffoldMessenger.of(context); // 🔹 `context` vor `await` speichern
 
       await Future.delayed(Duration(seconds: 2)); // 🔹 Wartezeit von 2 Sekunden hinzufügen
 
       if (mounted) {
         messenger.showSnackBar(
           SnackBar(
             content: Text('❌ Senden fehlgeschlagen. Starte die SunMask neu.'),
             duration: Duration(seconds: 3),
           ),
         );
       }
     }
   } else {
     debugPrint("⚠️ Weckzeit-Charakteristik nicht gefunden oder keine Weckzeit gesetzt.");
   }
 }
 
 
 void sendTimerToESP() async {
   if (_timerCharacteristic != null && selectedTimerMinutes != null) {
     try {
       String timerValue = selectedTimerMinutes.toString();
 
       await _timerCharacteristic!.write(utf8.encode(timerValue)); // 🔹 Daten senden
 
       if (mounted) {
         setState(() {
           sentTimerMinutes = selectedTimerMinutes;
           sentWakeTime = null; // Weckzeit zurücksetzen
         });
       }
 
       debugPrint("✅ Timer gesendet: $timerValue Minuten");
     } catch (e) {
       debugPrint("⚠️ Senden fehlgeschlagen: $e");
 
       if (!mounted) return;
       final messenger = ScaffoldMessenger.of(context); // 🔹 `context` vor `await` speichern
 
       await Future.delayed(Duration(seconds: 2)); // 🔹 Wartezeit von 2 Sekunden hinzufügen
 
       if (mounted) {
         messenger.showSnackBar(
           SnackBar(
             content: Text('❌ Senden fehlgeschlagen. Starte die SunMask neu.'),
             duration: Duration(seconds: 3),
           ),
         );
       }
     }
   } else {
     debugPrint("⚠️ Timer-Charakteristik nicht gefunden oder kein Timer gesetzt.");
   }
 }
 
Future<void> reconnectToDevice() async {
  if (!mounted) return; // Verhindert den Zugriff, falls das Widget nicht mehr existiert

  final currentContext = context; // Speichert `context` vor dem ersten `await`
  final messenger = ScaffoldMessenger.of(currentContext); // Speichert `ScaffoldMessenger` ebenfalls vorher

  try {
    await widget.device.connect().timeout(const Duration(seconds: 2));

    if (!mounted) return; // Nach dem await prüfen, ob Widget noch existiert

    // 🔹 BLE-Charakteristiken nach dem erneuten Verbinden neu abrufen
    BluetoothCharacteristic? alarmCharacteristic;
    BluetoothCharacteristic? timerCharacteristic;
    List<BluetoothService> services = await widget.device.discoverServices();
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

    if (!mounted) return; // Nochmal prüfen, ob Widget noch existiert

    setState(() {
  isConnected = true;
  _alarmCharacteristic = widget.alarmCharacteristic;
  _timerCharacteristic = widget.timerCharacteristic;
});


    debugPrint("✅ Erneute Verbindung erfolgreich");
  } catch (e) {
    debugPrint("❌ Erneute Verbindung fehlgeschlagen: $e");

    if (!mounted) return; // Absicherung nach `await`

    messenger.showSnackBar(
      const SnackBar(
        content: Text('❌ Erneute Verbindung fehlgeschlagen!'),
        duration: Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(currentContext); // Zurück zur Geräteliste
      }
    });
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
        actions: [
          TextButton(
            onPressed: reconnectToDevice,
            child: const Text(
              "Erneut verbinden",
              style: TextStyle(fontSize: 16), // Standard-Button-Farbe bleibt erhalten
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
              onPressed: disconnectFromDevice,
              child: const Text("Verbindung trennen", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

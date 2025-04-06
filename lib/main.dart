import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ));
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const blaugrau = Color(0xFF7A9CA3);

    return MaterialApp(
      title: 'SunMask',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: blaugrau),
          titleTextStyle: TextStyle(color: blaugrau, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: blaugrau),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: blaugrau),
          bodyMedium: TextStyle(color: blaugrau),
          titleLarge: TextStyle(color: blaugrau),
          titleMedium: TextStyle(color: blaugrau),
          titleSmall: TextStyle(color: blaugrau),
          labelLarge: TextStyle(color: blaugrau),
          labelMedium: TextStyle(color: blaugrau),
          labelSmall: TextStyle(color: blaugrau),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blaugrau,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: blaugrau,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: blaugrau,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: blaugrau,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.white,
          contentTextStyle: TextStyle(color: Colors.black),
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(color: blaugrau, fontSize: 20),
          contentTextStyle: TextStyle(color: blaugrau),
        ),
        timePickerTheme: const TimePickerThemeData(
          backgroundColor: Colors.black,
          dialHandColor: blaugrau,
          dialTextColor: Colors.white,
          entryModeIconColor: blaugrau,
          hourMinuteTextColor: Colors.white,
          hourMinuteColor: blaugrau,
          hourMinuteTextStyle: TextStyle(color: blaugrau, fontSize: 18),
          helpTextStyle: TextStyle(color: blaugrau),
          dayPeriodColor: blaugrau,
          dayPeriodTextColor: Colors.white,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: blaugrau,
          selectionColor: Color(0x807A9CA3),
          selectionHandleColor: blaugrau,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: blaugrau),
        ),
      ),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('de', ''),
      ],
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

      showErrorSnackbar(
        "❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask, den Refresh-Button und versuche es dann erneut.",
      );
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
    if (isShowingConnectionError &&
        currentTime.difference(lastConnectionErrorTime).inSeconds < 5) {
      return;
    }

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
    const blaugrau = Color(0xFF7A9CA3);

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
            orElse: () => BluetoothDevice(remoteId: DeviceIdentifier(id)),
          );
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
                    style: const TextStyle(color: blaugrau),
                  ),
                ),
                if (loadingDevices.contains(device))
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (storedDevices.contains(id)) ...[
                  if (isAvailable)
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: blaugrau),
                      onPressed: () async {
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
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: blaugrau),
                    onPressed: () => removeStoredDevice(id),
                  ),
                ],
              ],
            ),
            subtitle: Text(
  "Gerätenummer: $id",
  style: const TextStyle(color: blaugrau),
),
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


// Teil 2: DeviceControlPage komplett + DeviceOverviewPage


// DeviceControlPage - Kompletter Code

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
  final TextEditingController timerHoursController = TextEditingController();
  final TextEditingController timerMinutesController = TextEditingController();

  TimeOfDay? selectedWakeTime;
  int? selectedTimerMinutes;
  TimeOfDay? sentWakeTime;
  int? sentTimerMinutes;
  DateTime? timerStartTime;
  int? batteryLevel;
  double buttonWidth = double.infinity;

  Timer? countdownTimer;
  Timer? timerCountdown;

  bool wakeTimeExpired = false;
  bool timerExpired = false;

  @override
  void initState() {
    super.initState();
    readBatteryLevel();
    listenToBatteryNotifications();
    loadSavedData();
    startCountdownTimer();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    timerCountdown?.cancel();
    try {
      widget.device.disconnect();
    } catch (e) {
      debugPrint('⚠️ Fehler beim Trennen der Verbindung (dispose): $e');
    }
    super.dispose();
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

  void startCountdownTimer() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        checkWakeTimeExpired();
        setState(() {});
      }
    });
  }

  void startTimerCountdown() {
    timerCountdown?.cancel();
    timerCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final wakeTime = prefs.getString('lastWakeTime_${widget.device.remoteId.str}');
    final timerMinutes = prefs.getInt('lastTimerMinutes_${widget.device.remoteId.str}');
    final timerStartTimestamp = prefs.getInt('timerStartTime_${widget.device.remoteId.str}');

    if (!mounted) return;

    setState(() {
      if (wakeTime != null) {
        final parts = wakeTime.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            sentWakeTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }

      if (timerMinutes != null) {
        sentTimerMinutes = timerMinutes;
      }

      if (timerStartTimestamp != null) {
        timerStartTime = DateTime.fromMillisecondsSinceEpoch(timerStartTimestamp);
      }
    });
  }

  void checkWakeTimeExpired() {
    if (sentWakeTime != null) {
      final now = TimeOfDay.now();
      if (now.hour > sentWakeTime!.hour ||
          (now.hour == sentWakeTime!.hour && now.minute >= sentWakeTime!.minute)) {
        if (!wakeTimeExpired) {
          setState(() {
            wakeTimeExpired = true;
          });
        }
      }
    }
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (hours > 0) parts.add("$hours Stunden");
    if (minutes > 0 || hours == 0) parts.add("$minutes Minuten");
    return parts.join(", ");
  }

  String wakeTimeButtonText() {
    if (selectedWakeTime != null) {
      return "Weckzeit wählen – ${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}";
    }
    return "Weckzeit wählen";
  }

  String timerButtonText() {
    if (selectedTimerMinutes != null) {
      final hours = selectedTimerMinutes! ~/ 60;
      final minutes = selectedTimerMinutes! % 60;
      return "Timer wählen – ${hours}h ${minutes}min";
    }
    return "Timer wählen";
  }

  String get wakeTimeText {
    if (wakeTimeExpired && sentWakeTime != null) {
      final time = "${sentWakeTime!.hour.toString().padLeft(2, '0')}:${sentWakeTime!.minute.toString().padLeft(2, '0')}";
      return "Weckzeit abgelaufen ($time)";
    }
    return sentWakeTime != null
        ? "${sentWakeTime!.hour.toString().padLeft(2, '0')}:${sentWakeTime!.minute.toString().padLeft(2, '0')}"
        : "Nicht aktiv";
  }

  String get timerText {
    if (timerExpired && sentTimerMinutes != null) {
      final originalHours = (sentTimerMinutes! ~/ 60);
      final originalMinutes = (sentTimerMinutes! % 60);
      return "Timer abgelaufen (${originalHours}h ${originalMinutes}min)";
    } else if (sentTimerMinutes != null && timerStartTime != null) {
      final elapsed = DateTime.now().difference(timerStartTime!);
      final remaining = Duration(minutes: sentTimerMinutes!) - elapsed;
      if (remaining.isNegative) {
        timerExpired = true;
        return "Timer abgelaufen (${sentTimerMinutes! ~/ 60}h ${sentTimerMinutes! % 60}min)";
      } else {
        return formatDuration(remaining);
      }
    }
    return sentTimerMinutes != null
        ? "${sentTimerMinutes! ~/ 60} Stunden ${sentTimerMinutes! % 60} Minuten"
        : "Nicht aktiv";
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Die anderen Methoden wie selectWakeTime, selectTimer, sendWakeTimeToESP, sendTimerToESP, clearWakeTimeOrTimer und build folgen jetzt...
// DeviceControlPage - Kompletter Code Teil 2

  Future<void> selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedWakeTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7A9CA3),
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogTheme(
              backgroundColor: Colors.black,
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.white,
              selectionColor: Color(0x80000000),
              selectionHandleColor: Colors.white,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(
                color: Color(0xFF7A9CA3),
                fontSize: 16,
              ),
              floatingLabelStyle: TextStyle(
                color: Color(0xFF7A9CA3),
                fontSize: 16,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedWakeTime) {
      setState(() {
        selectedWakeTime = picked;
      });
    }
  }

  Future<void> selectTimer(BuildContext context) async {
    timerHoursController.text = selectedTimerMinutes != null
        ? (selectedTimerMinutes! ~/ 60).toString()
        : '';
    timerMinutesController.text = selectedTimerMinutes != null
        ? (selectedTimerMinutes! % 60).toString()
        : '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Timer wählen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: timerHoursController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF7A9CA3)),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF7A9CA3)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF7A9CA3)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Stunden",
                          style: TextStyle(color: Color(0xFF7A9CA3)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: timerMinutesController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF7A9CA3)),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF7A9CA3)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF7A9CA3)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Minuten",
                          style: TextStyle(color: Color(0xFF7A9CA3)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Abbrechen", style: TextStyle(fontSize: 18)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("OK", style: TextStyle(fontSize: 18)),
              onPressed: () {
                final enteredHours = int.tryParse(timerHoursController.text) ?? 0;
                final enteredMinutes = int.tryParse(timerMinutesController.text) ?? 0;
                final totalMinutes = enteredHours * 60 + enteredMinutes;
                Navigator.of(context).pop(totalMinutes);
              },
            ),
          ],
        );
      },
    ).then((minutes) {
      if (minutes != null) {
        setState(() {
          selectedTimerMinutes = minutes;
        });
      }
    });
  }

  void sendWakeTimeToESP() async {
    if (!widget.device.isConnected) {
      showErrorSnackbar("❌ Senden fehlgeschlagen! Verbinde die SunMask neu.");
      Navigator.pop(context);
      return;
    }

    if (widget.alarmCharacteristic != null && selectedWakeTime != null) {
      try {
        String currentTime = DateFormat("HH:mm").format(DateTime.now());
        String wakeTime =
            "${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}";
        String combinedData = "$currentTime|$wakeTime";

        await widget.alarmCharacteristic!.write(utf8.encode(combinedData));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastWakeTime_${widget.device.remoteId.str}', wakeTime);
        await prefs.remove('lastTimerMinutes_${widget.device.remoteId.str}');
        await prefs.remove('timerStartTime_${widget.device.remoteId.str}');

        if (mounted) {
          setState(() {
            sentWakeTime = selectedWakeTime;
            sentTimerMinutes = null;
            wakeTimeExpired = false;
            timerExpired = false;
            timerStartTime = null;
          });
        }

        debugPrint("✅ Weckzeit gesendet: $combinedData");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
      }
    }
  }

  void sendTimerToESP() async {
    if (!widget.device.isConnected) {
      showErrorSnackbar("❌ Senden fehlgeschlagen! Verbinde die SunMask neu.");
      Navigator.pop(context);
      return;
    }

    if (widget.timerCharacteristic != null && selectedTimerMinutes != null) {
      try {
        String timerValue = selectedTimerMinutes.toString();
        await widget.timerCharacteristic!.write(utf8.encode(timerValue));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastTimerMinutes_${widget.device.remoteId.str}', selectedTimerMinutes!);
        await prefs.setInt('timerStartTime_${widget.device.remoteId.str}', DateTime.now().millisecondsSinceEpoch);
        await prefs.remove('lastWakeTime_${widget.device.remoteId.str}');

        if (mounted) {
          setState(() {
            sentTimerMinutes = selectedTimerMinutes;
            sentWakeTime = null;
            timerExpired = false;
            wakeTimeExpired = false;
            timerStartTime = DateTime.now();
          });
          startTimerCountdown();
        }

        debugPrint("✅ Timer gesendet: $timerValue Minuten");
      } catch (e) {
        debugPrint("⚠️ Senden fehlgeschlagen: $e");
      }
    }
  }

  void clearWakeTimeOrTimer() async {
    if (!widget.device.isConnected) {
      showErrorSnackbar("❌ Löschen fehlgeschlagen! Verbinde die SunMask neu.");
      Navigator.pop(context);
      return;
    }
    try {
      await widget.alarmCharacteristic?.write(utf8.encode("CLEAR"));
      await widget.timerCharacteristic?.write(utf8.encode("CLEAR"));

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastWakeTime_${widget.device.remoteId.str}');
      await prefs.remove('lastTimerMinutes_${widget.device.remoteId.str}');
      await prefs.remove('timerStartTime_${widget.device.remoteId.str}');

      if (mounted) {
        setState(() {
          sentWakeTime = null;
          sentTimerMinutes = null;
          timerExpired = false;
          wakeTimeExpired = false;
          timerStartTime = null;
        });
      }

      debugPrint("✅ Weckzeit/Timer gelöscht");
    } catch (e) {
      debugPrint("⚠️ Löschen fehlgeschlagen: $e");
    }
  }
// DeviceControlPage - Kompletter Code Teil 3

  @override
  Widget build(BuildContext context) {
    const blaugrau = Color(0xFF7A9CA3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lichtwecker einstellen', style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            try {
              await widget.device.disconnect();
            } catch (e) {
              debugPrint('⚠️ Fehler beim Trennen der Verbindung: $e');
            }

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                batteryLevel != null ? 'Akku: $batteryLevel%' : '',
                style: const TextStyle(
                  color: blaugrau,
                  fontSize: 16,
                ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blaugrau,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => selectWakeTime(context),
                  child: Text(wakeTimeButtonText(), style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blaugrau,
                    foregroundColor: Colors.white,
                  ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blaugrau,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => selectTimer(context),
                  child: Text(timerButtonText(), style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blaugrau,
                    foregroundColor: Colors.white,
                  ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: blaugrau,
                foregroundColor: Colors.white,
              ),
              onPressed: clearWakeTimeOrTimer,
              child: const Text("Weckzeit/Timer löschen", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}




// -------------------------
// DeviceOverviewPage
// -------------------------

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
  BluetoothDevice? targetDevice;
  late final StreamSubscription<List<ScanResult>> scanSubscription;

  int? lastTimerMinutes;
  int? timerStartTimestamp;
  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();
    loadTimerStartTime();
    startCountdownTimer();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    scanSubscription.cancel();
    super.dispose();
  }

  void startCountdownTimer() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> loadTimerStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastTimerMinutes = widget.lastTimerMinutes;
      timerStartTimestamp = prefs.getInt('timerStartTime_${widget.deviceId}');
    });
  }

  String get wakeTimeText {
    if (widget.lastWakeTime != null) {
      final now = TimeOfDay.now();
      final parts = widget.lastWakeTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        if (now.hour > hour || (now.hour == hour && now.minute >= minute)) {
          return "Weckzeit abgelaufen (${widget.lastWakeTime!})";
        } else {
          return widget.lastWakeTime!;
        }
      }
    }
    return "Nicht aktiv";
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (hours > 0) parts.add("$hours Stunden");
    if (minutes > 0 || hours == 0) parts.add("$minutes Minuten");
    return parts.join(", ");
  }

  String get timerText {
    if (lastTimerMinutes != null && timerStartTimestamp != null) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(timerStartTimestamp!);
      final now = DateTime.now();
      final totalDuration = Duration(minutes: lastTimerMinutes!);
      final elapsed = now.difference(startTime);
      final remaining = totalDuration - elapsed;

      if (remaining.isNegative) {
        final originalHours = (lastTimerMinutes! ~/ 60);
        final originalMinutes = (lastTimerMinutes! % 60);
        return "Timer abgelaufen (${originalHours}h ${originalMinutes}min)";
      } else {
        return formatDuration(remaining);
      }
    }
    return "Nicht aktiv";
  }

  void showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> connectToDeviceById() async {
    setState(() {
      isConnecting = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (var result in results) {
          if (result.device.remoteId.str == widget.deviceId) {
            targetDevice = result.device;
            await FlutterBluePlus.stopScan();
            await scanSubscription.cancel();
            await establishConnection(targetDevice!);
            return;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 6));

      if (targetDevice == null) {
        throw Exception("Gerät nicht gefunden");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showErrorSnackbar("❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask, den Refresh-Button und versuche es dann erneut.");
    } finally {
      if (mounted) {
        setState(() {
          isConnecting = false;
        });
      }
    }
  }

  Future<void> establishConnection(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 6));
      List<BluetoothService> services = await device.discoverServices();

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
            device: device,
            alarmCharacteristic: alarmCharacteristic,
            timerCharacteristic: timerCharacteristic,
            batteryCharacteristic: batteryCharacteristic,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showErrorSnackbar("❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask, den Refresh-Button und versuche es dann erneut.");
    }
  }

  @override
  Widget build(BuildContext context) {
    const blaugrau = Color(0xFF7A9CA3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eingestellter Lichtwecker', style: TextStyle(fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Weckzeit", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("Aktuelle Weckzeit: $wakeTimeText", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 181),
            const Text("Timer", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Aktueller Timer: $timerText", style: const TextStyle(fontSize: 20)),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: blaugrau),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Zum Ändern oder Löschen von Timer oder Weckzeit bitte die SunMask starten und verbinden.",
                    style: TextStyle(color: blaugrau),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(blaugrau),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
                ),
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


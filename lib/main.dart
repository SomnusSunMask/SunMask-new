import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
        expansionTileTheme: ExpansionTileThemeData(
        iconColor: Color(0xFF7A9CA3), // Blaugrau für den Standard-Pfeil
       ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: blaugrau,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.white,
          contentTextStyle: TextStyle(color: Colors.black),
        ),
        dialogTheme: const DialogThemeData(
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
          floatingLabelStyle: TextStyle(color: blaugrau),
          hintStyle: TextStyle(color: blaugrau),
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

class _BLEHomePageState extends State<BLEHomePage> with WidgetsBindingObserver {
  final List<BluetoothDevice> devices = [];
  final Set<BluetoothDevice> loadingDevices = {};
  List<String> storedDevices = [];
  Map<String, String> storedDeviceNames = {};
  BluetoothDevice? selectedDevice;
  bool isRequirementDialogOpen = false;

  bool isShowingConnectionError = false;
  DateTime lastConnectionErrorTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    showAppIntroIfFirstStart();
    loadKnownDevices();
    checkBluetoothAndLocation();
    scanForDevices();
  }

  @override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}

  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    // Wenn App wieder sichtbar wird, erneut prüfen!
    checkBluetoothAndLocation();
  }
}

  void showAppIntroIfFirstStart() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownIntro = prefs.getBool('appFirstStartShown') ?? false;

    if (!hasShownIntro) {
      await prefs.setBool('appFirstStartShown', true);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF7A9CA3), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'SunMask Verbindungsanleitung',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '1. Starte deine SunMask und drücke den Startknopf.\n\n'
                  '2. Aktualisiere oben rechts, um nach Geräten zu suchen.\n\n'
                  '3. Tippe auf die angezeigte "SunMask", um dich zu verbinden.\n\n'
                  '4. Du hast anschließend 60 Sekunden* Zeit, um Weckzeit oder Timer einzustellen.\n\n'
                  'Bei Unklarheiten kannst du später jederzeit auf das Fragezeichen in der Geräteübersicht tippen.',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 13),
                Text(
                  '* Um Akku zu sparen, wird Bluetooth 60 Sekunden nach dem Start deaktiviert.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('Verstanden'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
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
    await checkBluetoothAndLocation();

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

    // ❗️ Hier: Services lesen
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
      "❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask, aktualisiere die Geräteliste und versuche es dann erneut.",
    );
  }
}

  void removeStoredDevice(String deviceId) async {
    storedDevices.remove(deviceId);
    storedDeviceNames.remove(deviceId);
    await saveKnownDevices();
    setState(() {});
  }

  Future<void> checkBluetoothAndLocation() async {
    const blaugrau = Color(0xFF7A9CA3);
    final isAndroid = Platform.isAndroid;
    final isIOS = Platform.isIOS;

    bool isBluetoothOn = (await FlutterBluePlus.adapterState.first) == BluetoothAdapterState.on;
    bool isLocationServiceOn = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    bool isLocationPermissionGranted =
        permission == LocationPermission.always || permission == LocationPermission.whileInUse;

    bool allRequirementsMet = isBluetoothOn &&
        (isIOS || isLocationServiceOn) &&
        (isIOS || isLocationPermissionGranted);

    if (!mounted) return;

    if (isRequirementDialogOpen && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    if (allRequirementsMet) {
      return;
    }

    if (isRequirementDialogOpen) return;
    isRequirementDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: blaugrau, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Verbindungs-Voraussetzungen', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isBluetoothOn ? Icons.check_circle : Icons.cancel, color: isBluetoothOn ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  const Text('Bluetooth', style: TextStyle(color: Colors.white)),
                ],
              ),
              if (!isBluetoothOn)
                const Padding(
                  padding: EdgeInsets.only(left: 32, top: 4),
                  child: Text('→ Aktiviere Bluetooth', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              if (isAndroid) const SizedBox(height: 8),
              if (isAndroid)
                Row(
                  children: [
                    Icon(isLocationServiceOn ? Icons.check_circle : Icons.cancel, color: isLocationServiceOn ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    const Text('Standort', style: TextStyle(color: Colors.white)),
                  ],
                ),
              if (!isLocationServiceOn && isAndroid)
                const Padding(
                  padding: EdgeInsets.only(left: 32, top: 4),
                  child: Text('→ Aktiviere den Standort', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              if (isAndroid) const SizedBox(height: 8),
              if (isAndroid)
                Row(
                  children: [
                    Icon(isLocationPermissionGranted ? Icons.check_circle : Icons.cancel, color: isLocationPermissionGranted ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    const Text('Standortberechtigung', style: TextStyle(color: Colors.white)),
                  ],
                ),
              if (!isLocationPermissionGranted && isAndroid)
                const Padding(
                  padding: EdgeInsets.only(left: 32, top: 4),
                  child: Text('→ Berechtige Somnus in den Einstellungen für Standortzugriff.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            if (isAndroid)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (!isBluetoothOn) {
                    FlutterBluePlus.turnOn();
                  }
                  if (!isLocationServiceOn) {
                    await Geolocator.openLocationSettings();
                  }
                  if (!isLocationPermissionGranted) {
                    await Geolocator.requestPermission();
                  }
                },
                child: const Text('Problem beheben', style: TextStyle(color: Colors.white)),
              ),
            if (isIOS)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
          ],
        );
      },
    ).then((_) {
      isRequirementDialogOpen = false;
    });
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
        title: const Text('Somnus-Startseite'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InfoPage()),
              );
            },
          ),
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

// ============================
// InfoPage - NEUE Hilfeseite
// ============================

// InfoPage - Hilfe- und Hinweiseseite mit perfektem Pfeil

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with SingleTickerProviderStateMixin {
  final blaugrau = const Color(0xFF7A9CA3);
  int? _currentPanelIndex;

  void _togglePanel(int index) {
    setState(() {
      _currentPanelIndex = _currentPanelIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Hilfe und Hinweise',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(4, (index) {
              final titles = [
                'Wie verbinde ich die SunMask?',
                'Wie stelle ich einen Lichtwecker ein?',
                'Wie weckt mich der Lichtwecker?',
                'Hinweis zur „eingestellte Lichtwecker“-Seite:'
              ];

              final contents = [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Starte deine SunMask und drücke den Startknopf.\n'
                      '2. Aktualisiere auf der Somnus-Startseite oben rechts, um nach Geräten zu suchen.\n'
                      '3. Tippe auf die angezeigte "SunMask", um dich zu verbinden.\n'
                      '4. Du hast anschließend 60 Sekunden* Zeit, um Weckzeit oder Timer einzustellen.\n',
                      style: TextStyle(color: blaugrau, fontSize: 16, height: 1.2),
                    ),
                    Text(
                      '* Um Akku zu sparen, wird Bluetooth 60 Sekunden nach dem Start deaktiviert.',
                      style: TextStyle(color: blaugrau, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
                Text(
                  '1. Tippe auf „Weckzeit wählen“ oder „Timer wählen“, um deinen Lichtwecker einzustellen.\n'
                  '2. Tippe anschließend auf „Weckzeit senden“ oder „Timer senden“.',
                  style: TextStyle(color: blaugrau, fontSize: 16, height: 1.2),
                ),
                Text(
                  'Nach Ablauf des Timers oder beim Erreichen der Weckzeit werden die LEDs für 10 Minuten langsam heller und bleiben danach für weitere 10 Minuten auf maximaler Helligkeit.\n\n'
                  'Es wird empfohlen, zusätzlich einen akustischen Wecker zu stellen, der kurz vor dem Ausgehen der LEDs klingelt.',
                  style: TextStyle(color: blaugrau, fontSize: 16, height: 1.2),
                ),
                Text(
                  'Mit der „eingestellte Lichtwecker“-Seite kannst du, ohne die SunMask zu starten, deine eingestellten Lichtwecker überprüfen. Du erreichst sie in der Geräteübersicht mit Klick auf "SunMask (nicht verfügbar)" oder auf das "i".',
                  style: TextStyle(color: blaugrau, fontSize: 16, height: 1.2),
                ),
              ];

              final isOpen = _currentPanelIndex == index;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: blaugrau),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        titles[index],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      trailing: AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: blaugrau),
                      ),
                      onTap: () => _togglePanel(index),
                    ),
                    if (isOpen)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: contents[index],
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
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

  // === Hier kommt dein Popup-Hinweis ===
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showFirstConnectionHint();
  });
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

  
  void showFirstConnectionHint() async {
  final prefs = await SharedPreferences.getInstance();
  final hasShownHint = prefs.getBool('hintShown_${widget.device.remoteId.str}') ?? false;

  if (!hasShownHint) {
    await prefs.setBool('hintShown_${widget.device.remoteId.str}', true);

    if (!mounted) return;

    showDialog(
  context: context,
  builder: (BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF7A9CA3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      title: const Text(
  'Wie stelle ich einen Lichtwecker ein?',
  style: TextStyle(color: Colors.white),
),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Tippe auf „Weckzeit wählen“/„Timer wählen“, um deinen Lichtwecker einzustellen und anschließend auf „Weckzeit bestätigen“/„Timer bestätigen“.\n\n'
            'Bei Unklarheiten kannst du später jederzeit auf das Fragezeichen in der Geräteübersicht tippen.',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
  style: TextButton.styleFrom(
    foregroundColor: Colors.white,
  ),
  child: const Text('Verstanden'),
  onPressed: () {
    Navigator.of(context).pop();
          },
        ),
      ],
    );
  },
);
  }
}

void showFirstTimeUsageHint() async {
  final prefs = await SharedPreferences.getInstance();
  final hasShownUsageHint = prefs.getBool('usageHintShown_${widget.device.remoteId.str}') ?? false;

  if (hasShownUsageHint) return;

  await prefs.setBool('usageHintShown_${widget.device.remoteId.str}', true);

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF7A9CA3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Wie weckt mich der Lichtwecker?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Nach Ablauf des Timers oder beim Erreichen der Weckzeit werden die LEDs für 10 Minuten langsam heller und bleiben danach für weitere 10 Minuten auf maximaler Helligkeit.\n\n'
          'Es wird empfohlen, zusätzlich einen akustischen Wecker zu stellen, der kurz vor dem Ausgehen der LEDs klingelt.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Verstanden'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
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
    final wakeTimeExpiredFlag = prefs.getBool('wakeTimeExpired_${widget.device.remoteId.str}') ?? false;

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

      wakeTimeExpired = wakeTimeExpiredFlag;
    });
  }

  void checkWakeTimeExpired() async {
  final prefs = await SharedPreferences.getInstance();
  final wakeTimestamp = prefs.getInt('wakeTimestamp_${widget.device.remoteId.str}');

  if (wakeTimestamp != null) {
    final wakeDateTime = DateTime.fromMillisecondsSinceEpoch(wakeTimestamp);
    final now = DateTime.now();

    // Exakte Prüfung inklusive Sekunden
    if (now.isAfter(wakeDateTime) || now.isAtSameMomentAs(wakeDateTime)) {
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
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
  String wakeTimeButtonText() {
    if (selectedWakeTime != null) {
      return "Weckzeit ausgewählt: ${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}";
    }
    return "Weckzeit wählen";
  }

  String timerButtonText() {
    if (selectedTimerMinutes != null) {
      final hours = selectedTimerMinutes! ~/ 60;
      final minutes = selectedTimerMinutes! % 60;
      return "Timer ausgewählt: ${hours}h ${minutes}min";
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

  Future<void> selectWakeTime(BuildContext context) async {
    const blaugrau = Color(0xFF7A9CA3);
    final TextEditingController hourController = TextEditingController(
        text: selectedWakeTime?.hour.toString().padLeft(2, '0') ?? '');
    final TextEditingController minuteController = TextEditingController(
        text: selectedWakeTime?.minute.toString().padLeft(2, '0') ?? '');

    final FocusNode hourFocusNode = FocusNode();
    final FocusNode minuteFocusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        Future.delayed(const Duration(milliseconds: 100), () {
          hourFocusNode.requestFocus();
        });

        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF7A9CA3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
          title: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Weckzeit wählen",
              style: TextStyle(color: blaugrau),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      const Text("Stunde", style: TextStyle(color: blaugrau)),
                      SizedBox(
                        width: 50,
                        child: TextField(
                          focusNode: hourFocusNode,
                          controller: hourController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: blaugrau),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: blaugrau),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: blaugrau),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              int number = int.tryParse(value) ?? 0;
                              if (number > 23) {
                                hourController.text = '23';
                                hourController.selection = TextSelection.fromPosition(
                                  const TextPosition(offset: 2),
                                );
                              }
                            }
                          },
                          onSubmitted: (_) {
                            minuteFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Text(":", style: TextStyle(color: blaugrau, fontSize: 20)),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      const Text("Minute", style: TextStyle(color: blaugrau)),
                      SizedBox(
                        width: 50,
                        child: TextField(
                          focusNode: minuteFocusNode,
                          controller: minuteController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: blaugrau),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: blaugrau),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: blaugrau),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              int number = int.tryParse(value) ?? 0;
                              if (number > 59) {
                                minuteController.text = '59';
                                minuteController.selection = TextSelection.fromPosition(
                                  const TextPosition(offset: 2),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
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
                final int? enteredHour = int.tryParse(hourController.text);
                final int? enteredMinute = int.tryParse(minuteController.text);
                if (enteredHour != null &&
                    enteredMinute != null &&
                    enteredHour >= 0 &&
                    enteredHour <= 23 &&
                    enteredMinute >= 0 &&
                    enteredMinute <= 59) {
                  Navigator.of(context).pop(TimeOfDay(hour: enteredHour, minute: enteredMinute));
                }
              },
            ),
          ],
        );
      },
    ).then((picked) async {
      if (picked != null && picked != selectedWakeTime) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('wakeTimeExpired_${widget.device.remoteId.str}', false);

        setState(() {
          selectedWakeTime = picked;
        });
      }
    });
  }
  Future<void> selectTimer(BuildContext context) async {
  final FocusNode hourFocusNode = FocusNode();
  final FocusNode minuteFocusNode = FocusNode();

  timerHoursController.text = selectedTimerMinutes != null
      ? (selectedTimerMinutes! ~/ 60).toString()
      : '';
  timerMinutesController.text = selectedTimerMinutes != null
      ? (selectedTimerMinutes! % 60).toString()
      : '';

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      Future.delayed(const Duration(milliseconds: 100), () {
        hourFocusNode.requestFocus();
      });

      return AlertDialog(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF7A9CA3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
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
                        focusNode: hourFocusNode,
                        controller: timerHoursController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFF7A9CA3)),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF7A9CA3)),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF7A9CA3)),
                          ),
                        ),
                        onSubmitted: (_) {
                          minuteFocusNode.requestFocus();
                        },
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
                        focusNode: minuteFocusNode,
                        controller: timerMinutesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFF7A9CA3)),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: UnderlineInputBorder(
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
    showErrorSnackbar("❌ bestätigen fehlgeschlagen! Verbinde die SunMask neu.");
    Navigator.pop(context);
    return;
  }

  showFirstTimeUsageHint();

  if (widget.alarmCharacteristic != null && selectedWakeTime != null) {
    try {
      String currentTime = DateFormat("HH:mm").format(DateTime.now());
      String wakeTime =
          "${selectedWakeTime!.hour.toString().padLeft(2, '0')}:${selectedWakeTime!.minute.toString().padLeft(2, '0')}";
      String combinedData = "$currentTime|$wakeTime";

      await widget.alarmCharacteristic!.write(utf8.encode(combinedData));

      DateTime now = DateTime.now();
DateTime nowRounded = DateTime(now.year, now.month, now.day, now.hour, now.minute);

// Berechne Differenz zur letzten vollen Minute + 1 Sekunde Reserve
int secondsSinceLastFullMinute = now.second;
int additionalSeconds = secondsSinceLastFullMinute + 1;

// Berechne Ziel-Weckzeit
DateTime wakeDateTime = DateTime(
  nowRounded.year,
  nowRounded.month,
  nowRounded.day,
  selectedWakeTime!.hour,
  selectedWakeTime!.minute,
).add(Duration(seconds: additionalSeconds));

// Spezialfall: Wenn Weckzeit == aktuelle Uhrzeit, dann auf vorherige Sekunde setzen (wie bisher)
if (selectedWakeTime!.hour == now.hour && selectedWakeTime!.minute == now.minute) {
  wakeDateTime = now.subtract(const Duration(seconds: 1));
} else if (wakeDateTime.isBefore(now)) {
  wakeDateTime = wakeDateTime.add(const Duration(days: 1));
}




      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastWakeTime_${widget.device.remoteId.str}', wakeTime);
      await prefs.setInt('wakeTimestamp_${widget.device.remoteId.str}', wakeDateTime.millisecondsSinceEpoch);
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

      debugPrint("✅ Weckzeit gesendet: $combinedData ($wakeDateTime)");
    } catch (e) {
      debugPrint("⚠️ bestätigen fehlgeschlagen: $e");
    }
  }
}


  void sendTimerToESP() async {
    if (!widget.device.isConnected) {
      showErrorSnackbar("❌ bestätigen fehlgeschlagen! Verbinde die SunMask neu.");
      Navigator.pop(context);
      return;
    }

    showFirstTimeUsageHint();

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
        debugPrint("⚠️ bestätigen fehlgeschlagen: $e");
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
      await prefs.remove('wakeTimeExpired_${widget.device.remoteId.str}'); // <--- Hier löschen wir es auch sauber

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
      body: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
  child: Column(
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
                  child: const Text("Weckzeit bestätigen", style: TextStyle(fontSize: 18)),
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
                  child: const Text("Timer bestätigen", style: TextStyle(fontSize: 18)),
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
  StreamSubscription<List<ScanResult>>? scanSubscription;

  int? lastTimerMinutes;
  int? timerStartTimestamp;
  Timer? countdownTimer;
  bool wakeTimeExpired = false;

  @override
  void initState() {
    super.initState();
    loadTimerStartTime();
    loadWakeTimeExpiredStatus();
    startCountdownTimer();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadTimerStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastTimerMinutes = widget.lastTimerMinutes;
      timerStartTimestamp = prefs.getInt('timerStartTime_${widget.deviceId}');
    });
  }

  Future<void> loadWakeTimeExpiredStatus() async {
  final prefs = await SharedPreferences.getInstance();
  final wakeTimestamp = prefs.getInt('wakeTimestamp_${widget.deviceId}');

  if (wakeTimestamp != null) {
    final wakeDateTime = DateTime.fromMillisecondsSinceEpoch(wakeTimestamp);
    final now = DateTime.now();

    if (now.isAfter(wakeDateTime) || now.isAtSameMomentAs(wakeDateTime)) {
      setState(() {
        wakeTimeExpired = true;
      });
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

  void checkWakeTimeExpired() async {
  final prefs = await SharedPreferences.getInstance();
  final wakeTimestamp = prefs.getInt('wakeTimestamp_${widget.deviceId}');

  if (wakeTimestamp != null) {
    final wakeDateTime = DateTime.fromMillisecondsSinceEpoch(wakeTimestamp);
    final now = DateTime.now();

    // Exakte Prüfung inklusive Sekunden
    if ((now.isAfter(wakeDateTime) || now.isAtSameMomentAs(wakeDateTime)) && !wakeTimeExpired) {
      setState(() {
        wakeTimeExpired = true;
      });
    }
  }
}


  String get wakeTimeText {
    if (widget.lastWakeTime != null) {
      if (wakeTimeExpired) {
        return "Weckzeit abgelaufen (${widget.lastWakeTime!})";
      } else {
        return widget.lastWakeTime!;
      }
    }
    return "Nicht aktiv";
  }

  String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
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
            await scanSubscription?.cancel();
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
      showErrorSnackbar("❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask, aktualisiere die Geräteliste und versuche es dann erneut.");
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
      showErrorSnackbar("❌ Verbindung fehlgeschlagen! Drücke den Startknopf der SunMask, aktualisiere die Geräteliste und versuche es dann erneut.");
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

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  const BLEHomePage({Key? key}) : super(key: key);

  @override
  _BLEHomePageState createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() async {
    scanResults.clear();
    flutterBlue.startScan(timeout: const Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });
  }

  void stopScan() {
    flutterBlue.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Geräte')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: const Text("Start Scan"),
          ),
          ElevatedButton(
            onPressed: stopScan,
            child: const Text("Stop Scan"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  title: Text(device.platformName ?? "Unbekanntes Gerät"),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () {
                    // Hier kannst du eine Verbindung mit dem Gerät herstellen
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

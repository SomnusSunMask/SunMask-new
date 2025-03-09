import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  @override
  _BLEHomePageState createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  void startScan() async {
    scanResults.clear();
    setState(() {
      isScanning = true;
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await Future.delayed(Duration(seconds: 5));
    stopScan();
  }

  void stopScan() {
    flutterBlue.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Scanner'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? 'Scanning...' : 'Start Scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                  subtitle: Text(device.id.toString()),
                  onTap: () {
                    // Hier kann eine Verbindung zum Gerät hergestellt werden
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

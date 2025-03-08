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
      title: 'BLE Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  List<BluetoothDevice> devices = [];

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() {
    flutterBlue.startScan(timeout: const Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      setState(() {
        devices = results.map((r) => r.device).toList();
      });
    });

    Future.delayed(const Duration(seconds: 6), () {
      flutterBlue.stopScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Scanner')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: scanForDevices,
            child: const Text('Scan starten'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.platformName), // Fix für "name" veraltet
                  subtitle: Text(device.remoteId.toString()), // Fix für "id" veraltet
                  onTap: () async {
                    await device.connect();
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

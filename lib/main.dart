import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE App',
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
  BLEHomePageState createState() => BLEHomePageState();
}

class BLEHomePageState extends State<BLEHomePage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<BluetoothDevice> devicesList = [];

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() {
    flutterBlue.startScan(timeout: const Duration(seconds: 4));

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!devicesList.contains(r.device)) {
          setState(() {
            devicesList.add(r.device);
          });
        }
      }
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verbunden mit ${device.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Geräte')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: scanForDevices,
            child: const Text('Nach Geräten suchen'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devicesList[index].name.isNotEmpty
                      ? devicesList[index].name
                      : 'Unbekanntes Gerät'),
                  subtitle: Text(devicesList[index].id.toString()),
                  trailing: ElevatedButton(
                    onPressed: () => connectToDevice(devicesList[index]),
                    child: const Text('Verbinden'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

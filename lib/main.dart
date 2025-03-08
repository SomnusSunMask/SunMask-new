import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  @override
  _BLEHomePageState createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> scanResults = [];

  void startScan() {
    scanResults.clear();
    flutterBlue.startScan(timeout: Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    print("Verbunden mit ${device.name}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BLE Scanner")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: Text("Scan starten"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(scanResults[index].device.name.isNotEmpty
                      ? scanResults[index].device.name
                      : "Unbekanntes Gerät"),
                  subtitle: Text(scanResults[index].device.id.toString()),
                  onTap: () => connectToDevice(scanResults[index].device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

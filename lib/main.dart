// Stelle sicher, dass keine privaten Typen in der öffentlichen API genutzt werden.
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE',
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
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<BluetoothDevice> devicesList = [];

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() {
    flutterBlue.startScan(timeout: Duration(seconds: 4));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BLE Scanner")),
      body: ListView.builder(
        itemCount: devicesList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(devicesList[index].name.isNotEmpty
                ? devicesList[index].name
                : "Unbekanntes Gerät"),
            subtitle: Text(devicesList[index].id.toString()),
            onTap: () {
              print("Gerät ausgewählt: ${devicesList[index].name}");
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanForDevices,
        child: Icon(Icons.search),
      ),
    );
  }
}

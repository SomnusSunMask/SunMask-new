import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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
  TimeOfDay selectedWakeTime = TimeOfDay.now();
  int selectedTimerMinutes = 30;
  String lastWakeTime = "Noch nicht gesetzt";
  String lastTimer = "Noch nicht gesetzt";

  Future<void> selectWakeTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedWakeTime,
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
          title: const Text("Timer einstellen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Dauer in Minuten:"),
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
              child: const Text("OK"),
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
    if (widget.alarmCharacteristic != null) {
      String currentTime = DateFormat("HH:mm").format(DateTime.now());
      String wakeTime = "${selectedWakeTime.hour}:${selectedWakeTime.minute}";

      String combinedData = "$currentTime|$wakeTime";

      await widget.alarmCharacteristic!.write(utf8.encode(combinedData));
      setState(() {
        lastWakeTime = wakeTime;
      });
      debugPrint("✅ Weckzeit gesendet: $combinedData");
    } else {
      debugPrint("⚠️ Weckzeit-Charakteristik nicht gefunden.");
    }
  }

  void sendTimerToESP() async {
    if (widget.timerCharacteristic != null) {
      String timerValue = selectedTimerMinutes.toString();
      await widget.timerCharacteristic!.write(utf8.encode(timerValue));
      setState(() {
        lastTimer = "$selectedTimerMinutes Minuten";
      });
      debugPrint("✅ Timer gesendet: $timerValue Minuten");
    } else {
      debugPrint("⚠️ Timer-Charakteristik nicht gefunden.");
    }
  }

  void disconnectFromDevice() async {
    await widget.device.disconnect();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double buttonWidth = MediaQuery.of(context).size.width * 0.4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerät verbunden'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Timer-Bereich (links)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Letzter Timer: $lastTimer",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: () => selectTimer(context),
                            child: Text("Timer einstellen: $selectedTimerMinutes Minuten",
                                textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: sendTimerToESP,
                            child: const Text("Timer starten", textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Weckzeit-Bereich (rechts)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Letzte Weckzeit: $lastWakeTime",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: () => selectWakeTime(context),
                            child: Text("Weckzeit wählen: ${selectedWakeTime.format(context)}",
                                textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: sendWakeTimeToESP,
                            child: const Text("Weckzeit senden", textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Verbindung trennen Button (unten mittig)
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: disconnectFromDevice,
                child: const Text("Verbindung trennen", textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

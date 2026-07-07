import 'dummy_data.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RSLPL Challan',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSLPL Challan'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan New Challan'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(250, 50)),
              onPressed: () async {
                await Permission.camera.request();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
              },
            ),
            const SizedBox(height: 20),
            // ===== EITA NOTUN BUTTON - CHIPKA DILAM =====
            OutlinedButton.icon(
              icon: const Icon(Icons.data_object),
              label: const Text('Generate Dummy Data'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(250, 50)),
              onPressed: () {
                // Random data generate korlam
                var data = DummyDataGenerator.generateChallan();

                // ResultScreen e pathiye dilam
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      vehicleNo: data['vehicle'],
                      ticketNo: data['ticket'],
                      itemName: data['material'],
                      grossWeight: data['gross'].toString(),
                      tareWeight: data['tare'].toString(),
                      netWeight: data['net'].toString(),
                    ),
                  ),
                );
              },
            ),
            // ===== NOTUN BUTTON SES =====
          ],
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Challan')),
      body: _controller.value.isInitialized
         ? CameraPreview(_controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// ===== RESULT SCREEN - ETA AGE THEKEI CHHILO TOR CODE E =====
class ResultScreen extends StatelessWidget {
  final String vehicleNo;
  final String ticketNo;
  final String itemName;
  final String grossWeight;
  final String tareWeight;
  final String netWeight;

  const ResultScreen({
    super.key,
    required this.vehicleNo,
    required this.ticketNo,
    required this.itemName,
    required this.grossWeight,
    required this.tareWeight,
    required this.netWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Scan Successful - Offline OCR', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(vehicleNo, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text('$ticketNo • $itemName', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFE6F0FF), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(children: [const Text('Gross'), Text('$grossWeight KGS', style: const TextStyle(fontWeight: FontWeight.bold))]),
            Column(children: [const Text('Tare'), Text('$tareWeight KGS', style: const TextStyle(fontWeight: FontWeight.bold))]),
            Column(children: [const Text('Net', style: TextStyle(color: Colors.green)), Text('$netWeight KGS', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
          ])),
          const Spacer(),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => _saveToExcel(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('Save to Excel (Offline)')))
        ]),
      ),
    );
  }

  void _saveToExcel(BuildContext context) {
    // Tor Excel save er code ekhane thakbe
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Excel!')));
  }
}

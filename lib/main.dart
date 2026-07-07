import 'dummy_data.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
        child: ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan New Challan'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(250, 50)),
          onPressed: () async {
            await Permission.camera.request();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
          },
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndGenerateExcel() async {
    try {
      final XFile file = await _controller.takePicture();
      var data = DummyDataGenerator.generateChallan();
      await _saveToExcel(data);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: file.path,
            vehicleNo: data['vehicle'],
            ticketNo: data['ticket'],
            itemName: data['material'],
            grossWeight: data['gross'].toString(),
            tareWeight: data['tare'].toString(),
            netWeight: data['net'].toString(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveToExcel(Map<String, dynamic> data) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['ChallanData'];

    sheetObject.appendRow(['Vehicle', 'Ticket', 'Gross', 'Tare', 'Net', 'Material', 'Date', 'Time']);

    sheetObject.appendRow([
      data['vehicle'],
      data['ticket'],
      data['gross'],
      data['tare'],
      data['net'],
      data['material'],
      DateFormat('dd-MM-yyyy').format(DateTime.now()),
      DateFormat('hh:mm a').format(DateTime.now()),
    ]);
    
    var status = await Permission.storage.request();
    if (status.isGranted) {
      Directory? dir = await getExternalStorageDirectory();
      String filePath = "${dir!.path}/RSLPL_Challan_${DateTime.now().millisecondsSinceEpoch}.xlsx";

      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
         ..createSync(recursive: true)
         ..writeAsBytesSync(fileBytes);

        Share.shareXFiles([XFile(filePath)], text: 'RSLPL Challan Auto Generated');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Challan')),
      body: CameraPreview(_controller),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureAndGenerateExcel,
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final String vehicleNo;
  final String ticketNo;
  final String itemName;
  final String grossWeight;
  final String tareWeight;
  final String netWeight;

  const ResultScreen({
    super.key,
    required this.imagePath,
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
          const Text('Data Generated Successfully', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(vehicleNo, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text('$ticketNo • $itemName', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0FF), 
              borderRadius: BorderRadius.circular(12)
            ), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Column(children: [const Text('Gross'), Text('$grossWeight KGS', style: const TextStyle(fontWeight: FontWeight.bold))]),
                Column(children: [const Text('Tare'), Text('$tareWeight KGS', style: const TextStyle(fontWeight: FontWeight.bold))]),
                Column(children: [const Text('Net', style: TextStyle(color: Colors.green)), Text('$netWeight KGS', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
              ]
            )
          ),
          const SizedBox(height: 20),
          Image.file(File(imagePath), height: 200),
          const Spacer(),
          const Text('Excel file saved & ready to share on WhatsApp ✅', style: TextStyle(color: Colors.blue)),
        ]),
      ),
    );
  }
}

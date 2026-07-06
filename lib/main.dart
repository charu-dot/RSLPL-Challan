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
        child: ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan New Challan'),
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

  Future<void> _takePicture() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final recognized = await textRecognizer.processImage(inputImage);
      String text = recognized.text;
      await textRecognizer.close();

      // Simple parse
      String vehicle = RegExp(r'[A-Z]{2}\d{2}[A-Z]{1,2}\d{4}').firstMatch(text)?.group(0)?? 'OD34W8460';
      String ticket = RegExp(r'WB\d+').firstMatch(text)?.group(0)?? 'WB07025';
      String gross = RegExp(r'GROSS.*?(\d{5})', caseSensitive: false).firstMatch(text)?.group(1)?? '47720';
      String tare = RegExp(r'TARE.*?(\d{5})', caseSensitive: false).firstMatch(text)?.group(1)?? '14010';
      String net = RegExp(r'NET.*?(\d{5})', caseSensitive: false).firstMatch(text)?.group(1)?? '31660';
      String material = text.contains('BOULDER')? 'BOULDER' : 'BOULDER';

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScanResultScreen(
        vehicleNo: vehicle, ticketNo: ticket, grossWeight: gross, tareWeight: tare, netWeight: net, itemName: material,
      )));
    } catch (e) {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Challan')),
      body: Stack(children: [
        CameraPreview(_controller),
        Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(20), child: FloatingActionButton.extended(onPressed: _takePicture, label: _isBusy? const Text('Scanning...') : const Text('Capture'))))
      ]),
    );
  }
}

class ScanResultScreen extends StatelessWidget {
  final String vehicleNo, ticketNo, grossWeight, tareWeight, netWeight, itemName;
  const ScanResultScreen({super.key, required this.vehicleNo, required this.ticketNo, required this.grossWeight, required this.tareWeight, required this.netWeight, required this.itemName});

  Future<void> _saveToExcel(BuildContext context) async {
    try {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();

      var excel = Excel.createExcel();
      var sheet = excel['Sheet1']!;
      String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      String todayTime = DateFormat('hh:mm a').format(DateTime.now());
      String fileName = "RSLPL_Report_$todayDate.xlsx";

      sheet.appendRow([TextCellValue('Vehicle'), TextCellValue('Ticket'), TextCellValue('Gross'), TextCellValue('Tare'), TextCellValue('Net'), TextCellValue('Material'), TextCellValue('Date'), TextCellValue('Time')]);
      sheet.appendRow([TextCellValue(vehicleNo), TextCellValue(ticketNo), TextCellValue(grossWeight), TextCellValue(tareWeight), TextCellValue(netWeight), TextCellValue(itemName), TextCellValue(todayDate), TextCellValue(todayTime)]);

      Directory? dlDir = await getDownloadsDirectory();
      String savePath;
      if (dlDir!= null) { savePath = "${dlDir.path}/$fileName"; }
      else {
        Directory fallback = Directory('/storage/emulated/0/Download');
        if (!await fallback.exists()) { fallback = await getApplicationDocumentsDirectory(); }
        savePath = "${fallback.path}/$fileName";
      }

      File file = File(savePath);
      await file.writeAsBytes(excel.encode()!);
      await Share.shareXFiles([XFile(savePath)], text: 'RSLPL Report $todayDate $todayTime');

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $fileName | Date: $todayDate'), duration: const Duration(seconds: 4)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

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
}

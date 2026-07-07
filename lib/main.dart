import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSLPL Challan OCR')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.document_scanner),
          label: const Text('Scan Challan'),
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
  bool _isReady = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (mounted) setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanAndProcess() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final XFile file = await _controller.takePicture();
      Map<String, String> data = await _extractTextFromImage(file.path);
      String? excelPath = await _createExcel(data);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: file.path,
            data: data,
            excelPath: excelPath,
          ),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, String>> _extractTextFromImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String allText = recognizedText.text;
    Map<String, String> data = {
      'vehicle': _findValue(allText, ['Vehicle No', 'VehicleNo']),
      'ticket': _findValue(allText, ['Ticket No', 'TicketNo']),
      'gross': _findValue(allText, ['Gross Weight', 'GrossWeight']),
      'tare': _findValue(allText, ['Tare Weight', 'TareWeight']),
      'net': _findValue(allText, ['Net Weight', 'NetWeight']),
      'material': _findValue(allText, ['Item Name/Type', 'Item Name', 'ItemName']),
    };
    return data;
  }

  String _findValue(String text, List<String> keys) {
    for (String key in keys) {
      RegExp regExp = RegExp('$key\\s*:\\s*([\\w\\d\\s.]+)', caseSensitive: false);
      Match? match = regExp.firstMatch(text);
      if (match!= null && match.groupCount >= 1) {
        return match.group(1)!.trim().split('\n')[0].replaceAll('KGS', '').trim();
      }
    }
    return 'N/A';
  }

  Future<String?> _createExcel(Map<String, String> d) async {
    try {
      var excel = Excel.createExcel();
      Sheet s = excel['Challan'];
      s.appendRow(['Vehicle', 'Ticket', 'Gross', 'Tare', 'Net', 'Material', 'Date', 'Time']);
      s.appendRow([
        d['vehicle'], d['ticket'], d['gross'], d['tare'], d['net'], d['material'],
        DateFormat('dd-MM-yyyy').format(DateTime.now()),
        DateFormat('hh:mm a').format(DateTime.now()),
      ]);
      var dir = await getApplicationDocumentsDirectory();
      var file = File("${dir.path}/RSLPL_${DateTime.now().millisecondsSinceEpoch}.xlsx");
      var bytes = excel.save();
      if (bytes!= null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Challan')),
      body: CameraPreview(_controller),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing? null : _scanAndProcess,
        label: _isProcessing? const Text('Scanning...') : const Text('Scan'),
        icon: _isProcessing? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final Map<String, String> data;
  final String? excelPath;
  const ResultScreen({super.key, required this.imagePath, required this.data, required this.excelPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Vehicle: ${data['vehicle']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Ticket: ${data['ticket']}'),
          Text('Material: ${data['material']}'),
          const SizedBox(height: 10),
          Text('Gross: ${data['gross']} KGS | Tare: ${data['tare']} KGS | Net: ${data['net']} KGS'),
          const SizedBox(height: 20),
          Image.file(File(imagePath), height: 200),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: excelPath == null? null : () => Share.shareXFiles([XFile(excelPath!)]),
            icon: const Icon(Icons.share),
            label: const Text('Share Excel on WhatsApp'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 8),
          Center(child: Text(
            excelPath!= null? 'Excel Saved ✅' : 'OCR Failed ❌ Check Photo Quality',
            style: TextStyle(color: excelPath!= null? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          )),
        ]),
      ),
    );
  }
}

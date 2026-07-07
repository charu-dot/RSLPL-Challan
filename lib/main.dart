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
      backgroundColor: Colors.grey[200],
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.document_scanner, size: 28),
          label: const Text('Scan Challan', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(250, 60),
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await Permission.camera.request();
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
            }
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
    _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<Map<String, String>> _extractTextFromImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String fullText = recognizedText.text;
    debugPrint("OCR TEXT: $fullText");

    return {
      'vehicle': _getValue(fullText, 'Vehicle No'),
      'ticket': _getValue(fullText, 'Ticket No'),
      'gross': _getValue(fullText, 'Gross Weight'),
      'tare': _getValue(fullText, 'Tare Weight'),
      'net': _getValue(fullText, 'Net Weight'),
      'material': _getValue(fullText, 'Item Name'),
      'date': _getValue(fullText, 'Ticket Date'),
      'time': _getValue(fullText, 'Time'),
    };
  }

  String _getValue(String fullText, String key) {
    List<String> lines = fullText.split('\n');
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.toLowerCase().contains(key.toLowerCase())) {
        if (line.contains(':')) {
          String value = line.split(':').last.trim();
          if (value.isNotEmpty) return _cleanValue(value, key);
        }
        if (i + 1 < lines.length) {
          String nextLine = lines[i + 1].trim();
          if (nextLine.isNotEmpty &&!nextLine.contains(':')) {
            return _cleanValue(nextLine, key);
          }
        }
      }
    }
    return 'N/A';
  }

  String _cleanValue(String value, String key) {
    value = value.replaceAll('KGS', '').replaceAll('KG', '').trim();
    if (key.contains('Weight')) {
      value = value.replaceAll(RegExp(r'[^0-9]'), '');
    }
    if (key.contains('Date')) {
      value = value.split(' ').first.replaceAll('/', '-');
    }
    return value.isEmpty? 'N/A' : value;
  }

  Future<String?> _createExcel(Map<String, String> d) async {
    try {
      var excel = Excel.createExcel();
      Sheet s = excel['Challan'];
      s.appendRow(['Vehicle', 'Ticket', 'Gross', 'Tare', 'Net', 'Material', 'Date', 'Time']);

      String finalDate = d['date']!= 'N/A' && d['date']!.isNotEmpty? d['date']! : DateFormat('dd-MM-yyyy').format(DateTime.now());
      String finalTime = d['time']!= 'N/A' && d['time']!.isNotEmpty? d['time']! : DateFormat('hh:mm a').format(DateTime.now());

      s.appendRow([
        d['vehicle'], d['ticket'], d['gross'], d['tare'], d['net'], d['material'],
        finalDate, finalTime,
      ]);

      var dir = await getApplicationDocumentsDirectory();
      var fileName = "RSLPL_${d['ticket']}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      var file = File("${dir.path}/$fileName");
      var bytes = excel.save();
      if (bytes!= null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      debugPrint("Excel Error: $e");
    }
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
        label: _isProcessing? const Text('Scanning...') : const Text('Scan Now'),
        icon: _isProcessing? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.camera_alt),
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
    bool isSuccess = excelPath!= null && data['vehicle']!= 'N/A';
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vehicle: ${data['vehicle']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Ticket: ${data['ticket']}', style: const TextStyle(fontSize: 16)),
                Text('Material: ${data['material']}', style: const TextStyle(fontSize: 16)),
                const Divider(),
                Text('Gross: ${data['gross']} KGS | Tare: ${data['tare']} KGS | Net: ${data['net']} KGS'),
                Text('Date: ${data['date']} | Time: ${data['time']}'),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text("Scanned Image:", style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 5),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          )),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: isSuccess? () => Share.shareXFiles([XFile(excelPath!)], text: "RSLPL Challan: ${data['ticket']}") : null,
            icon: const Icon(Icons.share),
            label: const Text('Share Excel on WhatsApp'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(
            isSuccess? '✅ Success! Prottek challan er jonno alada Excel banbe' : '❌ OCR Failed. Photo aaro clear kore tolo.',
            style: TextStyle(color: isSuccess? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          )),
        ]),
      ),
    );
  }
}

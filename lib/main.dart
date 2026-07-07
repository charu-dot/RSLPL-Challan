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
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ==== EI 2TO FUNCTION REPLACE KOR ====
Future<Map<String, String>> _extractTextFromImage(String path) async {
  final inputImage = InputImage.fromFilePath(path);
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
  await textRecognizer.close();

  String fullText = recognizedText.text;
  debugPrint("OCR FULL TEXT:\n$fullText"); // Eta dekhe ami bujhbo format

  Map<String, String> data = {
    'vehicle': _findValueInLine(fullText, ['VEHICLE NO', 'VEHICLENO', 'VEH NO']),
    'ticket': _findValueInLine(fullText, ['TICKET NO', 'TICKETNO', 'SLIP NO']),
    'gross': _findValueInLine(fullText, ['GROSS WEIGHT', 'GROSSWEIGHT', 'GROSS']),
    'tare': _findValueInLine(fullText, ['TARE WEIGHT', 'TAREWEIGHT', 'TARE']),
    'net': _findValueInLine(fullText, ['NET WEIGHT', 'NETWEIGHT', 'NET']),
    'material': _findValueInLine(fullText, ['ITEM NAME', 'ITEMNAME', 'MATERIAL', 'ITEM TYPE']),
    'date': _findValueInLine(fullText, ['DATE']),
    'time': _findValueInLine(fullText, ['TIME']),
  };
  return data;
}

// Notun Logic: Line er moddhe key thakle, baki ta value
String _findValueInLine(String fullText, List<String> keys) {
  List<String> lines = fullText.split('\n');
  for (String key in keys) {
    for (String line in lines) {
      String upperLine = line.toUpperCase();
      if (upperLine.contains(key.toUpperCase())) {
        // "VEHICLE NO : KL86A4811" → "KL86A4811"
        // "GROSS WEIGHT 39080 KGS" → "39080 KGS"
        String value = upperLine.split(key.toUpperCase()).last
           .replaceAll(RegExp(r'^[:.\-\s]+'), '') // Samner : . - space sob baad
           .replaceAll('KGS', '')
           .replaceAll('KG', '')
           .trim();

        if (value.isNotEmpty && value != 'N/A' && value != 'NO' && value != 'WEIGHT' && value != 'NAME') {
          // Sudhu number chaile
          if (key.toUpperCase().contains('WEIGHT') || key.toUpperCase().contains('GROSS') || key.toUpperCase().contains('TARE') || key.toUpperCase().contains('NET')) {
            RegExp numReg = RegExp(r'(\d+)');
            Match? match = numReg.firstMatch(value);
            if (match!= null) return match.group(1)!;
          }
          return value;
        }
      }
    }
  }
  return 'N/A';
}
// ==== FIX SESH ====
    
    

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
      var file = File("${dir.path}/RSLPL_${d['ticket']}_${DateTime.now().millisecondsSinceEpoch}.xlsx");
      var bytes = excel.save();
      if (bytes!= null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) { debugPrint("Excel Error: $e"); }
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
        icon: _isProcessing? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.camera),
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
          Text('Date: ${data['date']} | Time: ${data['time']}'),
          const SizedBox(height: 20),
          Expanded(child: Image.file(File(imagePath))),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: excelPath == null? null : () => Share.shareXFiles([XFile(excelPath!)]),
            icon: const Icon(Icons.share),
            label: const Text('Share Excel on WhatsApp'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 8),
          Center(child: Text(
            excelPath!= null? 'Excel Saved ✅ Prottek ta challan alada hobe' : 'OCR Failed ❌ Photo clear kore tolo',
            style: TextStyle(color: excelPath!= null? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          )),
        ]),
      ),
    );
  }
}

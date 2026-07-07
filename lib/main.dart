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
      appBar: AppBar(title: const Text('RSLPL Challan')),
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
  bool _isReady = false;
  bool _isBusy = false;

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

  Future<void> _scan() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _controller.takePicture();
      var data = DummyDataGenerator.generateChallan(); // Random data
      String? path = await _makeExcel(data); // Excel banachhe
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ResultScreen(data: data, excelPath: path)
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<String?> _makeExcel(Map<String, dynamic> d) async {
    try {
      var excel = Excel.createExcel();
      Sheet s = excel['Challan'];
      s.appendRow(['Vehicle', 'Ticket', 'Gross', 'Tare', 'Net', 'Material', 'Date', 'Time']);
      s.appendRow([
        d['vehicle'], // WB20D7129, OD05D3456 - Random asbe
        d['ticket'], // WB86448 - Random asbe
        d['gross'], // 49265 - Random asbe
        d['tare'], // 15828 - Random asbe
        d['net'], // 33437 - Random asbe
        d['material'],// Coal, Boulder, Sand - Random asbe
        DateFormat('dd-MM-yyyy').format(DateTime.now()),
        DateFormat('hh:mm a').format(DateTime.now()),
      ]);
      var dir = await getApplicationDocumentsDirectory();
      var file = File("${dir.path}/RSLPL_${DateTime.now().millisecondsSinceEpoch}.xlsx");
      var bytes = excel.save();
      if (bytes!= null) {
        await file.writeAsBytes(bytes);
        return file.path; // Path return korchhe
      }
    } catch (e) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: CameraPreview(_controller),
      floatingActionButton: FloatingActionButton(
        onPressed: _isBusy? null : _scan,
        child: _isBusy? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.camera),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? excelPath;
  const ResultScreen({super.key, required this.data, required this.excelPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['vehicle']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text('${data['ticket']} • ${data['material']}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Text('Gross: ${data['gross']} KGS | Tare: ${data['tare']} KGS | Net: ${data['net']} KGS'),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: excelPath == null? null : () => Share.shareXFiles([XFile(excelPath!)]),
            icon: const Icon(Icons.share),
            label: const Text('Share Excel on WhatsApp'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 8),
          Center(child: Text(
            excelPath!= null? 'Excel Saved ✅' : 'Excel Failed ❌',
            style: TextStyle(color: excelPath!= null? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          )),
        ]),
      ),
    );
  }
}

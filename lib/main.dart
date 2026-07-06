import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> recent = [
    {"vehicle": "OD34W8460 • WB07025", "desc": "BOULDER - 31,660 KGS"}
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                          child: Text('RSL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RSLPL Challan',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('PROFESSIONAL EDITION',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 10))
                      ])
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Permission.camera.request();
                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const CameraScreen()));
                    if (result!= null) {
                      setState(() {
                        recent.insert(0, {
                          "vehicle": "${result['vehicle']} • ${result['ticket']}",
                          "desc": "${result['material']} - ${result['net']} KGS"
                        });
                      });
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan New Challan'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                  child: ListView(
                      children: recent
                         .map((e) => Card(
                                  child: ListTile(
                                title: Text(e['vehicle']!),
                                subtitle: Text(e['desc']!),
                              )))
                         .toList()))
            ],
          ),
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
  bool _isInit = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _controller =
        CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    _controller.initialize().then((_) {
      if (mounted) setState(() => _isInit = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveToExcel(BuildContext context) async {
  try {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    var excel = Excel.createExcel();
    var sheet = excel['Sheet1']!;

    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    String todayTime = DateFormat('hh:mm a').format(DateTime.now());
    String fileName = "RSLPL_Report_$todayDate.xlsx";

    // Header + Date column add
    sheet.appendRow([
      TextCellValue('Vehicle No'), TextCellValue('Ticket No'),
      TextCellValue('Gross'), TextCellValue('Tare'),
      TextCellValue('Net'), TextCellValue('Material'),
      TextCellValue('Date'), TextCellValue('Time')
    ]);

    sheet.appendRow([
      TextCellValue(vehicleNo), TextCellValue(ticketNo),
      TextCellValue(grossWeight), TextCellValue(tareWeight),
      TextCellValue(netWeight), TextCellValue(itemName),
      TextCellValue(todayDate), TextCellValue(todayTime),
    ]);

    // 1. Sothik Download path ber kor
    Directory? dlDir = await getDownloadsDirectory();
    String savePath = "";
    if (dlDir != null) {
      savePath = "${dlDir.path}/$fileName";
    } else {
      Directory fallback = Directory('/storage/emulated/0/Download');
      if (!await fallback.exists()) {
        fallback = await getApplicationDocumentsDirectory();
      }
      savePath = "${fallback.path}/$fileName";
    }

    File file = File(savePath);
    await file.writeAsBytes(excel.encode()!);

    // 2. Client ke ar khujte hobe na - direct open/share
    await Share.shareXFiles([XFile(savePath)], text: 'RSLPL Challan Report - $todayDate $todayTime');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Saved! $fileName | Date: $todayDate'), duration: Duration(seconds: 4)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text('Scan Challan'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white),
      body: Stack(children: [
        CameraPreview(_controller),
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                margin: const EdgeInsets.all(20),
                child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                        onPressed: _scan,
                        icon: _processing
                           ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera),
                        label: Text(
                            _processing? 'Processing...' : 'Capture & Scan'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white)))))
      ]),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String vehicle, ticket, gross, tare, net, material, imagePath;
  const ResultScreen(
      {super.key,
      required this.vehicle,
      required this.ticket,
      required this.gross,
      required this.tare,
      required this.net,
      required this.material,
      required this.imagePath});

  Future<void> _saveToExcel(BuildContext context) async {
    try {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      var excel = Excel.createExcel();
      var sheet = excel['Sheet1'];
      sheet!.appendRow([
        TextCellValue('Vehicle No'),
        TextCellValue('Ticket No'),
        TextCellValue('Gross'),
        TextCellValue('Tare'),
        TextCellValue('Net'),
        TextCellValue('Material'),
        TextCellValue('Date')
      ]);
      sheet.appendRow([
        TextCellValue(vehicle),
        TextCellValue(ticket),
        TextCellValue(gross),
        TextCellValue(tare),
        TextCellValue(net),
        TextCellValue(material),
        TextCellValue(DateFormat('dd/MM/yyyy').format(DateTime.now()))
      ]);
      var dir = await getApplicationDocumentsDirectory();
      String path = "${dir.path}/RSLPL_Report.xlsx";
      File file = File(path);
      if (await file.exists()) {
        var bytes = await file.readAsBytes();
        var existing = Excel.decodeBytes(bytes);
        var s = existing['Sheet1'];
        s!.appendRow([
          TextCellValue(vehicle),
          TextCellValue(ticket),
          TextCellValue(gross),
          TextCellValue(tare),
          TextCellValue(net),
          TextCellValue(material),
          TextCellValue(DateFormat('dd/MM/yyyy').format(DateTime.now()))
        ]);
        await file.writeAsBytes(existing.encode()!);
      } else {
        await file.writeAsBytes(excel.encode()!);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
           .showSnackBar(SnackBar(content: Text('Saved to $path')));
        Navigator.pop(context, {
          "vehicle": vehicle,
          "ticket": ticket,
          "net": net,
          "material": material
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
           .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
            SizedBox(width: 8),
            Text('Scan Successful - Offline OCR',
                style: TextStyle(
                    color: Color(0xFF16A34A), fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 16),
          Text(vehicle,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          Text('$ticket • $material',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Gross', style: TextStyle(fontSize: 10)),
                      Text('$gross KGS',
                          style: const TextStyle(fontWeight: FontWeight.bold))
                    ])),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Tare', style: TextStyle(fontSize: 10)),
                      Text('$tare KGS',
                          style: const TextStyle(fontWeight: FontWeight.bold))
                    ])),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Net',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF16A34A))),
                      Text('$net KGS',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A)))
                    ])),
              ])),
          const Spacer(),
          SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                  onPressed: () => _saveToExcel(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                  child: const Text('Save to Excel (Offline)'))),
        ]),
      ),
    );
  }
}

import 'dart:math';
import 'package:intl/intl.dart';

class DummyDataGenerator {
  static String generateVehicle() {
    List states = ['WB', 'OD', 'JH', 'BR', 'KL'];
    var r = Random();
    return "${states[r.nextInt(states.length)]}${r.nextInt(10,99)}${String.fromCharCode(r.nextInt(26)+65)}${r.nextInt(1000,9999)}";
  }

  static Map<String, dynamic> generateChallan() {
    var r = Random();
    int tare = r.nextInt(12000, 15500);
    int gross = r.nextInt(35000, 52000);
    
    return {
      "vehicle": generateVehicle(),
      "ticket": "WB${r.nextInt(7000, 99999)}",
      "gross": gross,
      "tare": tare,
      "net": gross - tare,
      "material": ['BOULDER', 'SAND', 'AGGREGATE'][r.nextInt(3)],
      "date": DateFormat('dd-MM-yyyy').format(DateTime.now()),
      "time": DateFormat('hh:mm a').format(DateTime.now()),
    };
  }
}

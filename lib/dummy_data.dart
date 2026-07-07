import 'dart:math';

class DummyDataGenerator {
  static final _random = Random();
  
  static Map<String, dynamic> generateChallan() {
    int gross = 40000 + _random.nextInt(10000);
    int tare = 15000 + _random.nextInt(5000);
    int net = gross - tare;
    
    List<String> materials = ['Coal', 'Stone', 'Sand', 'Iron Ore', 'Dolomite'];
    
    return {
      'vehicle': 'WB${20 + _random.nextInt(79)}D${1000 + _random.nextInt(8999)}',
      'ticket': 'WB${80000 + _random.nextInt(9999)}',
      'gross': gross,
      'tare': tare,
      'net': net,
      'material': materials[_random.nextInt(materials.length)],
    };
  }
}

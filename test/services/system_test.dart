import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/system.dart';
import 'package:lanxi/models/system_info.dart';

void main() {
  test('SystemParser.parse produces a sane SystemInfo from sectioned output', () {
    const raw = '''
<<<LOAD>>>
0.50 0.40 0.30
<<<CPU>>>
us 12.3 sy 5.0 ni 0.0 id 82.7 wa 0.0 hi 0.0 si 0.0 st 0.0
<<<CPUINFO>>>
cpu cores : 4
model name : Intel Core
<<<MEM>>>
Mem: 8000000 3000000 4000000 1000000
<<<DISK>>>
2000000 1900000 100000
<<<UPTIME>>>
12345
<<<HOSTNAME>>>
myhost
<<<KERNEL>>>
5.15.0
<<<OS>>>
Ubuntu
''';

    final info = SystemParser.parse(raw);

    expect(info, isA<SystemInfo>());
    expect(info.cpuCores, 4);
    expect(info.cpuUsage, isA<double>());
    expect(info.memoryTotal, 8000000);
    expect(info.load1, closeTo(0.5, 0.001));
  });
}

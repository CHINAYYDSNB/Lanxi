import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/system.dart';
import 'package:lanxi/models/system_info.dart';

void main() {
  test('SystemParser.parse produces a sane SystemInfo from top output', () {
    const raw = '''
top - 10:00:00 up 1 day,  1:00,  1 user,  load average: 0.50, 0.40, 0.30
Tasks: 100 total,   2 running
%Cpu(s): 12.3 us,  5.0 sy,  0.0 ni, 82.7 id
%Cpu0  : 10.0 us,  0.0 sy
%Cpu1  : 20.0 us,  0.0 sy
KiB Mem :  8000000 total,  4000000 free,  3000000 used,  1000000 buff/cache
KiB Swap:  1000000 total,   900000 free,   100000 used
''';

    final info = SystemParser.parse(raw);

    expect(info, isA<SystemInfo>());
    expect(info.cpuCores, greaterThan(0));
    expect(info.cpuUsage, isA<double>());
    expect(info.memoryTotal, greaterThan(0));
    expect(info.load1, isA<double>());
  });
}

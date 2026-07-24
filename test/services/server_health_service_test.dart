import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/server_health_service.dart';
import 'package:lanxi/models/system_info.dart';

/// Recording fake of [SystemInfoSource] so we can assert the service
/// actually pulled a snapshot (real behavior, no mockito needed).
class FakeSource implements SystemInfoSource {
  int snapshotCalls = 0;
  SystemInfo? _value;

  void given(SystemInfo v) => _value = v;

  bool verifyCalled(String name) => name == 'snapshot' && snapshotCalls > 0;

  @override
  Future<SystemInfo> snapshot() {
    snapshotCalls++;
    return Future.value(_value!);
  }
}

SystemInfo sample({
  double cpu = 10,
  int memTotal = 1000,
  int memUsed = 100,
  int diskTotal = 2000,
  int diskUsed = 200,
  int cores = 4,
  double load1 = 0.5,
}) =>
    SystemInfo(
      cpuUsage: cpu,
      cpuCores: cores,
      cpuModel: 'Intel',
      memoryTotal: memTotal,
      memoryUsed: memUsed,
      memoryFree: memTotal - memUsed,
      diskTotal: diskTotal,
      diskUsed: diskUsed,
      diskFree: diskTotal - diskUsed,
      uptimeSeconds: 100,
      hostname: 'h',
      kernel: 'k',
      os: 'o',
      load1: load1,
      load5: 0,
      load15: 0,
    );

void main() {
  test('levelFor maps usage to health levels', () {
    expect(ServerHealthService.levelFor(50), HealthLevel.ok);
    expect(ServerHealthService.levelFor(80), HealthLevel.warning);
    expect(ServerHealthService.levelFor(95), HealthLevel.critical);
  });

  test('levelForLoad judges load relative to core count', () {
    expect(ServerHealthService.levelForLoad(0.5, 4), HealthLevel.ok);
    expect(ServerHealthService.levelForLoad(3.0, 4), HealthLevel.warning);
    expect(ServerHealthService.levelForLoad(4.5, 4), HealthLevel.critical);
  });

  test('evaluate pulls a snapshot and aggregates to critical', () async {
    final src = FakeSource()
      ..given(sample(
        cpu: 95,
        memUsed: 950,
        memTotal: 1000,
        diskUsed: 1900,
        diskTotal: 2000,
        load1: 4.2,
        cores: 4,
      ));
    final report = await ServerHealthService(src).evaluate();

    expect(src.verifyCalled('snapshot'), isTrue);
    expect(report.cpu, HealthLevel.critical);
    expect(report.memory, HealthLevel.critical);
    expect(report.disk, HealthLevel.critical);
    expect(report.load, HealthLevel.critical);
    expect(report.overall, HealthLevel.critical);
    expect(report.summary, contains('critical'));
  });

  test('evaluate reports ok for healthy resources', () async {
    final src = FakeSource()..given(sample());
    final report = await ServerHealthService(src).evaluate();

    expect(src.verifyCalled('snapshot'), isTrue);
    expect(report.cpu, HealthLevel.ok);
    expect(report.memory, HealthLevel.ok);
    expect(report.disk, HealthLevel.ok);
    expect(report.load, HealthLevel.ok);
    expect(report.overall, HealthLevel.ok);
  });
}

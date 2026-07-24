import '../models/system_info.dart';

enum HealthLevel { ok, warning, critical }

class HealthReport {
  final HealthLevel cpu;
  final HealthLevel memory;
  final HealthLevel disk;
  final HealthLevel load;
  final HealthLevel overall;
  final String summary;

  const HealthReport({
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.load,
    required this.overall,
    required this.summary,
  });
}

/// Abstract source of system metrics. Injectable so the service can be
/// tested without a real SSH connection.
abstract class SystemInfoSource {
  Future<SystemInfo> snapshot();
}

/// Evaluates server health from a [SystemInfo] snapshot.
///
/// Thresholds (percent): <75 ok, 75–90 warning, >=90 critical.
/// Load average is judged relative to core count.
class ServerHealthService {
  final SystemInfoSource source;

  ServerHealthService(this.source);

  static const double _warn = 75;
  static const double _crit = 90;

  static HealthLevel levelFor(double usage) {
    if (usage >= _crit) return HealthLevel.critical;
    if (usage >= _warn) return HealthLevel.warning;
    return HealthLevel.ok;
  }

  static HealthLevel levelForLoad(double load, int cores) {
    if (cores <= 0) return HealthLevel.ok;
    final ratio = load / cores;
    if (ratio >= 1.0) return HealthLevel.critical;
    if (ratio >= 0.7) return HealthLevel.warning;
    return HealthLevel.ok;
  }

  static HealthLevel _worst(List<HealthLevel> levels) {
    if (levels.contains(HealthLevel.critical)) return HealthLevel.critical;
    if (levels.contains(HealthLevel.warning)) return HealthLevel.warning;
    return HealthLevel.ok;
  }

  Future<HealthReport> evaluate() async {
    final info = await source.snapshot();

    final memPct = info.memoryTotal > 0
        ? info.memoryUsed * 100 / info.memoryTotal
        : 0.0;
    final diskPct = info.diskTotal > 0
        ? info.diskUsed * 100 / info.diskTotal
        : 0.0;

    final cpu = levelFor(info.cpuUsage);
    final memory = levelFor(memPct);
    final disk = levelFor(diskPct);
    final load = levelForLoad(info.load1, info.cpuCores);

    final overall = _worst([cpu, memory, disk, load]);

    final summary =
        'cpu=${info.cpuUsage.toStringAsFixed(1)}% mem=${memPct.toStringAsFixed(0)}% '
        'disk=${diskPct.toStringAsFixed(0)}% load1=${info.load1} -> $overall';

    return HealthReport(
      cpu: cpu,
      memory: memory,
      disk: disk,
      load: load,
      overall: overall,
      summary: summary,
    );
  }
}

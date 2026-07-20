import '../models/system_info.dart';

/// Parses combined system command output from AppContext.rawSystemInfo().
class SystemParser {
  static SystemInfo parse(String raw) {
    final sections = <String, String>{};
    final lines = raw.split('\n');
    String? current;
    for (final line in lines) {
      if (line.startsWith('<<<') && line.endsWith('>>>')) {
        current = line.substring(3, line.length - 3);
        sections[current] = '';
      } else if (current != null) {
        sections[current] = '${sections[current]}$line\n';
      }
    }

    return SystemInfo(
      cpuUsage: _parseCpu(sections['CPU'] ?? ''),
      cpuCores: _parseCores(sections['CPUINFO'] ?? ''),
      cpuModel: (sections['CPUINFO'] ?? '').trim(),
      memoryTotal: _parseMemField(sections['MEM'] ?? '', 'Mem:', 1),
      memoryUsed: _parseMemField(sections['MEM'] ?? '', 'Mem:', 2),
      memoryFree: _parseMemField(sections['MEM'] ?? '', 'Mem:', 3),
      diskTotal: _parseDiskField(sections['DISK'] ?? '', 1),
      diskUsed: _parseDiskField(sections['DISK'] ?? '', 2),
      diskFree: _parseDiskField(sections['DISK'] ?? '', 3),
      uptimeSeconds: _parseUptime(sections['UPTIME'] ?? ''),
      hostname: (sections['HOSTNAME'] ?? '').trim(),
      kernel: (sections['KERNEL'] ?? '').trim(),
      os: (sections['OS'] ?? '').trim().replaceAll('"', '').replaceAll("'", ''),
      load1: _parseLoadField(sections['LOAD']!, 0),
      load5: _parseLoadField(sections['LOAD']!, 1),
      load15: _parseLoadField(sections['LOAD']!, 2),
    );
  }

  static double _parseCpu(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length < 8) return 0;
    final user = int.tryParse(parts[1]) ?? 0;
    final nice = int.tryParse(parts[2]) ?? 0;
    final system = int.tryParse(parts[3]) ?? 0;
    final idle = int.tryParse(parts[4]) ?? 0;
    final iowait = int.tryParse(parts[5]) ?? 0;
    final total = user + nice + system + idle + iowait;
    if (total == 0) return 0;
    return ((total - idle - iowait) * 100 / total);
  }

  static int _parseCores(String s) {
    final match = RegExp(r'cpu cores\s*:\s*(\d+)', caseSensitive: false).firstMatch(s);
    if (match != null) return int.tryParse(match.group(1)!) ?? 1;
    return 1;
  }

  static int _parseMemField(String s, String prefix, int idx) {
    for (final line in s.split('\n')) {
      if (line.startsWith(prefix)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length > idx) return int.tryParse(parts[idx]) ?? 0;
      }
    }
    return 0;
  }

  static int _parseDiskField(String s, int idx) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length > idx) return int.tryParse(parts[idx]) ?? 0;
    return 0;
  }

  static int _parseUptime(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    return (double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0).toInt();
  }

  static double _parseLoadField(String s, int idx) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length > idx) return double.tryParse(parts[idx]) ?? 0;
    return 0;
  }
}

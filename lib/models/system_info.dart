class SystemInfo {
  final double cpuUsage;
  final int cpuCores;
  final String cpuModel;
  final int memoryTotal;   // bytes
  final int memoryUsed;
  final int memoryFree;
  final int diskTotal;     // bytes
  final int diskUsed;
  final int diskFree;
  final int uptimeSeconds;
  final String hostname;
  final String kernel;
  final String os;
  final double load1;
  final double load5;
  final double load15;

  SystemInfo({
    required this.cpuUsage,
    required this.cpuCores,
    required this.cpuModel,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.memoryFree,
    required this.diskTotal,
    required this.diskUsed,
    required this.diskFree,
    required this.uptimeSeconds,
    required this.hostname,
    required this.kernel,
    required this.os,
    required this.load1,
    required this.load5,
    required this.load15,
  });

  String get memoryUsage => memoryTotal > 0
      ? '${(memoryUsed * 100 / memoryTotal).toStringAsFixed(1)}%'
      : '0%';
  String get diskUsage => diskTotal > 0
      ? '${(diskUsed * 100 / diskTotal).toStringAsFixed(1)}%'
      : '0%';

  String fmt(int bytes) {
    const u = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double v = bytes.toDouble();
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${u[i]}';
  }

  String get memoryTotalStr => fmt(memoryTotal);
  String get memoryUsedStr => fmt(memoryUsed);
  String get diskTotalStr => fmt(diskTotal);
  String get diskUsedStr => fmt(diskUsed);

  String get formattedUptime {
    final d = uptimeSeconds ~/ 86400;
    final h = (uptimeSeconds % 86400) ~/ 3600;
    final m = (uptimeSeconds % 3600) ~/ 60;
    final parts = <String>[];
    if (d > 0) parts.add('${d}天');
    if (h > 0) parts.add('${h}时');
    if (m > 0) parts.add('${m}分');
    return parts.isEmpty ? '${uptimeSeconds}秒' : parts.join(' ');
  }
}

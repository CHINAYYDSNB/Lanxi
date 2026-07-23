import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../core/context.dart';

class PanelCheckResult {
  final bool success;
  final String msg;
  const PanelCheckResult({required this.success, required this.msg});
}

class PanelMonitorData {
  final List<MonitorPoint> cpu;
  final List<MonitorPoint> memory;
  final List<MonitorPoint> diskIo;
  final List<MonitorPoint> netIo;
  final List<MonitorPoint> load;
  final DateTime start;
  final DateTime end;

  const PanelMonitorData({
    this.cpu = const [],
    this.memory = const [],
    this.diskIo = const [],
    this.netIo = const [],
    this.load = const [],
    required this.start,
    required this.end,
  });
}

class MonitorPoint {
  final DateTime time;
  final double value;
  const MonitorPoint({required this.time, required this.value});
}

class PanelApiService {
  // ─── Connectivity checks ───

  /// Check 1Panel API connectivity.
  /// 1Panel uses: GET /api/v1/auth with 1Panel-Token header.
  static Future<PanelCheckResult> check1Panel(String host, int port, String apiKey) async {
    if (!AppContext.i.isConnected) {
      return const PanelCheckResult(success: false, msg: 'SSH 未连接');
    }
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _panelToken(apiKey, ts);
      final r = await AppContext.i.exec(
        'curl -sk -m 10 "https://$host:$port/api/v1/dashboard/current" '
        '-H "1Panel-Token: $token" -H "1Panel-Timestamp: $ts" 2>/dev/null',
        timeout: const Duration(seconds: 12),
      );
      if (!r.isSuccess) {
        return PanelCheckResult(success: false, msg: '请求失败: ${r.stderr}');
      }
      try {
        final json = jsonDecode(r.stdout);
        if (json is Map && json['code'] == 200) {
          return const PanelCheckResult(success: true, msg: '连接成功');
        }
        return PanelCheckResult(success: false, msg: '响应异常: ${r.stdout.substring(0, min(r.stdout.length, 80))}');
      } catch (_) {
        return PanelCheckResult(success: false, msg: '非JSON响应,可能端口不正确');
      }
    } catch (e) {
      return PanelCheckResult(success: false, msg: e.toString());
    }
  }

  /// Check BT Panel API connectivity.
  /// BT uses: POST /system?action=GetSystemTotal with request_token.
  static Future<PanelCheckResult> checkBt(String host, int port, String apiKey) async {
    if (!AppContext.i.isConnected) {
      return const PanelCheckResult(success: false, msg: 'SSH 未连接');
    }
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _btToken(apiKey, ts);
      final r = await AppContext.i.exec(
        'curl -sk -m 10 -X POST '
        '"https://$host:$port/system?action=GetSystemTotal" '
        '-d "request_token=$token&request_time=$ts" 2>/dev/null',
        timeout: const Duration(seconds: 12),
      );
      if (!r.isSuccess) {
        return PanelCheckResult(success: false, msg: '请求失败: ${r.stderr}');
      }
      try {
        final json = jsonDecode(r.stdout);
        if (json is Map && json['status'] != null) {
          return const PanelCheckResult(success: true, msg: '连接成功');
        }
        return PanelCheckResult(success: false, msg: '响应异常: ${r.stdout.substring(0, min(r.stdout.length, 80))}');
      } catch (_) {
        return PanelCheckResult(success: false, msg: '非JSON响应,可能端口或Key不正确');
      }
    } catch (e) {
      return PanelCheckResult(success: false, msg: e.toString());
    }
  }

  // ─── Monitoring data ───

  /// Fetch monitoring data from 1Panel.
  /// 1Panel monitor API: POST /api/v1/monitor/search
  /// Body: {"param": {"startTime": "...", "endTime": "...", "interval": 60}}
  static Future<PanelMonitorData> fetch1Panel({
    required String host,
    required int port,
    required String apiKey,
    required DateTime start,
    required DateTime end,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = _panelToken(apiKey, ts);
    final st = start.toIso8601String();
    final et = end.toIso8601String();

    Future<List<MonitorPoint>> fetchMetric(String type) async {
      try {
        final body = jsonEncode({
          'param': {
            'startTime': st,
            'endTime': et,
            'interval': 60,
          }
        });
        final r = await AppContext.i.exec(
          'curl -sk -m 15 -X POST '
          '"https://$host:$port/api/v1/monitor/search" '
          '-H "1Panel-Token: $token" -H "1Panel-Timestamp: $ts" '
          '-H "Content-Type: application/json" '
          '-d \'${body.replaceAll("'", "'\\''")}\' 2>/dev/null',
          timeout: const Duration(seconds: 18),
        );
        if (!r.isSuccess) return [];
        final json = jsonDecode(r.stdout);
        if (json is! Map || json['code'] != 200) return [];
        final data = json['data'];
        if (data is! Map) return [];
        final list = data[type];
        if (list is! List) return [];
        return list.map<MonitorPoint>((p) {
          return MonitorPoint(
            time: DateTime.tryParse(p['time']?.toString() ?? '') ?? DateTime.now(),
            value: double.tryParse(p['value']?.toString() ?? '0') ?? 0,
          );
        }).toList();
      } catch (_) {
        return [];
      }
    }

    final results = await Future.wait([
      fetchMetric('cpu'),
      fetchMetric('memory'),
      fetchMetric('io'),
      fetchMetric('network'),
      fetchMetric('load'),
    ]);

    return PanelMonitorData(
      cpu: results[0], memory: results[1], diskIo: results[2],
      netIo: results[3], load: results[4],
      start: start, end: end,
    );
  }

  /// Fetch monitoring data from BT Panel.
  /// BT doesn't have a unified monitor API; uses individual endpoints.
  static Future<PanelMonitorData> fetchBt({
    required String host,
    required int port,
    required String apiKey,
    required DateTime start,
    required DateTime end,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = _btToken(apiKey, ts);
    final List<MonitorPoint> allPoints = [];

    // Get network info (current snapshot only for BT)
    try {
      final r = await AppContext.i.exec(
        'curl -sk -m 10 -X POST '
        '"https://$host:$port/system?action=GetNetWork" '
        '-d "request_token=$token&request_time=$ts" 2>/dev/null',
        timeout: const Duration(seconds: 12),
      );
      if (r.isSuccess) {
        final json = jsonDecode(r.stdout);
        if (json is Map) {
          final netUp = double.tryParse(json['network']['upTotal']?.toString() ?? '0') ?? 0;
          final netDown = double.tryParse(json['network']['downTotal']?.toString() ?? '0') ?? 0;
          allPoints.add(MonitorPoint(time: DateTime.now(), value: netUp + netDown));
        }
      }
    } catch (_) {}

    // Get disk info
    try {
      final r = await AppContext.i.exec(
        'curl -sk -m 10 -X POST '
        '"https://$host:$port/system?action=GetDiskInfo" '
        '-d "request_token=$token&request_time=$ts" 2>/dev/null',
        timeout: const Duration(seconds: 12),
      );
      if (r.isSuccess) {
        final json = jsonDecode(r.stdout);
        if (json is List) {
          double totalRead = 0, totalWrite = 0;
          for (final disk in json) {
            totalRead += double.tryParse(disk['readCount']?.toString() ?? '0') ?? 0;
            totalWrite += double.tryParse(disk['writeCount']?.toString() ?? '0') ?? 0;
          }
          allPoints.add(MonitorPoint(time: DateTime.now(), value: totalRead + totalWrite));
        }
      }
    } catch (_) {}

    // Get system load
    try {
      final r = await AppContext.i.exec(
        'curl -sk -m 10 -X POST '
        '"https://$host:$port/system?action=GetTaskCount" '
        '-d "request_token=$token&request_time=$ts" 2>/dev/null',
        timeout: const Duration(seconds: 12),
      );
      if (r.isSuccess) {
        final json = jsonDecode(r.stdout);
        if (json is Map) {
          final load = double.tryParse(json['load']?['one']?.toString() ?? '0') ?? 0;
          allPoints.add(MonitorPoint(time: DateTime.now(), value: load));
        }
      }
    } catch (_) {}

    return PanelMonitorData(
      netIo: allPoints,
      start: start, end: end,
    );
  }

  // ─── Auth helpers ───

  /// 1Panel token: md5("1panel" + apiKey + timestamp)
  static String _panelToken(String apiKey, int ts) {
    final input = '1panel$apiKey$ts';
    return md5.convert(utf8.encode(input)).toString();
  }

  /// BT token: md5(md5(apiKey) + timestamp)
  static String _btToken(String apiKey, int ts) {
    final md5Key = md5.convert(utf8.encode(apiKey)).toString();
    return md5.convert(utf8.encode('$md5Key$ts')).toString();
  }
}

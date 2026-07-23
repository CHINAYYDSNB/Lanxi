import 'package:flutter/material.dart';
import '../../services/panel_api_service.dart';
import '../../services/storage_service.dart';
import '../../models/ssh_config.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  PanelMonitorData? _data;
  bool _loading = true;
  String? _error;
  Duration _range = const Duration(hours: 1);
  SshConfig? _config;

  static const _ranges = [
    ('1小时', Duration(hours: 1)),
    ('6小时', Duration(hours: 6)),
    ('24小时', Duration(hours: 24)),
    ('7天', Duration(days: 7)),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final raw = await StorageService.instance.getSshConnections();
    if (raw != null && raw.isNotEmpty) {
      final first = raw.first;
      _config = SshConfig(
        host: first['host']?.toString() ?? '',
        port: int.tryParse(first['port']?.toString() ?? '') ?? 22,
        username: first['username']?.toString() ?? 'root',
        password: first['password']?.toString(),
        privateKey: first['privateKey']?.toString(),
        panel1PanelPort: first['panel1PanelPort']?.toString(),
        panel1PanelApiKey: first['panel1PanelApiKey']?.toString(),
        panelBtPort: first['panelBtPort']?.toString(),
        panelBtApiKey: first['panelBtApiKey']?.toString(),
      );
      if (_config!.hasAnyPanel) _fetch();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetch() async {
    if (_config == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final end = DateTime.now();
      final start = end.subtract(_range);

      if (_config!.hasPanel1Panel) {
        _data = await PanelApiService.fetch1Panel(
          host: _config!.host,
          port: int.tryParse(_config!.panel1PanelPort ?? '') ?? 0,
          apiKey: _config!.panel1PanelApiKey ?? '',
          start: start, end: end,
        );
      } else if (_config!.hasPanelBt) {
        _data = await PanelApiService.fetchBt(
          host: _config!.host,
          port: int.tryParse(_config!.panelBtPort ?? '') ?? 0,
          apiKey: _config!.panelBtApiKey ?? '',
          start: start, end: end,
        );
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasPanel = _config?.hasAnyPanel == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('监控'),
        actions: [
          if (hasPanel) IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: !hasPanel
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFFAAB4BF)),
                  const SizedBox(height: 16),
                  const Text('未配置面板 API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('在 SSH 配置页面填写 1Panel 或宝塔面板的\nAPI Key 后即可查看监控数据',
                      textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF686F78))),
                ]),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _fetch, child: const Text('重试')),
                    ]))
                  : _data == null
                      ? const Center(child: Text('暂无数据', style: TextStyle(color: Color(0xFF686F78))))
                      : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
                          // Time range selector
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: _ranges.map((r) {
                              final selected = _range == r.$2;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(r.$1),
                                  selected: selected,
                                  onSelected: (_) {
                                    setState(() => _range = r.$2);
                                    _fetch();
                                  },
                                ),
                              );
                            }).toList()),
                          ),
                          const SizedBox(height: 12),
                          if (_data!.cpu.isNotEmpty) _chartCard('CPU (%)', _data!.cpu, Colors.blue, formatValue: (v) => '${v.toStringAsFixed(1)}%'),
                          if (_data!.memory.isNotEmpty) _chartCard('内存 (%)', _data!.memory, Colors.green),
                          if (_data!.diskIo.isNotEmpty) _chartCard('磁盘 IO (MB/s)', _data!.diskIo, Colors.orange),
                          if (_data!.netIo.isNotEmpty) _chartCard('网络 IO (KB/s)', _data!.netIo, Colors.purple),
                          if (_data!.load.isNotEmpty) _chartCard('负载', _data!.load, Colors.red, formatValue: (v) => v.toStringAsFixed(2)),
                        ]),
    );
  }

  Widget _chartCard(String title, List<MonitorPoint> points, Color color, {String Function(double)? formatValue}) {
    final theme = Theme.of(context);
    if (points.isEmpty) return const SizedBox.shrink();

    final values = points.map((p) => p.value).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final avg = values.fold(0.0, (a, b) => a + b) / values.length;
    final current = values.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(formatValue != null ? formatValue(current) : current.toStringAsFixed(1),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _stat('最大', maxVal, formatValue),
            const SizedBox(width: 16),
            _stat('最小', minVal, formatValue),
            const SizedBox(width: 16),
            _stat('平均', avg, formatValue),
          ]),
          const SizedBox(height: 10),
          // Sparkline-like bars
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _SparklinePainter(values, maxVal, color),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, double value, String Function(double)? format) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFAAB4BF))),
      Text(format != null ? format(value) : value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
    ]);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double max;
  final Color color;
  _SparklinePainter(this.values, this.max, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color.withAlpha(30)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final barW = (size.width / values.length) * 0.8;
    final gap = (size.width / values.length) * 0.2;
    final scale = max > 0 ? (size.height - 4) / max : 0.0;

    // Draw area and line
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * (barW + gap) + gap / 2;
      final h = values[i] * scale;
      final y = size.height - h;
      // Draw bar
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, y, barW, h), topLeft: const Radius.circular(1), topRight: const Radius.circular(1)),
        paint,
      );
      // Build line path
      if (i == 0) {
        path.moveTo(x + barW / 2, y);
      } else {
        path.lineTo(x + barW / 2, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

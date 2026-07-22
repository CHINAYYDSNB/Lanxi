import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/context.dart';
import '../../models/compose.dart';
import '../../models/container.dart';
import 'container_detail_page.dart';

class ComposeDetailPage extends StatefulWidget {
  final ComposeInfo compose;
  const ComposeDetailPage({super.key, required this.compose});

  @override
  State<ComposeDetailPage> createState() => _ComposeDetailPageState();
}

class _ComposeDetailPageState extends State<ComposeDetailPage> {
  List<Map<String, dynamic>> _containers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = widget.compose;
    final files = c.configFiles.split(',').first;
    final dir = files.split('/').reversed.skip(1).toList().reversed.join('/');
    final file = files.split('/').last;

    setState(() => _loading = true);
    try {
      final r = await AppContext.i.exec('cd "$dir" && docker compose -f "$file" ps --format json 2>/dev/null || echo ""');
      final lines = r.stdout.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final list = <Map<String, dynamic>>[];
      for (final l in lines) {
        try { list.add(jsonDecode(l) as Map<String, dynamic>); } catch (_) {}
      }
      if (mounted) setState(() { _containers = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.compose;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c.name), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row('状态', c.status),
                  _row('配置文件', c.configFiles),
                ])),
              ),
              const SizedBox(height: 10),
              if (_containers.isNotEmpty)
                Text('容器 (${_containers.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._containers.map((ctr) => Card(
                child: ListTile(
                  leading: Icon(ctr['State']?.toString() == 'running' ? Icons.play_circle : Icons.stop_circle,
                      color: ctr['State']?.toString() == 'running' ? Colors.green : Colors.red, size: 28),
                  title: Text(ctr['Name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(ctr['Image']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
                  onTap: () {
                    final mapped = Map<String, dynamic>.from(ctr);
                    mapped['Id'] = mapped.remove('ID');
                    mapped['Names'] = mapped.remove('Name');
                    final info = ContainerInfo.fromJson(mapped);
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ContainerDetailPage(container: info)),
                    );
                  },
                ),
              )),
              if (_containers.isEmpty && !_loading)
                const Center(child: Text('无容器', style: TextStyle(color: Color(0xFF686F78)))),
              const SizedBox(height: 90),
            ]),
    );
  }

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Color(0xFF686F78), fontSize: 13))),
      Expanded(child: Text(val, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

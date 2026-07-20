import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/container.dart';
import '../../providers/docker/container.dart';

class ContainerDetailPage extends ConsumerStatefulWidget {
  final ContainerInfo container;
  const ContainerDetailPage({super.key, required this.container});

  @override
  ConsumerState<ContainerDetailPage> createState() => _ContainerDetailPageState();
}

class _ContainerDetailPageState extends ConsumerState<ContainerDetailPage> {
  Map<String, dynamic>? _inspect;
  Map<String, dynamic>? _stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docker = AppContext.i;
    final c = widget.container;
    final [insp, stat] = await Future.wait([
      docker.exec('docker inspect ${c.name}').then((r) {
        try { return (jsonDecode(r.stdout) as List).first as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
      }),
      docker.exec("docker stats --no-stream --format '{{json .}}' ${c.name}").then((r) {
        try { return jsonDecode(r.stdout) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
      }),
    ]);
    if (mounted) setState(() { _inspect = insp; _stats = stat; });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.container;
    final theme = Theme.of(context);

    final cfg = (_inspect?['Config'] as Map<String, dynamic>?);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          if (c.isRunning)
            IconButton(icon: const Icon(Icons.stop), tooltip: '停止', onPressed: () => _op('stop')),
          if (!c.isRunning)
            IconButton(icon: const Icon(Icons.play_arrow), tooltip: '启动', onPressed: () => _op('start')),
          IconButton(icon: const Icon(Icons.restart_alt), tooltip: '重启', onPressed: () => _op('restart')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Icon(c.isRunning ? Icons.check_circle : Icons.cancel, color: c.isRunning ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(c.state, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ]),
                if (_stats != null) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _statCol('CPU', (_stats!['CPUPerc'] ?? '-').toString()),
                    _statCol('内存', (_stats!['MemUsage'] ?? '-').toString()),
                    _statCol('网络 I/O', (_stats!['NetIO'] ?? '-').toString()),
                  ]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row('镜像', c.image),
                _row('状态', c.status),
                _row('创建', c.created),
                if (c.ports.isNotEmpty) _row('端口', c.ports.join(', ')),
                if (cfg != null) ...[
                  _row('路径', (cfg['WorkingDir'] ?? '-').toString()),
                  _row('环境变量', '${(cfg['Env'] as List<dynamic>?)?.length ?? 0} 个'),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Logs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('日志', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 400,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _LogViewer(name: c.name),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF686F78))),
  ]);

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Color(0xFF686F78), fontSize: 13))),
      Expanded(child: Text(val, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Future<void> _op(String op) async {
    final err = await AppContext.i.dockerExec('$op ${widget.container.name}').then((r) => r.isSuccess ? '' : r.stderr);
    if (err.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ref.read(containerListProvider.notifier).refresh();
      _load();
    }
  }
}

class _LogViewer extends ConsumerStatefulWidget {
  final String name;
  const _LogViewer({required this.name});

  @override
  ConsumerState<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends ConsumerState<_LogViewer> {
  final _lines = <String>[];
  final _scroll = ScrollController();
  late StreamSubscription<String> _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final docker = AppContext.i;
    final r = await docker.exec('docker logs --tail 200 ${widget.name}');
    if (mounted && r.stdout.isNotEmpty) {
      setState(() => _lines.addAll(r.stdout.split('\n')));
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _scrollToEnd() {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _sub.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      itemCount: _lines.length,
      itemBuilder: (_, i) => Text(
        _lines[i],
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.greenAccent, height: 1.4),
      ),
    );
  }
}

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
  bool _operating = false;

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

    // Watch container list for reactive state (F3 + F5)
    final containerListAsync = ref.watch(containerListProvider);
    final isRunning = containerListAsync.maybeWhen(
      data: (containers) =>
          containers.firstWhere((ct) => ct.name == c.name, orElse: () => c).isRunning,
      orElse: () => c.isRunning,
    );
    Widget? composeWarning;
    final containers = containerListAsync.asData?.value;
    if (containers != null) {
      composeWarning = _buildComposeWarning(containers);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          if (_operating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (isRunning)
              IconButton(icon: const Icon(Icons.stop), tooltip: '停止', onPressed: () => _op('stop')),
            if (!isRunning)
              IconButton(icon: const Icon(Icons.play_arrow), tooltip: '启动', onPressed: () => _op('start')),
            IconButton(icon: const Icon(Icons.restart_alt), tooltip: '重启', onPressed: () => _op('restart')),
          ],
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
                  Icon(isRunning ? Icons.check_circle : Icons.cancel, color: isRunning ? Colors.green : Colors.red, size: 20),
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
          // Compose multi-container warning (F3)
          if (composeWarning != null) ...[
            const SizedBox(height: 10),
            composeWarning,
          ],
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
    final label = {'start': '启动', 'stop': '停止', 'restart': '重启'}[op] ?? op;
    setState(() => _operating = true);
    final err = await AppContext.i.dockerExec('$op ${widget.container.name}')
        .then((r) => r.isSuccess ? '' : r.stderr);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.isEmpty ? '${widget.container.name} $label成功' : err),
        backgroundColor: err.isEmpty ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    }
    if (err.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      ref.read(containerListProvider.notifier).refresh();
      _load();
    }
    if (mounted) setState(() => _operating = false);
  }

  String? _getComposeProject() {
    final fromPs = widget.container.labels['com.docker.compose.project'];
    if (fromPs != null && fromPs.isNotEmpty) return fromPs;
    final labels = _inspect?['Config']?['Labels'] as Map<String, dynamic>?;
    return labels?['com.docker.compose.project']?.toString();
  }

  Widget? _buildComposeWarning(List<ContainerInfo> containers) {
    final project = _getComposeProject();
    if (project == null || project.isEmpty) return null;
    final count = containers
        .where((ct) => ct.labels['com.docker.compose.project'] == project)
        .length;
    if (count <= 1) return null;
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '此容器属于 Compose 项目 $project，对该容器的操作（启动/停止/重启/删除）会影响同一 Compose 中的其他容器。',
                style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/docker/container.dart';
import '../../widgets/docker_check.dart';
import 'container_detail_page.dart';

class ContainerListPage extends ConsumerStatefulWidget {
  const ContainerListPage({super.key});

  @override
  ConsumerState<ContainerListPage> createState() => _ContainerListPageState();
}

class _ContainerListPageState extends ConsumerState<ContainerListPage> {
  final _operating = <String>{};

  Future<void> _handleOp(String name, String op) async {
    final n = ref.read(containerListProvider.notifier);
    final label = {'start':'启动','stop':'停止','restart':'重启','remove':'删除'}[op] ?? op;
    setState(() => _operating.add(name));
    final err = op == 'remove' ? await n.remove(name) : await n.operate(name, op);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.isEmpty ? '$name $label成功' : err),
        backgroundColor: err.isEmpty ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    }
    if (err.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      n.refresh();
    }
    if (mounted) setState(() => _operating.remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(containerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('容器'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(containerListProvider.notifier).refresh()),
        ],
      ),
      body: DockerCheck(child: list.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('无容器', style: TextStyle(color: Color(0xFF686F78))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final c = items[i];
                  final running = c.isRunning;
                  final loading = _operating.contains(c.name);
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContainerDetailPage(container: c))),
                      leading: loading
                          ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(running ? Icons.play_circle : Icons.stop_circle,
                              color: running ? Colors.green : Colors.red, size: 32),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.image, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
                      trailing: loading ? null : PopupMenuButton<String>(
                        onSelected: (op) => _handleOp(c.name, op),
                        itemBuilder: (_) => [
                          if (running) const PopupMenuItem(value: 'stop', child: Text('停止')),
                          if (!running) const PopupMenuItem(value: 'start', child: Text('启动')),
                          if (running) const PopupMenuItem(value: 'restart', child: Text('重启')),
                          const PopupMenuItem(value: 'remove', child: Text('删除', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  );
                }),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
      ),
    ));
  }
}

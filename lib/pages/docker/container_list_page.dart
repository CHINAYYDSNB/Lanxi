import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/docker/container.dart';
import 'container_detail_page.dart';

class ContainerListPage extends ConsumerWidget {
  const ContainerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(containerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('容器'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(containerListProvider.notifier).refresh()),
        ],
      ),
      body: list.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('无容器', style: TextStyle(color: Color(0xFF686F78))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final c = items[i];
                  final running = c.isRunning;
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContainerDetailPage(container: c))),
                      leading: Icon(
                        running ? Icons.play_circle : Icons.stop_circle,
                        color: running ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.image, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) => _handleOp(context, ref, c.name, op),
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
    );
  }

  void _handleOp(BuildContext context, WidgetRef ref, String name, String op) async {
    final n = ref.read(containerListProvider.notifier);
    String? err;
    if (op == 'remove') {
      err = await n.remove(name);
    } else {
      err = await n.operate(name, op);
    }
    if (err.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

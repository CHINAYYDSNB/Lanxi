import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/docker/compose.dart';
import 'compose_detail_page.dart';

class ComposeListPage extends ConsumerStatefulWidget {
  const ComposeListPage({super.key});

  @override
  ConsumerState<ComposeListPage> createState() => _ComposeListPageState();
}

class _ComposeListPageState extends ConsumerState<ComposeListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(composeListProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(composeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(composeListProvider.notifier).refresh()),
        ],
      ),
      body: list.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('无 Compose', style: TextStyle(color: Color(0xFF686F78))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final c = items[i];
                  final running = c.status.toLowerCase().contains('running');
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComposeDetailPage(compose: c))),
                      leading: Icon(
                        running ? Icons.dns : Icons.dns_outlined,
                        color: running ? Colors.green : const Color(0xFF686F78),
                        size: 32,
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.status, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) => _op(c.name, c.configFiles, op),
                        itemBuilder: (_) => [
                          if (running) const PopupMenuItem(value: 'down', child: Text('停止')),
                          if (!running) const PopupMenuItem(value: 'up', child: Text('启动')),
                          const PopupMenuItem(value: 'restart', child: Text('重启')),
                        ],
                      ),
                    ),
                  );
                }),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  void _op(String name, String files, String op) async {
    final workdir = files.split(',').first.split('/').reversed.skip(1).toList().reversed.join('/');
    final err = await ref.read(composeListProvider.notifier).operate(workdir, op);
    if (err.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

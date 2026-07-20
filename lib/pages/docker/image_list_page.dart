import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/docker/image.dart';

class ImageListPage extends ConsumerWidget {
  const ImageListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(imageListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('镜像'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(imageListProvider.notifier).refresh()),
          IconButton(icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => _prune(context, ref)),
        ],
      ),
      body: list.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('无镜像', style: TextStyle(color: Color(0xFF686F78))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final img = items[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.image_outlined, size: 32, color: Colors.teal),
                      title: Text('${img.repository}:${img.tag}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(img.size, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _remove(context, ref, img.id),
                      ),
                    ),
                  );
                }),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  void _remove(BuildContext context, WidgetRef ref, String id) async {
    final err = await ref.read(imageListProvider.notifier).remove(id);
    if (err.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _prune(BuildContext context, WidgetRef ref) async {
    final out = await ref.read(imageListProvider.notifier).prune();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(out.isNotEmpty ? out : '清理完成')));
    }
  }
}

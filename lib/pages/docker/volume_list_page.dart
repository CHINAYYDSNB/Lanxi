import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/context.dart';

class VolumeListPage extends StatefulWidget {
  const VolumeListPage({super.key});

  @override
  State<VolumeListPage> createState() => _VolumeListPageState();
}

class _VolumeListPageState extends State<VolumeListPage> {
  List<Map<String, dynamic>> _volumes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await AppContext.i.exec("docker volume ls --format '{{json .}}'");
    final vols = r.stdout.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return jsonDecode(l) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
    if (mounted) setState(() { _volumes = vols; _loading = false; });
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('创建卷'), content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '卷名', border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建'))],
      ),
    );
    if (name != null && name.isNotEmpty) { await AppContext.i.exec('docker volume create $name'); _load(); }
  }

  Future<void> _remove(String name) async {
    await AppContext.i.exec('docker volume rm $name');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据卷'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(icon: const Icon(Icons.add), onPressed: _create),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _volumes.isEmpty ? const Center(child: Text('无数据卷', style: TextStyle(color: Color(0xFF686F78))))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), itemCount: _volumes.length, itemBuilder: (_, i) {
            final v = _volumes[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.storage, size: 32, color: Colors.teal),
                title: Text(v['Name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(v['Driver']?.toString() ?? 'local'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _remove(v['Name']?.toString() ?? '')),
              ),
            );
          }),
    );
  }
}

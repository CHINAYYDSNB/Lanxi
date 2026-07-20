import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/context.dart';

class NetworkListPage extends StatefulWidget {
  const NetworkListPage({super.key});

  @override
  State<NetworkListPage> createState() => _NetworkListPageState();
}

class _NetworkListPageState extends State<NetworkListPage> {
  List<Map<String, dynamic>> _nets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await AppContext.i.exec("docker network ls --format '{{json .}}'");
    final nets = r.stdout.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return jsonDecode(l) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
    if (mounted) setState(() { _nets = nets; _loading = false; });
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('创建网络'), content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '网络名', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建'))],
    ));
    if (name != null && name.isNotEmpty) { await AppContext.i.exec('docker network create $name'); _load(); }
  }

  Future<void> _remove(String name) async {
    await AppContext.i.exec('docker network rm $name');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(icon: const Icon(Icons.add), onPressed: _create),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _nets.isEmpty ? const Center(child: Text('无网络', style: TextStyle(color: Color(0xFF686F78))))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), itemCount: _nets.length, itemBuilder: (_, i) {
            final n = _nets[i];
            final name = n['Name']?.toString() ?? '';
            final isDefault = name == 'bridge' || name == 'host' || name == 'none';
            return Card(
              child: ListTile(
                leading: Icon(Icons.hub, size: 32, color: isDefault ? const Color(0xFF686F78) : Colors.indigo),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(n['Driver']?.toString() ?? 'bridge'),
                trailing: isDefault ? null : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _remove(name)),
              ),
            );
          }),
    );
  }
}

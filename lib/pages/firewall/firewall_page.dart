import 'package:flutter/material.dart';
import '../../core/context.dart';

class FirewallPage extends StatefulWidget {
  const FirewallPage({super.key});

  @override
  State<FirewallPage> createState() => _FirewallPageState();
}

class _FirewallPageState extends State<FirewallPage> {
  final _ctx = AppContext.i;
  bool _hasUfw = false;
  bool _enabled = false;
  List<String> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final has = await _ctx.hasFirewall();
    if (has) {
      final r = await _ctx.exec('sudo ufw status numbered 2>/dev/null');
      final lines = r.stdout.split('\n');
      if (mounted) {
        setState(() {
          _hasUfw = true;
          _enabled = lines.any((l) => l.contains('Status: active'));
          _rules = lines.where((l) => l.trim().startsWith('[')).toList();
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() { _hasUfw = false; _loading = false; });
    }
  }

  Future<void> _toggle() async {
    await _ctx.exec(_enabled ? 'sudo ufw --force disable' : 'sudo ufw --force enable');
    _load();
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加规则'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(
          hintText: '例: 80/tcp  或  443',
          border: OutlineInputBorder(),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _ctx.exec('sudo ufw allow ${ctrl.text.trim()}');
      _load();
    }
  }

  Future<void> _delete(int num) async {
    await _ctx.exec('sudo ufw --force delete $num');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('防火墙'),
        actions: [
          if (_hasUfw) ...[
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            IconButton(icon: const Icon(Icons.add), onPressed: _add),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasUfw
              ? _notInstalled(theme)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
                  Card(
                    child: SwitchListTile(
                      secondary: Icon(_enabled ? Icons.shield : Icons.shield_outlined,
                          color: _enabled ? Colors.green : const Color(0xFF686F78)),
                      title: Text(_enabled ? '已启用' : '已禁用',
                          style: TextStyle(fontWeight: FontWeight.w600, color: _enabled ? Colors.green : null)),
                      value: _enabled,
                      onChanged: (_) => _toggle(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_rules.isEmpty)
                    const Card(
                      child: Padding(padding: EdgeInsets.all(24),
                          child: Center(child: Text('无规则', style: TextStyle(color: Color(0xFF686F78))))),
                    ),
                  ..._rules.map((r) => _ruleCard(r, theme)),
                ]),
    );
  }

  Widget _ruleCard(String line, ThemeData theme) {
    final match = RegExp(r'^\[\s*(\d+)\]\s+(.+)$').firstMatch(line.trim());
    if (match == null) return const SizedBox.shrink();
    final num = int.tryParse(match.group(1)!) ?? 0;
    final rule = match.group(2)!;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withAlpha(25),
          child: const Icon(Icons.check, color: Colors.green, size: 20),
        ),
        title: Text(rule, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () => _delete(num),
        ),
      ),
    );
  }

  Widget _notInstalled(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('UFW 未安装', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('在服务器上运行以下命令安装：',
              style: TextStyle(color: Color(0xFF686F78))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('sudo apt install ufw -y',
                style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 14)),
          ),
          const SizedBox(height: 16),
          Text('更多脚本可前往脚本商店安装',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 13)),
        ]),
      ),
    );
  }
}

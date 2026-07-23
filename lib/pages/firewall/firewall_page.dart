import 'package:flutter/material.dart';
import '../../core/context.dart';

enum FirewallType { ufw, firewalld, iptables }

class FirewallPage extends StatefulWidget {
  const FirewallPage({super.key});

  @override
  State<FirewallPage> createState() => _FirewallPageState();
}

class _FirewallPageState extends State<FirewallPage> {
  final _ctx = AppContext.i;

  FirewallType? _fwType;
  bool _enabled = false;
  List<_FwRule> _rules = [];
  bool _loading = true;
  String _firewalldZone = 'public';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─── Detection ───

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _fwType = await _detect();
      if (_fwType != null) {
        if (_fwType == FirewallType.ufw) {
          await _loadUfw();
        } else if (_fwType == FirewallType.firewalld) {
          await _loadFirewalld();
        } else {
          await _loadIptables();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<FirewallType?> _detect() async {
    // Priority: ufw > firewalld > iptables
    final r = await _ctx.exec(
      'if which ufw >/dev/null 2>&1; then echo "ufw"; '
      'elif which firewall-cmd >/dev/null 2>&1; then echo "firewalld"; '
      'elif which iptables >/dev/null 2>&1; then echo "iptables"; '
      'else echo "none"; fi',
    );
    final out = r.stdout.trim();
    return switch (out) {
      'ufw' => FirewallType.ufw,
      'firewalld' => FirewallType.firewalld,
      'iptables' => FirewallType.iptables,
      _ => null,
    };
  }

  // ─── UFW ───

  Future<void> _loadUfw() async {
    final r = await _ctx.exec('sudo ufw status numbered 2>/dev/null');
    final lines = r.stdout.split('\n');
    final enabled = lines.any((l) => l.contains('Status: active'));
    final rules = <_FwRule>[];
    for (final l in lines) {
      final m = RegExp(r'^\[\s*(\d+)\]\s+(.+)$').firstMatch(l.trim());
      if (m != null) rules.add(_FwRule(num: int.tryParse(m.group(1)!) ?? 0, text: m.group(2)!));
    }
    if (mounted) setState(() { _enabled = enabled; _rules = rules; });
  }

  Future<void> _addUfw(String input) async {
    await _ctx.exec('sudo ufw allow $input');
    await _loadUfw();
  }

  Future<void> _delUfw(int num) async {
    await _ctx.exec('sudo ufw --force delete $num');
    await _loadUfw();
  }

  // ─── firewalld ───

  Future<void> _loadFirewalld() async {
    // State
    final stateR = await _ctx.exec('sudo firewall-cmd --state 2>/dev/null');
    final enabled = stateR.stdout.contains('running');

    // Zone
    final zoneR = await _ctx.exec('sudo firewall-cmd --get-default-zone 2>/dev/null');
    final zone = zoneR.stdout.trim();
    if (zone.isNotEmpty) _firewalldZone = zone;

    // Rules
    final rules = <_FwRule>[];
    final r = await _ctx.exec('sudo firewall-cmd --list-all${zone.isNotEmpty ? ' --zone=$zone' : ''} 2>/dev/null');
    final lines = r.stdout.split('\n');
    bool inPorts = false;
    int idx = 0;
    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.startsWith('ports:')) { inPorts = true; continue; }
      if (inPorts && trimmed.isEmpty) break;
      if (inPorts && trimmed.isNotEmpty) {
        // Usually a line like "ports: 80/tcp 443/tcp"
        final parts = trimmed.split(RegExp(r'\s+'));
        for (final p in parts.where((p) => p.contains('/'))) {
          rules.add(_FwRule(num: ++idx, text: 'allow $p'));
        }
      }
    }
    if (mounted) setState(() { _enabled = enabled; _rules = rules; });
  }

  Future<void> _addFirewalld(String input) async {
    final zone = _firewalldZone;
    await _ctx.exec('sudo firewall-cmd --zone=$zone --add-port=$input --permanent 2>/dev/null');
    await _ctx.exec('sudo firewall-cmd --reload 2>/dev/null');
    await _loadFirewalld();
  }

  Future<void> _delFirewalld(int index) async {
    if (index <= 0 || index > _rules.length) return;
    final rule = _rules[index - 1];
    final port = RegExp(r'(\d+/tcp|\d+/udp)').firstMatch(rule.text)?.group(1);
    if (port == null) return;
    final zone = _firewalldZone;
    await _ctx.exec('sudo firewall-cmd --zone=$zone --remove-port=$port --permanent 2>/dev/null');
    await _ctx.exec('sudo firewall-cmd --reload 2>/dev/null');
    await _loadFirewalld();
  }

  // ─── iptables ───

  Future<void> _loadIptables() async {
    // Check if any rules exist (iptables is always "enabled" if running)
    final r = await _ctx.exec('sudo iptables -L INPUT -n --line-numbers 2>/dev/null');
    final lines = r.stdout.split('\n');
    final rules = <_FwRule>[];
    for (final l in lines) {
      final trimmed = l.trim();
      if (RegExp(r'^\d+').hasMatch(trimmed)) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          rules.add(_FwRule(
            num: int.tryParse(parts[0]) ?? rules.length + 1,
            text: trimmed.substring(parts[0].length).trim(),
          ));
        }
      }
    }
    // iptables doesn't have an enable/disable toggle — show as "active" if has rules
    if (mounted) setState(() { _enabled = true; _rules = rules; });
  }

  Future<void> _addIptables(String input) async {
    // input format: "80/tcp" or "443/udp"
    final parts = input.split('/');
    final port = parts[0];
    final proto = parts.length > 1 ? parts[1] : 'tcp';
    await _ctx.exec('sudo iptables -A INPUT -p $proto --dport $port -j ACCEPT');
    await _loadIptables();
  }

  Future<void> _delIptables(int num) async {
    await _ctx.exec('sudo iptables -D INPUT $num');
    await _loadIptables();
  }

  // ─── Toggle (ufw/firewalld only) ───

  Future<void> _toggle() async {
    if (_fwType == FirewallType.ufw) {
      await _ctx.exec(_enabled ? 'sudo ufw --force disable' : 'sudo ufw --force enable');
    } else if (_fwType == FirewallType.firewalld) {
      await _ctx.exec(_enabled
          ? 'sudo systemctl stop firewalld && sudo systemctl disable firewalld'
          : 'sudo systemctl enable firewalld && sudo systemctl start firewalld');
    }
    _load();
  }

  // ─── Add dialog ───

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final proto = ValueNotifier<String>('tcp');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: const Text('添加规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: _fwType == FirewallType.iptables ? '例: 443' : '例: 80/tcp',
                  border: const OutlineInputBorder(),
                  labelText: '端口',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('协议: '),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: proto,
                    builder: (_, v, __) => SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'tcp', label: Text('TCP')),
                        ButtonSegment(value: 'udp', label: Text('UDP')),
                      ],
                      selected: {v},
                      onSelectionChanged: (s) { proto.value = s.first; },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
          ],
        ),
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;

    final port = ctrl.text.trim();
    final pr = proto.value;

    if (_fwType == FirewallType.ufw) {
      await _addUfw('$port/$pr');
    } else if (_fwType == FirewallType.firewalld) {
      await _addFirewalld('$port/$pr');
    } else {
      await _addIptables('$port/$pr');
    }
    _load();
  }

  // ─── Delete ───

  Future<void> _delete(_FwRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('删除规则 "${rule.text}" ？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (_fwType == FirewallType.ufw) {
      _delUfw(rule.num);
    } else if (_fwType == FirewallType.firewalld) {
      final idx = _rules.indexOf(rule) + 1;
      _delFirewalld(idx);
    } else {
      _delIptables(rule.num);
    }
  }

  // ─── Build ───

  String get _fwLabel => switch (_fwType) {
    FirewallType.ufw => 'UFW',
    FirewallType.firewalld => 'firewalld',
    FirewallType.iptables => 'iptables',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('防火墙${_fwType != null ? ' ($_fwLabel)' : ''}'),
        actions: [
          if (_fwType != null) ...[
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            IconButton(icon: const Icon(Icons.add), onPressed: _add),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fwType == null
              ? _notInstalled(theme)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: [
                    if (_fwType != FirewallType.iptables)
                      Card(
                        child: SwitchListTile(
                          secondary: Icon(
                            _enabled ? Icons.shield : Icons.shield_outlined,
                            color: _enabled ? Colors.green : const Color(0xFF686F78),
                          ),
                          title: Text(
                            _fwType == FirewallType.firewalld
                                ? (_enabled ? 'firewalld 运行中' : 'firewalld 已停止')
                                : (_enabled ? '已启用' : '已禁用'),
                            style: TextStyle(fontWeight: FontWeight.w600, color: _enabled ? Colors.green : null),
                          ),
                          value: _enabled,
                          onChanged: (_) => _toggle(),
                        ),
                      ),
                    if (_fwType == FirewallType.iptables)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.info_outline, color: Colors.amber),
                          title: const Text('iptables 规则', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('无启/禁用开关，直接管理规则'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_rules.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('无规则', style: TextStyle(color: Color(0xFF686F78)))),
                        ),
                      ),
                    ..._rules.map((r) => _ruleCard(r, theme)),
                  ],
                ),
    );
  }

  Widget _ruleCard(_FwRule rule, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withAlpha(25),
          child: const Icon(Icons.check, color: Colors.green, size: 20),
        ),
        title: Text(rule.text, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () => _delete(rule),
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
          Text('未检测到防火墙', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('支持 UFW、firewalld、iptables\n请在服务器上安装其中之一',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF686F78))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
            child: const Column(
              children: [
                SelectableText('sudo apt install ufw -y          # UFW (推荐)',
                    style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13)),
                SelectableText('sudo apt install firewalld -y    # firewalld',
                    style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13)),
                SelectableText('sudo apt install iptables -y     # iptables',
                    style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _FwRule {
  final int num;
  final String text;
  const _FwRule({required this.num, required this.text});
}

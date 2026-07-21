import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/storage_service.dart';
import '../../models/ssh_config.dart';

class SshConfigPage extends ConsumerStatefulWidget {
  const SshConfigPage({super.key});

  @override
  ConsumerState<SshConfigPage> createState() => _SshConfigPageState();
}

class _SshConfigPageState extends ConsumerState<SshConfigPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _usePassword = true;
  bool _loading = false;
  String? _error;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final raw = await StorageService.instance.getSshConnections();
    if (raw != null && raw.isNotEmpty) {
      final first = raw.first;
      _hostCtrl.text = first['host']?.toString() ?? '';
      _portCtrl.text = first['port']?.toString() ?? '22';
      _userCtrl.text = first['username']?.toString() ?? 'root';
      final pwd = first['password']?.toString();
      final key = first['privateKey']?.toString();
      if (pwd != null && pwd.isNotEmpty) {
        _passCtrl.text = pwd;
        _usePassword = true;
      } else if (key != null && key.isNotEmpty) {
        _keyCtrl.text = key;
        _usePassword = false;
      }
    }
    if (_hostCtrl.text.isEmpty) {
      final host = await SshConnectionNotifier.detectServerHost();
      if (host != null && host.isNotEmpty) _hostCtrl.text = host;
    }
    // Check current connection status
    final svc = ref.read(sshServiceProvider);
    if (mounted) setState(() {});
  }

  void _addLog(String msg) {
    if (mounted) setState(() => _log.add(msg));
  }

  Future<void> _connect() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 22;
    final username = _userCtrl.text.trim();

    if (host.isEmpty) {
      setState(() => _error = '请输入主机地址');
      return;
    }

    setState(() { _loading = true; _error = null; _log.clear(); });
    _addLog('正在连接 $username@$host:$port ...');

    final config = SshConfig(
      host: host, port: port, username: username,
      password: _usePassword ? _passCtrl.text : null,
      privateKey: _usePassword ? null : _keyCtrl.text,
    );

    final err = await ref.read(sshConnectionProvider.notifier).connect(config);
    if (err != null) {
      _addLog('连接失败: $err');
      if (mounted) setState(() { _loading = false; _error = err; });
      return;
    }
    _addLog('SSH 连接建立，验证中...');

    // Verify connection with test command
    final svc = ref.read(sshServiceProvider);
    if (svc != null) {
      final r = await svc.execute('echo ok && hostname && uname -r');
      if (r.isSuccess) {
        _addLog('验证成功: ${r.stdout.trim().replaceAll('\n', ', ')}');
      } else {
        _addLog('验证失败: ${r.stderr}');
        if (mounted) setState(() { _loading = false; _error = '连接验证失败'; });
        return;
      }
    }

    _addLog('已连接');
    if (mounted) setState(() => _loading = false);
  }

  void _disconnect() {
    ref.read(sshConnectionProvider.notifier).disconnect();
    _addLog('已断开');
    setState(() {});
  }

  @override
  void dispose() {
    _hostCtrl.dispose(); _portCtrl.dispose(); _userCtrl.dispose();
    _passCtrl.dispose(); _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(sshConnectionProvider);
    final isConnected = conn.valueOrNull != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SSH 连接')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Status card
        Card(
          color: isConnected ? Colors.green.withAlpha(15) : (_error != null ? Colors.red.withAlpha(15) : Colors.grey.withAlpha(15)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(isConnected ? Icons.check_circle : (_error != null ? Icons.error : Icons.link_off),
                  color: isConnected ? Colors.green : (_error != null ? Colors.red : const Color(0xFF686F78)), size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isConnected ? '已连接' : (_error != null ? '连接失败' : '未配置'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              )),
              if (isConnected)
                TextButton(onPressed: _disconnect, child: const Text('断开', style: TextStyle(color: Colors.red))),
            ]),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.red.withAlpha(12),
            child: Padding(padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          ),
        ],
        const SizedBox(height: 12),
        // Form
        TextField(controller: _hostCtrl, decoration: const InputDecoration(labelText: '主机地址', hintText: '192.168.1.100', border: OutlineInputBorder(), prefixIcon: Icon(Icons.computer))),
        const SizedBox(height: 10),
        TextField(controller: _portCtrl, decoration: const InputDecoration(labelText: '端口', hintText: '22', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin)), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: '用户名', hintText: 'root', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('密码')), ButtonSegment(value: false, label: Text('私钥'))],
          selected: {_usePassword},
          onSelectionChanged: (s) => setState(() => _usePassword = s.first),
        ),
        const SizedBox(height: 10),
        if (_usePassword)
          TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)))
        else
          TextField(controller: _keyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '私钥(PEM内容或路径)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 46,
          child: FilledButton.icon(
            onPressed: _loading ? null : _connect,
            icon: _loading ? const SizedBox(width: 18,height:18,child: CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.link),
            label: Text(_loading ? '连接中...' : '连接'),
          ),
        ),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('连接日志', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...(_log.map((l) => Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF686F78), height: 1.5)))),
            ])),
          ),
        ],
        const SizedBox(height: 90),
      ]),
    );
  }
}

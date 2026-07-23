import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/storage_service.dart';
import '../../services/panel_api_service.dart';
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
  bool _verifying = false;
  String? _error;
  final _log = <String>[];

  // Panel API
  final _p1PortCtrl = TextEditingController();
  final _p1KeyCtrl = TextEditingController();
  final _btPortCtrl = TextEditingController();
  final _btKeyCtrl = TextEditingController();
  PanelCheckResult? _p1Check;
  PanelCheckResult? _btCheck;
  bool _checkingP1 = false;
  bool _checkingBt = false;

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
      // Load panel config
      _p1PortCtrl.text = first['panel1PanelPort']?.toString() ?? '';
      _p1KeyCtrl.text = first['panel1PanelApiKey']?.toString() ?? '';
      _btPortCtrl.text = first['panelBtPort']?.toString() ?? '';
      _btKeyCtrl.text = first['panelBtApiKey']?.toString() ?? '';
    }
    if (_hostCtrl.text.isEmpty) {
      final host = await SshConnectionNotifier.detectServerHost();
      if (host != null && host.isNotEmpty) _hostCtrl.text = host;
    }
    ref.read(sshServiceProvider);
    if (mounted) setState(() {});
  }

  void _addLog(String msg) {
    if (mounted) setState(() => _log.add(msg));
  }

  SshConfig _buildConfig() => SshConfig(
    host: _hostCtrl.text.trim(),
    port: int.tryParse(_portCtrl.text.trim()) ?? 22,
    username: _userCtrl.text.trim(),
    password: _usePassword ? _passCtrl.text : null,
    privateKey: _usePassword ? null : _keyCtrl.text,
    panel1PanelPort: _p1PortCtrl.text.trim().isEmpty ? null : _p1PortCtrl.text.trim(),
    panel1PanelApiKey: _p1KeyCtrl.text.trim().isEmpty ? null : _p1KeyCtrl.text.trim(),
    panelBtPort: _btPortCtrl.text.trim().isEmpty ? null : _btPortCtrl.text.trim(),
    panelBtApiKey: _btKeyCtrl.text.trim().isEmpty ? null : _btKeyCtrl.text.trim(),
  );

  Future<void> _connect() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = '请输入主机地址');
      return;
    }

    setState(() { _loading = true; _error = null; _log.clear(); });
    _addLog('正在连接 SSH...');

    final config = _buildConfig();
    final err = await ref.read(sshConnectionProvider.notifier).connect(config);
    if (err != null) {
      _addLog('SSH 失败: $err');
      if (mounted) setState(() { _loading = false; _error = err; });
      return;
    }
    _addLog('SSH 已连接');
    // Save panel config separately (SSH connect saves basic config)
    await StorageService.instance.saveSshConnections([config.toJson()]);

    // Verify
    if (mounted) setState(() => _verifying = true);
    final svc = ref.read(sshServiceProvider);
    if (svc != null) {
      final r = await svc.execute('echo ok && hostname && uname -r');
      if (r.isSuccess) {
        _addLog('验证通过: ${r.stdout.trim().replaceAll('\n', ', ')}');
      } else {
        _addLog('验证失败: ${r.stderr}');
        if (mounted) setState(() { _loading = false; _verifying = false; _error = '连接验证失败'; });
        ref.read(sshConnectionProvider.notifier).disconnect();
        return;
      }
    }
    _addLog('已连接');
    if (mounted) setState(() { _loading = false; _verifying = false; });
  }

  void _disconnect() {
    ref.read(sshConnectionProvider.notifier).disconnect();
    _addLog('已断开');
    setState(() {});
  }

  // ─── Panel connectivity checks ───

  Future<void> _check1Panel() async {
    setState(() { _checkingP1 = true; _p1Check = null; });
    final host = _hostCtrl.text.trim();
    final port = _p1PortCtrl.text.trim();
    final key = _p1KeyCtrl.text.trim();
    if (host.isEmpty || port.isEmpty || key.isEmpty) {
      setState(() { _checkingP1 = false; _p1Check = PanelCheckResult(success: false, msg: '请填写完整信息'); });
      return;
    }
    final r = await PanelApiService.check1Panel(host, int.tryParse(port) ?? 0, key);
    setState(() { _checkingP1 = false; _p1Check = r; });
  }

  Future<void> _checkBt() async {
    setState(() { _checkingBt = true; _btCheck = null; });
    final host = _hostCtrl.text.trim();
    final port = _btPortCtrl.text.trim();
    final key = _btKeyCtrl.text.trim();
    if (host.isEmpty || port.isEmpty || key.isEmpty) {
      setState(() { _checkingBt = false; _btCheck = PanelCheckResult(success: false, msg: '请填写完整信息'); });
      return;
    }
    final r = await PanelApiService.checkBt(host, int.tryParse(port) ?? 0, key);
    setState(() { _checkingBt = false; _btCheck = r; });
  }

  @override
  void dispose() {
    _hostCtrl.dispose(); _portCtrl.dispose(); _userCtrl.dispose();
    _passCtrl.dispose(); _keyCtrl.dispose();
    _p1PortCtrl.dispose(); _p1KeyCtrl.dispose();
    _btPortCtrl.dispose(); _btKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(sshConnectionProvider);
    final theme = Theme.of(context);
    final isConnected = conn.valueOrNull != null;

    String status; IconData statusIcon; Color statusColor;
    if (_loading) {
      status = '连接中...'; statusIcon = Icons.sync; statusColor = Colors.orange;
    } else if (_verifying) {
      status = '验证中...'; statusIcon = Icons.sync; statusColor = Colors.orange;
    } else if (isConnected) {
      status = '已连接'; statusIcon = Icons.check_circle; statusColor = Colors.green;
    } else if (_error != null) {
      status = '连接失败'; statusIcon = Icons.error; statusColor = Colors.red;
    } else {
      status = '未配置'; statusIcon = Icons.link_off; statusColor = const Color(0xFF686F78);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SSH 连接')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Status
        Card(
          color: statusColor.withAlpha(15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _loading || _verifying
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(status, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              if (isConnected)
                TextButton(onPressed: _disconnect, child: const Text('断开', style: TextStyle(color: Colors.red))),
            ]),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Card(color: Colors.red.withAlpha(12),
            child: Padding(padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          ),
        ],
        const SizedBox(height: 12),

        // ─── SSH Form ───
        TextField(controller: _hostCtrl, decoration: const InputDecoration(labelText: '主机地址', hintText: '192.168.1.100', border: OutlineInputBorder(), prefixIcon: Icon(Icons.computer))),
        const SizedBox(height: 10),
        TextField(controller: _portCtrl, decoration: const InputDecoration(labelText: 'SSH 端口', hintText: '22', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin)), keyboardType: TextInputType.number),
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

        const SizedBox(height: 24),

        // ─── Panel API (Optional) ───
        Text('面板 API (可选)', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFFAAB4BF))),
        const SizedBox(height: 8),
        // 1Panel
        _panelCard(
          label: '1Panel',
          portCtrl: _p1PortCtrl,
          keyCtrl: _p1KeyCtrl,
          checking: _checkingP1,
          result: _p1Check,
          onCheck: _check1Panel,
        ),
        const SizedBox(height: 8),
        // Baota
        _panelCard(
          label: '宝塔面板',
          portCtrl: _btPortCtrl,
          keyCtrl: _btKeyCtrl,
          checking: _checkingBt,
          result: _btCheck,
          onCheck: _checkBt,
        ),

        // Log
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('连接日志', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._log.map((l) => Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF686F78), height: 1.5))),
            ])),
          ),
        ],
        const SizedBox(height: 90),
      ]),
    );
  }

  Widget _panelCard({
    required String label,
    required TextEditingController portCtrl,
    required TextEditingController keyCtrl,
    required bool checking,
    required PanelCheckResult? result,
    required VoidCallback onCheck,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            if (checking) ...[
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 6),
              const Text('检测中...', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ] else if (result != null) ...[
              Icon(result.success ? Icons.check_circle : Icons.error, size: 16,
                  color: result.success ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Expanded(child: Text(result.msg, style: TextStyle(fontSize: 11, color: result.success ? Colors.green : Colors.red))),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: portCtrl,
                decoration: const InputDecoration(labelText: '端口', hintText: '自动检测', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder(), isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.wifi_find, size: 16),
              label: const Text('检测连通性', style: TextStyle(fontSize: 13)),
              onPressed: (portCtrl.text.isNotEmpty && keyCtrl.text.isNotEmpty && !checking) ? onCheck : null,
            ),
          ),
        ]),
      ),
    );
  }
}

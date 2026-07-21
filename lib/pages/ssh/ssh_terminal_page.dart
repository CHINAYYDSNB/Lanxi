import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../models/ssh_config.dart';
import '../../services/storage_service.dart';

class SshTerminalPage extends StatefulWidget {
  const SshTerminalPage({super.key});

  @override
  State<SshTerminalPage> createState() => _SshTerminalPageState();
}

class _SshTerminalPageState extends State<SshTerminalPage> {
  final _terminal = Terminal(maxLines: 5000);
  final _ctrl = TerminalController();
  SSHClient? _client;
  SSHSession? _session;
  bool _connected = false;
  String _status = '连接中...';

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = (data) {
      _session?.write(Uint8List.fromList(utf8.encode(data)));
    };
    _terminal.onResize = (w, h, pw, ph) {
      _session?.resizeTerminal(w, h, pw, ph);
    };
    _connect();
  }

  Future<void> _connect() async {
    try {
      final raw = await StorageService.instance.getSshConnections();
      if (raw == null || raw.isEmpty) {
        setState(() => _status = '请先在设置中配置SSH连接');
        return;
      }
      final first = raw.first;
      final config = SshConfig(
        host: first['host']?.toString() ?? '',
        port: int.tryParse(first['port']?.toString() ?? '') ?? 22,
        username: first['username']?.toString() ?? 'root',
        password: first['password']?.toString(),
        privateKey: first['privateKey']?.toString(),
        passphrase: first['passphrase']?.toString(),
      );

      final socket = await SSHSocket.connect(config.host, config.port,
          timeout: const Duration(seconds: 10));

      SSHClient client;
      if (config.privateKey != null && config.privateKey!.isNotEmpty) {
        try {
          final pairs = config.passphrase != null
              ? SSHKeyPair.fromPem(config.privateKey!, config.passphrase!)
              : SSHKeyPair.fromPem(config.privateKey!);
          client = SSHClient(socket, username: config.username,
              identities: pairs, onPasswordRequest: () => config.password ?? '');
        } catch (_) {
          client = SSHClient(socket, username: config.username,
              onPasswordRequest: () => config.password ?? '');
        }
      } else {
        client = SSHClient(socket, username: config.username,
            onPasswordRequest: () => config.password ?? '');
      }
      _client = client;

      final shell = await client.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );
      _session = shell;

      shell.stdout.listen((d) => _terminal.write(utf8.decode(d)));
      shell.stderr.listen((d) => _terminal.write(utf8.decode(d)));
      shell.done.then((_) {
        if (mounted) setState(() { _connected = false; _status = '会话已关闭'; });
      });

      if (mounted) setState(() { _connected = true; _status = '已连接'; });
    } catch (e) {
      if (mounted) setState(() => _status = '连接失败: $e');
    }
  }

  @override
  void dispose() {
    _session?.close();
    _client?.close();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH 终端'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _connected ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_status, style: TextStyle(fontSize: 12,
                color: _connected ? Colors.green : Colors.red)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { _session?.close(); _client?.close(); _connect(); },
          ),
          if (_connected) PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _terminal.buffer.clear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('清屏')),
            ],
          ),
        ],
      ),
      body: _connected
          ? TerminalView(_terminal, controller: _ctrl, autofocus: true)
          : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: Color(0xFF686F78))),
            ])),
    );
  }
}

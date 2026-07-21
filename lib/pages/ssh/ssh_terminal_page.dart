import 'dart:async';
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
  late TerminalController _ctrl;
  SSHClient? _client;
  SSHSession? _session;
  bool _connected = false;
  String _status = '连接中...';

  @override
  void initState() {
    super.initState();
    _ctrl = TerminalController(_terminal);
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

      shell.stdout.listen((d) => _terminal.write(d));
      shell.stderr.listen((d) => _terminal.write(d));
      shell.done.then((_) {
        if (mounted) setState(() { _connected = false; _status = '会话已关闭'; });
      });

      setState(() { _connected = true; _status = '已连接'; });
      _terminal.write('\x1b[32m=== Lanxi Terminal ===\x1b[0m\r\n');
      _terminal.write('Connected to ${config.host} as ${config.username}\r\n');
    } catch (e) {
      if (mounted) setState(() => _status = '连接失败: $e');
    }
  }

  void _onKey(KeyEvent event) {
    if (event is KeyKeyboardEvent && event.alt) {
      // Alt+key combinations
      final char = event.character;
      if (char != null) {
        _session?.write([0x1b, char.codeUnitAt(0)]);
        return;
      }
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
        ],
      ),
      body: _connected
          ? Column(children: [
              Expanded(
                child: TerminalView(
                  _terminal,
                  controller: _ctrl,
                  autofocus: true,
                  onSecondaryTapDown: (d) => _showMenu(d.globalPosition),
                  keyboardInput: (data) {
                    if (data == '\r') {
                      _session?.write([13]);
                    } else if (data.codeUnitAt(0) == 127) {
                      _session?.write([127]);
                    } else if (data.codeUnitAt(0) == 9) {
                      _session?.write([9]); // tab
                    } else if (data == '\x03') {
                      _session?.write([3]); // Ctrl+C
                    } else if (data == '\x04') {
                      _session?.write([4]); // Ctrl+D
                    } else {
                      _session?.write(data.codeUnits);
                    }
                  },
                ),
              ),
            ])
          : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: Color(0xFF686F78))),
            ])),
    );
  }

  void _showMenu(Offset pos) {
    showMenu(context: context, position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy), items: [
      const PopupMenuItem(value: 'paste', child: Text('粘贴')),
      const PopupMenuItem(value: 'clear', child: Text('清屏')),
    ]).then((v) {
      if (v == 'clear') _terminal.clear();
      if (v == 'paste') {
        // Clipboard paste via Ctrl+Shift+V or terminal's built-in
        _terminal.paste('\x1b[200~'); // bracketed paste start
      }
    });
  }
}

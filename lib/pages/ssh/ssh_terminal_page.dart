import 'package:flutter/material.dart';
import '../../core/context.dart';

class SshTerminalPage extends StatefulWidget {
  const SshTerminalPage({super.key});

  @override
  State<SshTerminalPage> createState() => _SshTerminalPageState();
}

class _SshTerminalPageState extends State<SshTerminalPage> {
  final _output = <String>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _ctx = AppContext.i;

  Future<void> _exec(String cmd) async {
    if (cmd.trim().isEmpty) return;
    setState(() => _output.add('\$ $cmd'));
    _input.clear();
    final r = await _ctx.exec(cmd);
    if (mounted) {
      setState(() {
        if (r.stdout.isNotEmpty) _output.add(r.stdout.trimRight());
        if (r.stderr.isNotEmpty) _output.add(r.stderr.trimRight());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 50), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSH')),
      body: Column(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: _output.isEmpty
                  ? const Center(child: Text('输入命令开始...', style: TextStyle(color: Colors.white24)))
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _output.length,
                      itemBuilder: (_, i) => Text(
                        _output[i],
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace',
                            color: Colors.greenAccent, height: 1.3),
                      ),
                    ),
            ),
          ),
        ),
        Container(
          color: const Color(0xFF1a1a1a),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '输入命令...',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                onSubmitted: _exec,
              ),
            ),
            IconButton(icon: const Icon(Icons.send, color: Colors.greenAccent), onPressed: () => _exec(_input.text)),
          ]),
        ),
      ]),
    );
  }
}

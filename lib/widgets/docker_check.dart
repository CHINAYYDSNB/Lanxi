import 'package:flutter/material.dart';
import '../core/context.dart';

class DockerCheck extends StatefulWidget {
  final Widget child;
  const DockerCheck({super.key, required this.child});

  @override
  State<DockerCheck> createState() => _DockerCheckState();
}

class _DockerCheckState extends State<DockerCheck> {
  bool? _has;
  bool _checking = true;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    if (!AppContext.i.isConnected) {
      setState(() { _has = null; _checking = false; });
      return;
    }
    final r = await AppContext.i.exec('docker --version 2>/dev/null');
    if (mounted) setState(() { _has = r.isSuccess; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Center(child: CircularProgressIndicator());
    if (_has == false) return _installGuide();
    if (_has == null) return const Center(child: Text('请先连接SSH', style: TextStyle(color: Color(0xFF686F78))));
    return widget.child;
  }

  Widget _installGuide() {
    return Center(
      child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.build_outlined, size: 56, color: Color(0xFFAAB4BF)),
        const SizedBox(height: 16),
        const Text('Docker 未安装', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('在服务器上运行:', style: TextStyle(color: Color(0xFF686F78))),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: const Text('curl -fsSL https://get.docker.com | sh',
              style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('重新检测'),
          onPressed: () { setState(() => _checking = true); _check(); },
        ),
      ])),
    );
  }
}

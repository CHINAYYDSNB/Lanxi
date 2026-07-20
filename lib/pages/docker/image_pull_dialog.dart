import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/context.dart';

Future<void> showImagePullDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        StreamSubscription<String>? _sub;
        final _lines = <String>[];
        bool _pulling = false;
        bool _done = false;
        String? _error;

        void _pull() {
          final image = ctrl.text.trim();
          if (image.isEmpty) return;
          setState(() { _pulling = true; _lines.clear(); });
          _sub = AppContext.i.stream('docker pull $image').listen(
            (d) => setState(() => _lines.add(d)),
            onError: (e) => setState(() { _error = e.toString(); _pulling = false; }),
            onDone: () => setState(() { _done = true; _pulling = false; }),
          );
        }

        void _close() { _sub?.cancel(); Navigator.pop(ctx); }

        return AlertDialog(
          title: Text(_pulling ? '拉取中...' : (_done ? '完成' : '拉取镜像')),
          content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!_pulling && !_done) TextField(
                controller: ctrl, autofocus: true,
                decoration: const InputDecoration(hintText: 'nginx:latest or repo/image:tag', border: OutlineInputBorder()),
                onSubmitted: (_) => _pull(),
              ),
              if (_pulling || _done || _error != null)
                Container(
                  height: 200, padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                  child: _error != null
                      ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'monospace'))
                      : ListView(children: _lines.map((l) => Text(l, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace', height: 1.3))).toList()),
                ),
            ]),
          ),
          actions: [
            if (!_pulling) TextButton(onPressed: _close, child: const Text('关闭')),
            if (!_pulling && !_done)
              FilledButton(onPressed: _pull, child: const Text('拉取')),
          ],
        );
      },
    ),
  );
}

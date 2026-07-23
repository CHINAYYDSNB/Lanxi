import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/context.dart';

Future<void> showImagePullDialog(BuildContext context, {VoidCallback? onPulled}) {
  final imageCtrl = TextEditingController();
  final registryCtrl = TextEditingController(text: 'docker.io');
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showAuth = false;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        StreamSubscription<String>? sub;
        final lines = <String>[];
        bool pulling = false;
        bool done = false;
        String? pullError;

        Future<void> doPull() async {
          final image = imageCtrl.text.trim();
          if (image.isEmpty) return;

          final registry = registryCtrl.text.trim();
          final user = userCtrl.text.trim();
          final pass = passCtrl.text.trim();
          final needAuth = user.isNotEmpty;

          setDialogState(() { pulling = true; lines.clear(); pullError = null; });

          // Login if credentials provided
          if (needAuth) {
            lines.add('\$ docker login $registry -u $user ***');
            try {
              final loginR = await AppContext.i.exec(
                'docker login $registry -u "$user" -p "$pass"',
                timeout: const Duration(seconds: 15),
              );
              if (!loginR.isSuccess) {
                lines.add('Login failed: ${loginR.stderr}');
                setDialogState(() { pulling = false; pullError = loginR.stderr; });
                return;
              }
              lines.add('Login succeeded');
            } catch (e) {
              lines.add('Login error: $e');
              setDialogState(() { pulling = false; pullError = e.toString(); });
              return;
            }
          }

          // Pull image
          lines.add('\$ docker pull $image');
          final pullCmd = registry == 'docker.io' || registry.isEmpty
              ? 'docker pull $image'
              : 'docker pull $registry/$image';

          sub = AppContext.i.stream(pullCmd).listen(
            (d) => setDialogState(() => lines.add(d)),
            onError: (e) => setDialogState(() { pullError = e.toString(); pulling = false; }),
            onDone: () async {
              setDialogState(() { done = true; pulling = false; });
              onPulled?.call();
              // Logout if we logged in
              if (needAuth) {
                try {
                  await AppContext.i.exec('docker logout $registry');
                } catch (_) {}
              }
            },
          );
        }

        void doClose() {
          sub?.cancel();
          Navigator.pop(ctx);
        }

        return AlertDialog(
          title: Text(pulling ? '拉取中...' : (done ? '拉取完成' : '拉取镜像')),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form (hidden during/after pull)
                  if (!pulling && !done) ...[
                    TextField(
                      controller: imageCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '镜像名',
                        hintText: 'nginx:latest or myapp:v1.0',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => doPull(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: registryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Registry',
                        hintText: 'docker.io',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: Icon(showAuth ? Icons.expand_less : Icons.expand_more, size: 18),
                          label: Text(showAuth ? '隐藏认证' : '私有仓库认证'),
                          onPressed: () => setDialogState(() => showAuth = !showAuth),
                        ),
                      ],
                    ),
                    if (showAuth) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                  // Terminal output
                  if (pulling || done || pullError != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      height: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: pullError != null
                          ? SingleChildScrollView(
                              child: Text(
                                pullError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace'),
                              ),
                            )
                          : ListView(
                              children: lines
                                  .where((l) => l.trim().isNotEmpty)
                                  .map((l) => Text(
                                        l,
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace', height: 1.35),
                                      ))
                                  .toList(),
                            ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (!pulling) TextButton(onPressed: doClose, child: const Text('关闭')),
            if (!pulling && !done)
              FilledButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('拉取'),
                onPressed: doPull,
              ),
          ],
        );
      },
    ),
  );
}

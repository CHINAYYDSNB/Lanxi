import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/installed_app_provider.dart';
import '../../api/installed_app_api.dart';
import '../../api/file_api.dart';
import '../../models/installed_app.dart';

class InstalledDetailPage extends ConsumerStatefulWidget {
  final int installId;
  final String appName;

  const InstalledDetailPage({
    super.key,
    required this.installId,
    required this.appName,
  });

  @override
  ConsumerState<InstalledDetailPage> createState() => _InstalledDetailPageState();
}

class _InstalledDetailPageState extends ConsumerState<InstalledDetailPage> {
  bool _updating = false;
  final _composeCtrl = TextEditingController();

  @override
  void dispose() {
    _composeCtrl.dispose();
    super.dispose();
  }

  Future<void> _editCompose(String path) async {
    try {
      final file = await FileApi.getContent(path);
      if (!mounted) return;
      _composeCtrl.text = file.content ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取 Compose 失败: $e')));
      }
      return;
    }
    if (!mounted) return;

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑 Docker Compose'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: _composeCtrl,
            maxLines: 20,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, _composeCtrl.text), child: const Text('保存')),
        ],
      ),
    );
    if (saved == null || !mounted) return;

    try {
      await FileApi.save(path, saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compose 已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Future<void> _checkAndUpdate(InstalledAppDetail app) async {
    List<String> versions;
    try {
      versions = await InstalledAppApi.getUpdateVersions(widget.installId);
    } catch (e) {
      // 单容器用 operate upgrade
      if (mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('升级'),
            content: Text('将 ${app.name} 升级到最新版本?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('升级')),
            ],
          ),
        );
        if (ok == true && mounted) {
          setState(() => _updating = true);
          try {
            await InstalledAppApi.operate(widget.installId, 'upgrade');
            if (mounted) {
              ref.invalidate(installedAppDetailProvider(widget.installId));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('升级成功')));
            }
          } catch (err) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('升级失败: $err')));
          } finally {
            if (mounted) setState(() => _updating = false);
          }
        }
      }
      return;
    }

    if (versions.isEmpty || !mounted) return;
    final selectedVersion = versions.first;

    // 版本选择 + compose 编辑
    final composeCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('更新应用'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${app.name} 可从 v${app.version} 升级到 v$selectedVersion',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                const Text('Docker Compose 配置', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: composeCtrl,
                  maxLines: 15,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('更新')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updating = true);
    try {
      // 升级并更新配置
      await InstalledAppApi.operate(widget.installId, 'upgrade');
      // 如果有新的 compose, 写到原路径
      if (composeCtrl.text.trim().isNotEmpty && app.composePath.isNotEmpty) {
        await FileApi.save(app.composePath, composeCtrl.text.trim());
      }
      if (mounted) {
        ref.invalidate(installedAppDetailProvider(widget.installId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新成功')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(installedAppDetailProvider(widget.installId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.appName)),
      body: detail.when(
        data: (app) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Container(width: 12, height: 12,
                decoration: BoxDecoration(color: app.isRunning ? Colors.green : Colors.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(app.statusLabel, style: theme.textTheme.titleMedium),
              const Spacer(),
              Text('v${app.version}', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              if (app.updateAvailable) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(app.latestVersion != null ? 'v${app.latestVersion} 可用' : '可更新',
                      style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            _InfoSection(title: '基本信息', children: [
              _InfoRow(label: '应用名称', value: app.name),
              _InfoRow(label: '应用 Key', value: app.appKey),
              _InfoRow(label: '当前版本', value: app.version),
              if (app.httpPort > 0) _InfoRow(label: 'HTTP 端口', value: app.httpPort.toString()),
              if (app.container.isNotEmpty) _InfoRow(label: '容器名称', value: app.container),
            ]),
            if (app.composePath.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoSection(title: 'Compose 文件', children: [
                _InfoRow(label: '路径', value: app.composePath),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _editCompose(app.composePath),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('编辑 Compose'),
                )),
              ]),
            ],
            if (app.env.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoSection(title: '环境变量 (${app.env.length})', children: [
                ...app.env.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 140, child: Text('${e.key}:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
                    Expanded(child: Text(e.value, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'))),
                  ]),
                )),
              ]),
            ],
            const SizedBox(height: 24),
            if (app.updateAvailable)
              SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(
                onPressed: _updating ? null : () => _checkAndUpdate(app),
                icon: _updating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.system_update),
                label: Text(_updating ? '更新中...' : '检查更新'),
              )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          Text('加载失败: $e'),
          FilledButton.icon(
            onPressed: () => ref.invalidate(installedAppDetailProvider(widget.installId)),
            icon: const Icon(Icons.refresh), label: const Text('重试'),
          ),
        ])),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title; final List<Widget> children;
  const _InfoSection({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title, style: Theme.of(context).textTheme.titleSmall), const Divider(), ...children],
    )));
  }
}

class _InfoRow extends StatelessWidget {
  final String label; final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ));
  }
}

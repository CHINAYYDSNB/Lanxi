import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_store_provider.dart';
import '../../api/app_store_api.dart';
import '../../api/installed_app_api.dart';
import '../../models/app_store_item.dart';

class AppDetailPage extends ConsumerStatefulWidget {
  final String appKey;
  final String appName;

  const AppDetailPage({
    super.key,
    required this.appKey,
    required this.appName,
  });

  @override
  ConsumerState<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends ConsumerState<AppDetailPage> {
  bool _installing = false;
  String _selectedVersion = '';
  final _composeCtrl = TextEditingController();
  bool _loadingCompose = false;

  @override
  void dispose() {
    _composeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompose(String version) async {
    setState(() => _loadingCompose = true);
    final compose = await AppStoreApi.fetchCompose(widget.appKey, version);
    if (mounted) {
      setState(() => _loadingCompose = false);
      if (compose != null && compose.isNotEmpty) {
        _composeCtrl.text = compose;
      } else if (_composeCtrl.text.isEmpty) {
        _composeCtrl.text = '# ${widget.appName}\n'
            'version: "3"\n'
            'services:\n'
            '  app:\n'
            '    image: ${widget.appKey}:latest\n'
            '    restart: always\n'
            '    ports:\n'
            '      - "8080:80"\n'
            '    environment:\n'
            '      - TZ=Asia/Shanghai\n';
      }
    }
  }

  Future<void> _startInstall(AppDetail app) async {
    final version = _selectedVersion.isNotEmpty ? _selectedVersion : (app.versions.isNotEmpty ? app.versions.first : '');

    // 先加载默认 compose
    await _loadCompose(version);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('安装应用'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('应用: ${app.name}', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: version,
                    decoration: const InputDecoration(labelText: '版本', border: OutlineInputBorder(), isDense: true),
                    items: app.versions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) {
                      setDlgState(() => _selectedVersion = v ?? '');
                      _loadCompose(v ?? '');
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Docker Compose 配置',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_loadingCompose)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _composeCtrl,
                    decoration: const InputDecoration(
                      hintText: '# docker-compose.yml',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 15,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始安装')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _installing = true);
    try {
      Map<String, String> params = {};
      if (_composeCtrl.text.trim().isNotEmpty) {
        params['docker_compose'] = _composeCtrl.text.trim();
      }
      await InstalledAppApi.install(
        key: app.key,
        name: app.name,
        version: version,
        params: params,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${app.name} 安装成功')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('安装失败: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(appDetailProvider(widget.appKey));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.appName)),
      body: detail.when(
        data: (app) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.apps, size: 28, color: colorScheme.onPrimaryContainer)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                if (app.shortDescZh.isNotEmpty)
                  Text(app.shortDescZh, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ])),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(label: '类型: ${app.type}'),
              _Chip(label: '架构: ${app.architectures.isNotEmpty ? app.architectures : "通用"}'),
              if (app.memoryRequired > 0) _Chip(label: '内存: ≥${app.memoryRequired}MB'),
              if (app.versions.isNotEmpty) _Chip(label: '最新: ${app.versions.first}'),
            ]),
            const SizedBox(height: 16),
            if (app.description.isNotEmpty) ...[
              Text('简介', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8), Text(app.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
            if (app.website.isNotEmpty || app.github.isNotEmpty || app.document.isNotEmpty) ...[
              Text('链接', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (app.website.isNotEmpty) _LinkRow(icon: Icons.language, label: '官网', url: app.website),
              if (app.github.isNotEmpty) _LinkRow(icon: Icons.code, label: 'GitHub', url: app.github),
              if (app.document.isNotEmpty) _LinkRow(icon: Icons.description, label: '文档', url: app.document),
              const SizedBox(height: 16),
            ],
            Text('可用版本', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (app.versions.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6,
                children: app.versions.take(10).map((v) => Chip(
                  label: Text(v, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(
              onPressed: _installing ? null : () => _startInstall(app),
              icon: _installing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              label: Text(_installing ? '安装中...' : '安装应用'),
            )),
            const SizedBox(height: 16),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败: $e', style: theme.textTheme.bodySmall),
          FilledButton.icon(
            onPressed: () => ref.invalidate(appDetailProvider(widget.appKey)),
            icon: const Icon(Icons.refresh), label: const Text('重试'),
          ),
        ])),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon; final String label; final String url;
  const _LinkRow({required this.icon, required this.label, required this.url});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 8),
        Expanded(child: Text(url, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
      ],
    ));
  }
}

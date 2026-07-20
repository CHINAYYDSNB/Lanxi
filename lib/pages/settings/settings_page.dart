import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../services/update_service.dart';
import 'ssh_config_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(settingsProvider.select((s) => s.isConnected));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Card(
            child: Column(children: [
              _Row(icon: Icons.terminal, title: 'SSH 连接', subtitle: '配置服务器地址与认证',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SshConfigPage())),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.wifi_find_outlined, size: 22, color: const Color(0xFF0C1014)),
                const SizedBox(width: 14),
                Expanded(child: Text('连接状态', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: connected ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(connected ? '已连接' : '未连接',
                    style: TextStyle(fontSize: 12, color: connected ? Colors.green : const Color(0xFF686F78))),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.info_outline, size: 22, color: const Color(0xFF0C1014)),
                const SizedBox(width: 14),
                Expanded(child: Text('Lanxi', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                Text(UpdateService.currentVersion, style: const TextStyle(fontSize: 13, color: Color(0xFF686F78))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: const Color(0xFF0C1014)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF686F78))),
          ])),
          const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dashboard/dashboard_page.dart';
import 'docker/container_list_page.dart';
import 'docker/image_list_page.dart';
import 'docker/compose_list_page.dart';
import 'docker/volume_list_page.dart';
import 'docker/network_list_page.dart';
import 'docker/docker_settings_page.dart';
import 'file/file_list_page.dart';
import 'ssh/ssh_terminal_page.dart';
import 'system/cron_page.dart';
import 'system/monitor_page.dart';
import 'database/database_page.dart';
import 'firewall/firewall_page.dart';
import 'settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _idx = 0;
  static const _pages = [
    DashboardPage(),
    ResourcePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '概览'),
          NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: '资源'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class ResourcePage extends StatelessWidget {
  const ResourcePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资源')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
        _Section('Docker'),
        _Row(icon: Icons.view_in_ar_outlined, color: Colors.teal,
          title: '容器', subtitle: '启动/停止/日志/删除',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerListPage())),
        ),
        _Row(icon: Icons.image_outlined, color: Colors.blue,
          title: '镜像', subtitle: '拉取/删除/清理',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageListPage())),
        ),
        _Row(icon: Icons.dns_outlined, color: Colors.indigo,
          title: 'Compose', subtitle: '编排/启停',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComposeListPage())),
        ),
        _Row(icon: Icons.storage, color: Colors.teal,
          title: '数据卷', subtitle: 'Volume 管理',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolumeListPage())),
        ),
        _Row(icon: Icons.hub, color: Colors.purple,
          title: '网络', subtitle: 'Network 管理',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkListPage())),
        ),
        _Row(icon: Icons.tune, color: const Color(0xFF686F78),
          title: 'Docker 设置', subtitle: '镜像仓库 / 配置',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DockerSettingsPage())),
        ),
        const SizedBox(height: 10),
        _Section('监控'),
        _Row(icon: Icons.analytics_outlined, color: Colors.blue,
          title: '服务器监控', subtitle: 'CPU / 内存 / IO / 网络 (面板API)',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonitorPage())),
        ),
        const SizedBox(height: 10),
        _Section('系统工具'),
        _Row(icon: Icons.folder, color: Colors.amber,
          title: '文件管理', subtitle: '浏览/编辑/删除',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileListPage())),
        ),
        _Row(icon: Icons.terminal, color: Colors.green,
          title: 'SSH 终端', subtitle: '远程命令行',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SshTerminalPage())),
        ),
        _Row(icon: Icons.schedule, color: Colors.teal,
          title: '计划任务', subtitle: 'Crontab 管理',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CronPage())),
        ),
        _Row(icon: Icons.shield_outlined, color: Colors.red,
          title: '防火墙', subtitle: 'UFW / firewalld / iptables',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirewallPage())),
        ),
        _Row(icon: Icons.storage_outlined, color: Colors.blueGrey,
          title: '数据库管理', subtitle: 'MySQL / PgSQL / MongoDB / Redis',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DatabasePage())),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFAAB4BF))),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        onTap: onTap,
      ),
    );
  }
}

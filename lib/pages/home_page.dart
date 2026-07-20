import 'package:flutter/material.dart';
import 'dashboard/dashboard_page.dart';
import 'docker/container_list_page.dart';
import 'docker/image_list_page.dart';
import 'docker/compose_list_page.dart';
import 'file/file_list_page.dart';
import 'ssh/ssh_terminal_page.dart';
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
          NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: 'Docker'),
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
      appBar: AppBar(title: const Text('Docker')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          _ResourceRow(icon: Icons.view_in_ar_outlined, color: Colors.teal,
            title: '容器', subtitle: '启动/停止/日志/删除',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerListPage())),
          ),
          _ResourceRow(icon: Icons.image_outlined, color: Colors.blue,
            title: '镜像', subtitle: '拉取/删除/清理',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageListPage())),
          ),
          _ResourceRow(icon: Icons.dns_outlined, color: Colors.indigo,
            title: 'Compose', subtitle: '编排/启停',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComposeListPage())),
          ),
          const SizedBox(height: 10),
          Text('系统工具', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFAAB4BF))),
          const SizedBox(height: 8),
          _ResourceRow(icon: Icons.folder, color: Colors.amber,
            title: '文件管理', subtitle: '浏览/编辑/删除',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileListPage())),
          ),
          _ResourceRow(icon: Icons.terminal, color: Colors.green,
            title: 'SSH 终端', subtitle: '远程命令行',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SshTerminalPage())),
          ),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ResourceRow({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        onTap: onTap,
      ),
    );
  }
}

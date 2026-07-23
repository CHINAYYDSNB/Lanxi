import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key});

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  List<DbInstance> _instances = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() { _loading = true; _error = null; });
    try {
      _instances = await DatabaseService.detectAll();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scan),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFF686F78))),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _scan, child: const Text('重试')),
                ]))
              : _instances.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.storage_outlined, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('未检测到数据库实例', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('支持识别 MySQL / PostgreSQL / MongoDB / Redis\n包括 Docker 容器内的实例',
                          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF686F78))),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重新检测'),
                        onPressed: _scan,
                      ),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: _instances.length,
                      itemBuilder: (_, i) => _instanceCard(_instances[i], theme),
                    ),
    );
  }

  Widget _instanceCard(DbInstance inst, ThemeData theme) {
    final icon = switch (inst.type) {
      DbType.mysql => Icons.storage,
      DbType.postgresql => Icons.storage,
      DbType.mongodb => Icons.storage,
      DbType.redis => Icons.memory,
    };
    final color = switch (inst.type) {
      DbType.mysql => Colors.blue,
      DbType.postgresql => Colors.indigo,
      DbType.mongodb => Colors.green,
      DbType.redis => Colors.red,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
        title: Text(inst.type.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text([
          if (inst.version != null) 'v${inst.version}',
          if (inst.inDocker) 'Docker',
          if (inst.containerName != null) inst.containerName!,
          if (inst.status != null) inst.status!,
        ].join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _InstanceDetailPage(instance: inst))),
      ),
    );
  }
}

// ─── Instance Detail Page ───

class _InstanceDetailPage extends StatefulWidget {
  final DbInstance instance;
  const _InstanceDetailPage({required this.instance});

  @override
  State<_InstanceDetailPage> createState() => _InstanceDetailPageState();
}

class _InstanceDetailPageState extends State<_InstanceDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<DbDatabase> _dbs = [];
  List<DbUser> _users = [];
  String? _connInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseService.listDatabases(widget.instance),
      DatabaseService.listUsers(widget.instance),
      DatabaseService.getConnectionInfo(widget.instance),
    ]);
    if (mounted) {
      setState(() {
        _dbs = results[0] as List<DbDatabase>;
        _users = results[1] as List<DbUser>;
        _connInfo = results[2] as String?;
        _loading = false;
      });
    }
  }

  Future<void> _addDatabase() async {
    final ctrl = TextEditingController();
    final ok = await _inputDialog('添加数据库', '数据库名', ctrl);
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final err = await DatabaseService.createDatabase(widget.instance, ctrl.text.trim());
      if (mounted) {
        if (err.isNotEmpty) _snack('创建失败: $err');
        _load();
      }
    }
  }

  Future<void> _deleteDatabase(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除数据库'),
        content: Text('确定要删除数据库 "$name" 吗？\n此操作不可逆！'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      final err = await DatabaseService.deleteDatabase(widget.instance, name);
      if (mounted) {
        if (err.isNotEmpty) _snack('删除失败: $err');
        _load();
      }
    }
  }

  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加用户'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
      final err = await DatabaseService.createUser(widget.instance, nameCtrl.text.trim(), passCtrl.text);
      if (mounted) {
        if (err.isNotEmpty) _snack('创建失败: $err');
        _load();
      }
    }
  }

  Future<void> _deleteUser(DbUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('删除用户 "${user.name}" ？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      final err = await DatabaseService.deleteUser(widget.instance, user.name, host: user.host ?? '%');
      if (mounted) {
        if (err.isNotEmpty) _snack('删除失败: $err');
        _load();
      }
    }
  }

  Future<void> _changePassword(DbUser user) async {
    final ctrl = TextEditingController();
    final ok = await _inputDialog('修改密码', '${user.name} 的新密码', ctrl, isPassword: true);
    if (ok == true && ctrl.text.isNotEmpty) {
      final err = await DatabaseService.changePassword(widget.instance, user.name, ctrl.text, host: user.host ?? '%');
      if (mounted) {
        _snack(err.isEmpty ? '密码已修改' : '失败: $err');
        _load();
      }
    }
  }

  Future<void> _grantPrivileges(DbUser user) async {
    if (_dbs.isEmpty) { _snack('没有可用的数据库'); return; }
    final db = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择数据库'),
        children: _dbs.map((d) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, d.name),
          child: Text(d.name),
        )).toList(),
      ),
    );
    if (db != null) {
      final err = await DatabaseService.grantPrivileges(widget.instance, user.name, db, host: user.host ?? '%');
      if (mounted) _snack(err.isEmpty ? '权限已授予 ($db)' : '失败: $err');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<bool?> _inputDialog(String title, String hint, TextEditingController ctrl, {bool isPassword = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, obscureText: isPassword, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inst = widget.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('${inst.type.label}${inst.inDocker ? ' (Docker)' : ''}'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '数据库'),
            Tab(text: '用户'),
            Tab(text: '连接'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                // Databases tab
                _dbs.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('无数据库', style: TextStyle(color: Color(0xFF686F78))),
                        if (inst.type != DbType.redis) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加数据库'),
                            onPressed: _addDatabase,
                          ),
                        ],
                      ]))
                    : Column(children: [
                        if (inst.type != DbType.redis)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('添加数据库'),
                              onPressed: _addDatabase,
                            )),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _dbs.length,
                            itemBuilder: (_, i) {
                              final d = _dbs[i];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.table_chart, color: Colors.teal),
                                  title: Text(d.name, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                                  trailing: inst.type != DbType.redis
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () => _deleteDatabase(d.name),
                                        )
                                      : null,
                                ),
                              );
                            }),
                        ),
                      ]),
                // Users tab
                _users.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('无用户数据', style: TextStyle(color: Color(0xFF686F78))),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('添加用户'),
                          onPressed: _addUser,
                        ),
                      ]))
                    : Column(children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('添加用户'),
                            onPressed: _addUser,
                          )),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _users.length,
                            itemBuilder: (_, i) {
                              final u = _users[i];
                              return Card(
                                child: ExpansionTile(
                                  leading: const Icon(Icons.person, color: Colors.blue),
                                  title: Text(u.name, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                                  subtitle: u.host != null ? Text('@${u.host}', style: const TextStyle(fontSize: 11, color: Color(0xFF686F78))) : null,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.lock, size: 18),
                                      title: const Text('修改密码', style: TextStyle(fontSize: 13)),
                                      onTap: () => _changePassword(u),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.admin_panel_settings, size: 18),
                                      title: const Text('授予权限', style: TextStyle(fontSize: 13)),
                                      onTap: () => _grantPrivileges(u),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      title: const Text('删除用户', style: TextStyle(fontSize: 13, color: Colors.red)),
                                      onTap: () => _deleteUser(u),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ),
                      ]),
                // Connection info tab
                ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('连接信息', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                          child: SelectableText(
                            _connInfo?.isNotEmpty == true ? _connInfo! : '无法获取连接信息',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('基本信息', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _infoRow('类型', inst.type.label),
                        _infoRow('版本', inst.version ?? '未知'),
                        _infoRow('部署方式', inst.inDocker ? 'Docker (${inst.containerName ?? ""})' : '宿主机'),
                        _infoRow('端口', inst.port?.toString() ?? inst.defaultPort),
                        _infoRow('状态', inst.status ?? '未知'),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF686F78)))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

import 'package:flutter/material.dart';
import '../../core/context.dart';

class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  String _path = '/';
  List<_FileEntry> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await AppContext.i.exec("ls -la --time-style=long-iso '$_path'");
      if (r.isSuccess) {
        _items = _parse(r.stdout);
      } else {
        _error = r.stderr;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_FileEntry> _parse(String raw) {
    final items = <_FileEntry>[];
    for (final l in raw.split('\n')) {
      final line = l.trim();
      if (line.isEmpty || line.startsWith('total ')) continue;
      final p = line.split(RegExp(r'\s+'));
      if (p.length < 8) continue;
      final perms = p[0];
      final name = p.sublist(7).join(' ');
      if (name == '.' || name == '..') continue;
      items.add(_FileEntry(
        name: name,
        isDir: perms[0] == 'd',
        isLink: perms[0] == 'l',
        size: int.tryParse(p[4]) ?? 0,
        date: '${p[5]} ${p[6]}',
        perms: perms.substring(1),
      ));
    }
    items.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  void _navigate(String dir) {
    setState(() {
      if (dir == '..') {
        if (_path == '/') return;
        _path = _path.substring(0, _path.lastIndexOf('/'));
        if (_path.isEmpty) _path = '/';
      } else {
        _path = _path == '/' ? '/$dir' : '$_path/$dir';
      }
    });
    _load();
  }

  void _goHome() { _path = '/'; _load(); }
  Future<void> _delete(_FileEntry f) async {
    final flag = f.isDir ? '-rf' : '-f';
    await AppContext.i.exec("rm $flag '$_path/${f.name}'");
    _load();
  }

  Future<void> _mkdir() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建目录'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '目录名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await AppContext.i.exec("mkdir -p '$_path/$name'");
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_path, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
        actions: [
          IconButton(icon: const Icon(Icons.home), onPressed: _goHome),
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: _mkdir),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _load, child: const Text('重试')),
                ]))
              : Column(children: [
                  if (_path != '/')
                    ListTile(
                      leading: const Icon(Icons.arrow_upward),
                      title: const Text('..'),
                      onTap: () => _navigate('..'),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final f = _items[i];
                        return ListTile(
                          leading: Icon(f.isDir ? Icons.folder : Icons.insert_drive_file_outlined,
                              color: f.isDir ? Colors.amber : null),
                          title: Text(f.name),
                          subtitle: Text('${f.perms}  ${f.size}  ${f.date}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          onTap: f.isDir ? () => _navigate(f.name) : () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => FileEditorPage(path: '$_path/${f.name}'))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _delete(f),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}

class _FileEntry {
  final String name, date, perms;
  final bool isDir, isLink;
  final int size;
  _FileEntry({required this.name, required this.isDir, required this.isLink, required this.size, required this.date, required this.perms});
}

class FileEditorPage extends StatefulWidget {
  final String path;
  const FileEditorPage({super.key, required this.path});

  @override
  State<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends State<FileEditorPage> {
  late TextEditingController _ctrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AppContext.i.exec("cat '${widget.path}'");
      if (r.isSuccess) _ctrl.text = r.stdout;
      else _error = r.stderr;
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final content = _ctrl.text.replaceAll("'", "'\\''");
    await AppContext.i.exec("echo '$content' > '${widget.path}'");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path.split('/').last),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
    );
  }
}

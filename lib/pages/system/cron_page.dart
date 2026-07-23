import 'package:flutter/material.dart';
import '../../core/context.dart';

class CronPage extends StatefulWidget {
  const CronPage({super.key});

  @override
  State<CronPage> createState() => _CronPageState();
}

class _CronPageState extends State<CronPage> {
  List<CronEntry> _entries = [];
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
      final r = await AppContext.i.exec('crontab -l');
      if (r.exitCode == 0) {
        _entries = CronEntry.parseMulti(r.stdout);
      } else if (r.stdout.contains('no crontab') || r.stderr.contains('no crontab')) {
        _entries = [];
      } else {
        _error = r.stderr.isNotEmpty ? r.stderr : r.stdout;
        if (_error!.isEmpty || _error == 'null') _error = null;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final lines = _entries.map((e) => e.toLine()).join('\n');
    final r = await AppContext.i.exec('echo \'${lines.replaceAll("'", "'\\''")}\' | crontab -');
    if (r.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crontab 已保存'), duration: Duration(seconds: 1)),
        );
      }
      _load();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${r.stderr}')),
        );
      }
    }
  }

  Future<void> _addOrEdit({CronEntry? existing}) async {
    final result = await showDialog<CronEntry>(
      context: context,
      builder: (ctx) => _CronEditDialog(entry: existing),
    );
    if (result != null) {
      if (existing != null) {
        final idx = _entries.indexOf(existing);
        if (idx >= 0) _entries[idx] = result;
      } else {
        _entries.add(result);
      }
      _save();
    }
  }

  Future<void> _delete(int index) async {
    final e = _entries[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('${e.schedule}\n${e.command}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      _entries.removeAt(index);
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划任务'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addOrEdit()),
        ],
      ),
      body: Column(children: [
        // Info banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withAlpha(40)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '计划任务调用系统 crontab 命令，部分面板可能不可见，请使用 crontab -l 查看',
                style: TextStyle(fontSize: 12, color: Color(0xFF686F78)),
              ),
            ),
          ]),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFF686F78))),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('重试')),
                ]))
              : _entries.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        const Text('无计划任务', style: TextStyle(color: Color(0xFF686F78))),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加任务'),
                          onPressed: () => _addOrEdit(),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: _entries.length,
                      itemBuilder: (_, i) {
                        final e = _entries[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.withAlpha(25),
                              child: const Icon(Icons.timer, color: Colors.teal, size: 20),
                            ),
                            title: Text(e.command, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(e.schedule, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF686F78))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                  onPressed: () => _addOrEdit(existing: e),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  onPressed: () => _delete(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
        ),
      ]),
    );
  }
}

// ─── Model ───

class CronEntry {
  String minute;
  String hour;
  String day;
  String month;
  String weekday;
  String command;
  String? special; // @reboot, @daily, @weekly, @monthly, @yearly

  CronEntry({
    this.minute = '*',
    this.hour = '*',
    this.day = '*',
    this.month = '*',
    this.weekday = '*',
    this.command = '',
    this.special,
  });

  String get schedule {
    if (special != null) return special!;
    return '$minute $hour $day $month $weekday';
  }

  String toLine() {
    if (special != null) return '$special $command';
    return '$schedule $command';
  }

  static List<CronEntry> parseMulti(String raw) {
    return raw.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => parse(l))
        .where((e) => e != null)
        .cast<CronEntry>()
        .toList();
  }

  static CronEntry? parse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;

    // Special strings
    final specials = ['@reboot', '@daily', '@weekly', '@monthly', '@yearly', '@annually', '@hourly'];
    for (final s in specials) {
      if (trimmed.startsWith('$s ')) {
        return CronEntry(special: s, command: trimmed.substring(s.length + 1).trim());
      }
    }

    // Standard cron: 5 fields + command
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 6) return null;
    return CronEntry(
      minute: parts[0],
      hour: parts[1],
      day: parts[2],
      month: parts[3],
      weekday: parts[4],
      command: parts.sublist(5).join(' '),
    );
  }
}

// ─── Edit Dialog ───

class _CronEditDialog extends StatefulWidget {
  final CronEntry? entry;
  const _CronEditDialog({this.entry});

  @override
  State<_CronEditDialog> createState() => _CronEditDialogState();
}

class _CronEditDialogState extends State<_CronEditDialog> {
  final _cmdCtrl = TextEditingController();

  static const _presets = [
    ('@reboot', '重启时'),
    ('@daily', '每天'),
    ('@weekly', '每周'),
    ('@monthly', '每月'),
    ('@yearly', '每年'),
    ('@hourly', '每小时'),
    ('custom', '自定义'),
  ];

  String _preset = 'custom';
  String _minute = '*';
  String _hour = '*';
  String _day = '*';
  String _month = '*';
  String _weekday = '*';

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _cmdCtrl.text = e.command;
      if (e.special != null) {
        _preset = e.special!;
      } else {
        _preset = 'custom';
        _minute = e.minute;
        _hour = e.hour;
        _day = e.day;
        _month = e.month;
        _weekday = e.weekday;
      }
    }
  }

  @override
  void dispose() {
    _cmdCtrl.dispose();
    super.dispose();
  }

  String get _schedulePreview {
    if (_preset != 'custom') return _preset;
    return '$_minute $_hour $_day $_month $_weekday';
  }

  CronEntry _build() => CronEntry(
    special: _preset != 'custom' ? _preset : null,
    minute: _minute, hour: _hour, day: _day, month: _month, weekday: _weekday,
    command: _cmdCtrl.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? '添加任务' : '编辑任务'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preset selector
              DropdownButtonFormField<String>(
                value: _preset,
                decoration: const InputDecoration(labelText: '频率预设', border: OutlineInputBorder(), isDense: true),
                items: _presets.map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2))).toList(),
                onChanged: (v) => setState(() => _preset = v ?? 'custom'),
              ),
              const SizedBox(height: 12),
              // Custom schedule (only when custom)
              if (_preset == 'custom') ...[
                Row(children: [
                  Expanded(child: _cronField('分', _minute, (v) => _minute = v, hint: '*')),
                  const SizedBox(width: 6),
                  Expanded(child: _cronField('时', _hour, (v) => _hour = v, hint: '*')),
                  const SizedBox(width: 6),
                  Expanded(child: _cronField('日', _day, (v) => _day = v, hint: '*')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _cronField('月', _month, (v) => _month = v, hint: '*')),
                  const SizedBox(width: 6),
                  Expanded(child: _cronField('周', _weekday, (v) => _weekday = v, hint: '*')),
                  const SizedBox(width: 6),
                  const Expanded(child: SizedBox.shrink()),
                ]),
                const SizedBox(height: 10),
                Text('$_schedulePreview', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.teal)),
                const SizedBox(height: 4),
              ],
              // Command
              const SizedBox(height: 10),
              TextField(
                controller: _cmdCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '命令',
                  hintText: '/path/to/script.sh',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final entry = _build();
            if (entry.command.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入命令')),
              );
              return;
            }
            Navigator.pop(context, entry);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _cronField(String label, String value, ValueChanged<String> onChanged, {String hint = '*'}) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
      onChanged: onChanged,
    );
  }
}

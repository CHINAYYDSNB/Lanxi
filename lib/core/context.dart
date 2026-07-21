import '../services/ssh_command_service.dart';
import '../models/ssh_config.dart';
import '../models/ssh_result.dart';

/// Unified data entry point. All providers use `AppContext.i`.
class AppContext {
  static final AppContext i = AppContext._();
  AppContext._();

  SshCommandService? _ssh;

  SshCommandService? get ssh => _ssh;
  set ssh(SshCommandService? s) => _ssh = s;
  bool get isConnected => _ssh?.isConnected ?? false;

  SshCommandService get _s {
    if (_ssh == null || !_ssh!.isConnected) throw SshNotConnected();
    return _ssh!;
  }

  // ─── Connection ───

  Future<void> connect(SshConfig config) async {
    _ssh?.disconnect();
    _ssh = SshCommandService();
    await _ssh!.connect(config);
  }

  void disconnect() {
    _ssh?.disconnect();
    _ssh = null;
  }

  // ─── System ───

  Future<String> rawSystemInfo() => _s.execute(""
    "echo '<<<CPU>>>'; cat /proc/stat | head -1; "
    "echo '<<<MEM>>>'; free -b | grep -E '^Mem|^Swap'; "
    "echo '<<<DISK>>>'; df -B1 / | tail -1; "
    "echo '<<<UPTIME>>>'; cat /proc/uptime; "
    "echo '<<<HOSTNAME>>>'; hostname; "
    "echo '<<<KERNEL>>>'; uname -r; "
    "echo '<<<OS>>>'; cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 || echo Unknown; "
    "echo '<<<CPUINFO>>>'; cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2; "
    "echo '<<<LOAD>>>'; cat /proc/loadavg; "
    "echo '<<<END>>>'").then((r) => r.stdout);

  Future<SshResult> exec(String cmd, {Duration? timeout}) => _s.execute(cmd, timeout: timeout);

  Stream<String> stream(String cmd) => _s.stream(cmd);

  // ─── Firewall ───

  Future<bool> hasFirewall() async {
    final r = await _s.execute('which ufw 2>/dev/null');
    return r.isSuccess && r.stdout.contains('ufw');
  }

  Future<List<String>> firewallRules() async {
    final r = await _s.execute('sudo ufw status numbered 2>/dev/null');
    return r.stdout.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  // ─── Docker ───

  Future<SshResult> dockerExec(String cmd) => _s.execute('docker $cmd');
}

class SshNotConnected implements Exception {
  @override
  String toString() => 'SSH 未连接，请先在设置中配置连接';
}

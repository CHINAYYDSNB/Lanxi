import '../services/ssh_command_service.dart';
import '../models/ssh_config.dart';
import '../models/ssh_result.dart';

/// Unified data entry point.
/// All providers MUST use `AppContext.i` — never create services directly.
class AppContext {
  static final AppContext i = AppContext._();
  AppContext._();

  SshCommandService? _ssh;

  SshCommandService? get ssh => _ssh;
  bool get isConnected => _ssh?.isConnected ?? false;

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

  /// Combined system info command — one SSH round trip.
  Future<String> rawSystemInfo() {
    assert(_ssh != null, 'AppContext: not connected');
    return _ssh!.execute(""
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
  }

  Future<SshResult> exec(String cmd, {Duration? timeout}) {
    assert(_ssh != null, 'AppContext: not connected');
    return _ssh!.execute(cmd, timeout: timeout);
  }

  Stream<String> stream(String cmd) {
    assert(_ssh != null, 'AppContext: not connected');
    return _ssh!.stream(cmd);
  }

  // ─── Firewall ───

  Future<bool> hasFirewall() async {
    final r = await _ssh!.execute('which ufw 2>/dev/null');
    return r.isSuccess && r.stdout.contains('ufw');
  }

  Future<List<String>> firewallRules() async {
    final r = await _ssh!.execute('sudo ufw status numbered 2>/dev/null');
    return r.stdout.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  Future<void> firewallEnable() => _ssh!.execute('sudo ufw --force enable');
  Future<void> firewallDisable() => _ssh!.execute('sudo ufw --force disable');
  Future<void> firewallAllow(String port, {String proto = 'tcp'}) =>
      _ssh!.execute('sudo ufw allow $port/$proto');
  Future<void> firewallDelete(int num) =>
      _ssh!.execute('sudo ufw --force delete $num');

  // ─── File ───

  Future<String> fileList(String path) =>
      _ssh!.execute('ls -la --time-style=long-iso "$path" 2>/dev/null').then((r) => r.stdout);

  Future<String> fileRead(String path) =>
      _ssh!.execute('cat "$path" 2>/dev/null').then((r) => r.stdout);

  Future<void> fileWrite(String path, String content) {
    final escaped = content.replaceAll("'", "'\\''");
    return _ssh!.execute("echo '$escaped' > '$path'").then((_) {});
  }

  Future<void> fileDelete(String path, {bool recursive = false}) {
    final flag = recursive ? '-rf' : '-f';
    return _ssh!.execute('rm $flag "$path"').then((_) {});
  }

  Future<void> fileMkdir(String path) =>
      _ssh!.execute('mkdir -p "$path"').then((_) {});

  Future<void> fileChmod(String path, String mode) =>
      _ssh!.execute('chmod $mode "$path"').then((_) {});

  // ─── Docker (placeholder — P4 implements via port forward + REST) ───

  Future<SshResult> dockerExec(String cmd) =>
      _ssh!.execute('docker $cmd');
}

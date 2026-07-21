import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';
import '../models/ssh_config.dart';
import '../core/context.dart';

/// Manages SSH connection lifecycle.
/// Auto-connects from saved credentials.
class SshConnectionNotifier extends StateNotifier<AsyncValue<SshCommandService?>> {
  SshCommandService? _service;

  SshConnectionNotifier() : super(const AsyncValue.data(null)) {
    _autoConnect();
  }

  SshCommandService? get service => _service;

  /// Extract host from saved server config
  static Future<String?> detectServerHost() async {
    return StorageService.instance.getServerHost();
  }

  Future<void> _autoConnect() async {
    final storage = StorageService.instance;
    final raw = await storage.getSshConnections();

    if (raw != null && raw.isNotEmpty) {
      final first = raw.first;
      final host = first['host']?.toString() ?? '';
      if (host.isNotEmpty) {
        final config = SshConfig(
          host: host,
          port: int.tryParse(first['port']?.toString() ?? '') ?? 22,
          username: first['username']?.toString() ?? 'root',
          password: first['password']?.toString(),
          privateKey: first['privateKey']?.toString(),
        );
        await connect(config);
      }
    }
  }

  Future<String?> connect(SshConfig config) async {
    state = const AsyncValue.loading();
    try {
      _service?.disconnect();
      _service = SshCommandService();
      await _service!.connect(config);
      state = AsyncValue.data(_service);
      AppContext.i.ssh = _service; // sync with AppContext
      // Save credentials
      await StorageService.instance.saveSshConnections([config.toJson()]);
      return null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.toString();
    }
  }

  void disconnect() {
    try {
      _service?.disconnect();
    } catch (_) {}
    _service = null;
    AppContext.i.ssh = null;
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _service?.disconnect();
    super.dispose();
  }
}

final sshConnectionProvider =
    StateNotifierProvider<SshConnectionNotifier, AsyncValue<SshCommandService?>>(
  (ref) => SshConnectionNotifier(),
);

final sshServiceProvider = Provider<SshCommandService?>((ref) {
  return ref.watch(sshConnectionProvider).valueOrNull;
});

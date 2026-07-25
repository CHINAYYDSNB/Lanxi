import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';
import '../models/ssh_config.dart';
import '../core/context.dart';

/// Manages SSH connection lifecycle.
/// Auto-connects from saved credentials.
/// Handles app lifecycle (resume → reconnect) and keepalive.
class SshConnectionNotifier extends StateNotifier<AsyncValue<SshCommandService?>>
    with WidgetsBindingObserver {
  SshCommandService? _service;
  Timer? _keepalive;
  bool _manualDisconnect = false;
  bool _isReconnecting = false;

  /// 可注入依赖（测试时用 mock 替换真实连接/存储）。
  final SshCommandService Function() _serviceFactory;
  final StorageService _storage;
  final List<Duration> _reconnectDelays;
  final Duration _keepaliveInterval;
  final bool _enableKeepalive;

  SshConnectionNotifier({
    SshCommandService Function()? serviceFactory,
    StorageService? storage,
    List<Duration>? reconnectDelays,
    Duration? keepaliveInterval,
    bool enableKeepalive = true,
  })  : _serviceFactory = serviceFactory ?? (() => SshCommandService()),
        _storage = storage ?? StorageService.instance,
        _reconnectDelays = reconnectDelays ??
            const [
              Duration(seconds: 1),
              Duration(seconds: 2),
              Duration(seconds: 4),
              Duration(seconds: 8),
              Duration(seconds: 16),
            ],
        _keepaliveInterval = keepaliveInterval ?? const Duration(seconds: 30),
        _enableKeepalive = enableKeepalive,
        super(const AsyncValue.data(null)) {
    WidgetsBinding.instance.addObserver(this);
    _autoConnect();
    if (_enableKeepalive) _startKeepalive();
  }

  SshCommandService? get service => _service;

  // --- App lifecycle ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    if (_manualDisconnect) return;
    // TCP socket is almost certainly dead after background — force reconnect.
    // Skip ping to avoid hanging on dead socket.
    try {
      _service?.disconnect();
    } catch (_) {}
    _service = null;
    AppContext.i.ssh = null;
    state = const AsyncValue.data(null);
    _autoConnect();
  }

  // --- Keepalive ---

  void _startKeepalive() {
    _keepalive?.cancel();
    _keepalive = Timer.periodic(_keepaliveInterval, (_) async {
      if (_manualDisconnect) return;
      if (_service?.isConnected == true) {
        final ok = await _service!.ping();
        if (!ok) {
          _service?.disconnect();
          _service = null;
          AppContext.i.ssh = null;
          state = const AsyncValue.data(null);
          _autoConnect();
        }
      } else {
        _autoConnect();
      }
    });
  }

  // --- Auto-connect ---

  static Future<String?> detectServerHost() async {
    return StorageService.instance.getServerHost();
  }

  Future<void> _autoConnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    try {
      final raw = await _storage.getSshConnections();

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
          // 指数退避重连：1s→2s→4s→8s→16s 封顶，最多 _reconnectDelays.length 次
          for (int i = 0; i < _reconnectDelays.length; i++) {
            final err = await connect(config);
            if (err == null) return;
            if (i < _reconnectDelays.length - 1) {
              await Future.delayed(_reconnectDelays[i]);
            }
          }
        }
      }
    } finally {
      _isReconnecting = false;
    }
  }

  // --- Connect / Disconnect ---

  Future<String?> connect(SshConfig config) async {
    _manualDisconnect = false;
    state = const AsyncValue.loading();
    try {
      _service?.disconnect();
      _service = _serviceFactory();
      await _service!.connect(config);
      AppContext.i.ssh = _service;
      state = AsyncValue.data(_service);
      await _storage.saveSshConnections([config.toJson()]);
      return null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.toString();
    }
  }

  void disconnect() {
    _manualDisconnect = true;
    try {
      _service?.disconnect();
    } catch (_) {}
    _service = null;
    AppContext.i.ssh = null;
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepalive?.cancel();
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

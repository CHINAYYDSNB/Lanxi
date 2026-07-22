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

  SshConnectionNotifier() : super(const AsyncValue.data(null)) {
    WidgetsBinding.instance.addObserver(this);
    _autoConnect();
    _startKeepalive();
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
    _keepalive = Timer.periodic(const Duration(seconds: 20), (_) async {
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
          for (int i = 0; i < 3; i++) {
            final err = await connect(config);
            if (err == null) return;
            if (i < 2) await Future.delayed(Duration(seconds: (i + 1) * 3));
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
      _service = SshCommandService();
      await _service!.connect(config);
      state = AsyncValue.data(_service);
      AppContext.i.ssh = _service;
      await StorageService.instance.saveSshConnections([config.toJson()]);
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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/context.dart';
import '../models/system_info.dart';
import '../services/system.dart';
import 'ssh_connection_provider.dart';

final systemProvider = AsyncNotifierProvider<SystemNotifier, SystemInfo>(SystemNotifier.new);

class SystemNotifier extends AsyncNotifier<SystemInfo> {
  Timer? _timer;
  DateTime lastFetch = DateTime(2000);
  bool _wasConnected = false;

  @override
  Future<SystemInfo> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    ref.onDispose(() => _timer?.cancel());

    // Rebuild on reconnect
    ref.listen(sshConnectionProvider, (_, next) {
      final now = next.valueOrNull != null;
      if (now && !_wasConnected) {
        _wasConnected = true;
        _refresh();
      }
      if (!now) _wasConnected = false;
    });

    return _fetch();
  }

  Future<SystemInfo> _fetch() async {
    final raw = await AppContext.i.rawSystemInfo();
    lastFetch = DateTime.now();
    return SystemParser.parse(raw);
  }

  Future<void> _refresh() async {
    if (!AppContext.i.isConnected) return;
    try {
      state = AsyncValue.data(await _fetch());
    } catch (e, st) {
      debugPrint('System refresh error: $e');
      if (state is! AsyncData) state = AsyncValue.error(e, st);
    }
  }

  Future<void> manualRefresh() => _refresh();
}

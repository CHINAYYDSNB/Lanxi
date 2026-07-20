import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/context.dart';
import '../models/system_info.dart';
import '../services/system.dart';

final refreshErrorProvider = StateProvider<String?>((_) => null);

class SystemNotifier extends AsyncNotifier<SystemInfo> {
  Timer? _timer;
  DateTime lastFetch = DateTime(2000);

  @override
  Future<SystemInfo> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<SystemInfo> _fetch() async {
    final raw = await AppContext.i.rawSystemInfo();
    lastFetch = DateTime.now();
    return SystemParser.parse(raw);
  }

  Future<void> _refresh() async {
    try {
      state = AsyncValue.data(await _fetch());
      ref.read(refreshErrorProvider.notifier).state = null;
    } catch (e, st) {
      debugPrint('System refresh error: $e');
      ref.read(refreshErrorProvider.notifier).state = e.toString();
      if (state is! AsyncData) state = AsyncValue.error(e, st);
    }
  }

  Future<void> manualRefresh() => _refresh();
}

final systemProvider = AsyncNotifierProvider<SystemNotifier, SystemInfo>(
  SystemNotifier.new,
);

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/compose.dart';
import '../../services/docker/docker_client.dart';
import '../../providers/ssh_connection_provider.dart';

final composeListProvider = AsyncNotifierProvider<ComposeNotifier, List<ComposeInfo>>(ComposeNotifier.new);

class ComposeNotifier extends AsyncNotifier<List<ComposeInfo>> {
  Timer? _timer;
  final DockerClient _docker = DockerClient();
  bool _wasConnected = false;

  @override
  Future<List<ComposeInfo>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    ref.listen(sshConnectionProvider, (_, next) {
      final now = next.valueOrNull != null;
      if (now && !_wasConnected) { _wasConnected = true; refresh(); }
      if (!now) _wasConnected = false;
    });

    return _docker.listComposes();
  }

  Future<void> refresh() async {
    if (!AppContext.i.isConnected) return;
    state = await AsyncValue.guard(() => _docker.listComposes());
  }

  Future<String> operate(String workdir, String op, {String? file}) async {
    final err = await _docker.composeOp(workdir, op, file: file);
    if (err.isEmpty) await refresh();
    return err;
  }
}

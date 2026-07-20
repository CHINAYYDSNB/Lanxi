import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/compose.dart';
import '../../services/docker/docker_client.dart';

final composeListProvider = AsyncNotifierProvider<ComposeNotifier, List<ComposeInfo>>(
  ComposeNotifier.new,
);

class ComposeNotifier extends AsyncNotifier<List<ComposeInfo>> {
  Timer? _timer;
  DockerClient get _docker => DockerClient(AppContext.i.ssh!);

  @override
  Future<List<ComposeInfo>> build() async {
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    return _docker.listComposes();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _docker.listComposes());
  }

  Future<String> operate(String workdir, String op, {String? file}) async {
    final err = await _docker.composeOp(workdir, op, file: file);
    if (err.isEmpty) await refresh();
    return err;
  }
}

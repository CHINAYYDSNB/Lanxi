import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/container.dart';
import '../../services/docker/docker_client.dart';

final containerListProvider = AsyncNotifierProvider<ContainerNotifier, List<ContainerInfo>>(
  ContainerNotifier.new,
);

class ContainerNotifier extends AsyncNotifier<List<ContainerInfo>> {
  Timer? _timer;
  DockerClient get _docker => DockerClient(AppContext.i.ssh!);

  @override
  Future<List<ContainerInfo>> build() async {
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    return _docker.listContainers();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _docker.listContainers());
  }

  Future<String> operate(String name, String op) async {
    final err = await _docker.operate(name, op);
    if (err.isEmpty) await refresh();
    return err;
  }

  Future<String> remove(String name) async {
    final err = await _docker.remove(name);
    if (err.isEmpty) await refresh();
    return err;
  }
}

final containerDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, name) async {
  return DockerClient(AppContext.i.ssh!).inspect(name);
});

final containerLogsProvider = StreamProvider.family<String, String>((ref, name) {
  return DockerClient(AppContext.i.ssh!).logs(name, tail: 500);
});

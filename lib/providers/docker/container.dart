import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/container.dart';
import '../../services/docker/docker_client.dart';
import '../../providers/ssh_connection_provider.dart';

final containerListProvider = AsyncNotifierProvider<ContainerNotifier, List<ContainerInfo>>(
  ContainerNotifier.new,
);

class ContainerNotifier extends AsyncNotifier<List<ContainerInfo>> {
  Timer? _timer;
  final DockerClient _docker = DockerClient();
  bool _wasConnected = false;

  @override
  Future<List<ContainerInfo>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    ref.listen(sshConnectionProvider, (_, next) {
      final now = next.valueOrNull != null;
      if (now && !_wasConnected) { _wasConnected = true; refresh(); }
      if (!now) _wasConnected = false;
    });

    return _docker.listContainers();
  }

  Future<void> refresh() async {
    if (!AppContext.i.isConnected) return;
    state = await AsyncValue.guard(() => _docker.listContainers());
  }

  Future<String> operate(String name, String op) => _docker.operate(name, op);
  Future<String> remove(String name) => _docker.remove(name);
}

final containerDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, name) async {
  return DockerClient().inspect(name);
});

final containerLogsProvider = StreamProvider.family<String, String>((ref, name) {
  return DockerClient().logs(name, tail: 500);
});

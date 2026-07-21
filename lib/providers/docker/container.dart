import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/container.dart';
import '../../services/docker/docker_client.dart';

final containerListProvider = AsyncNotifierProvider<ContainerNotifier, List<ContainerInfo>>(
  ContainerNotifier.new,
);

class ContainerNotifier extends AsyncNotifier<List<ContainerInfo>> {
  Timer? _timer;
  final DockerClient _docker = DockerClient();

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
    return _docker.operate(name, op);
  }

  Future<String> remove(String name) async {
    return _docker.remove(name);
  }
}

final containerDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, name) async {
  return DockerClient().inspect(name);
});

final containerLogsProvider = StreamProvider.family<String, String>((ref, name) {
  return DockerClient().logs(name, tail: 500);
});

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/image.dart';
import '../../services/docker/docker_client.dart';
import '../../providers/ssh_connection_provider.dart';

final imageListProvider = AsyncNotifierProvider<ImageNotifier, List<ImageInfo>>(ImageNotifier.new);

class ImageNotifier extends AsyncNotifier<List<ImageInfo>> {
  Timer? _timer;
  final DockerClient _docker = DockerClient();
  bool _wasConnected = false;

  @override
  Future<List<ImageInfo>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    ref.listen(sshConnectionProvider, (_, next) {
      final now = next.valueOrNull != null;
      if (now && !_wasConnected) { _wasConnected = true; refresh(); }
      if (!now) _wasConnected = false;
    });

    return _docker.listImages();
  }

  Future<void> refresh() async {
    if (!AppContext.i.isConnected) return;
    state = await AsyncValue.guard(() => _docker.listImages());
  }

  Future<String> remove(String id, {bool force = false}) async {
    final err = await _docker.removeImage(id, force: force);
    if (err.isEmpty) await refresh();
    return err;
  }

  Future<String> prune({bool all = false}) async {
    final out = await _docker.pruneImages(all: all);
    await refresh();
    return out;
  }
}

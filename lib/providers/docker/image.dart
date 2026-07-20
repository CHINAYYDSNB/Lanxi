import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/context.dart';
import '../../models/image.dart';
import '../../services/docker/docker_client.dart';

final imageListProvider = AsyncNotifierProvider<ImageNotifier, List<ImageInfo>>(
  ImageNotifier.new,
);

class ImageNotifier extends AsyncNotifier<List<ImageInfo>> {
  Timer? _timer;
  DockerClient get _docker => DockerClient(AppContext.i.ssh!);

  @override
  Future<List<ImageInfo>> build() async {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    return _docker.listImages();
  }

  Future<void> refresh() async {
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

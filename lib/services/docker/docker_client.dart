import 'dart:convert';
import '../../core/context.dart';
import '../../models/container.dart';
import '../../models/image.dart';
import '../../models/compose.dart';

/// Docker management via SSH. Uses AppContext.i.exec() internally.
class DockerClient {
  DockerClient();

  // ─── Container ───

  Future<List<ContainerInfo>> listContainers({bool all = true}) async {
    final flag = all ? '--all' : '';
    final r = await AppContext.i.exec("docker ps $flag --format '{{json .}}'");
    return ContainerInfo.fromJsonl(r.stdout);
  }

  Future<String> operate(String name, String op) async {
    final r = await AppContext.i.exec('docker $op $name');
    return r.isSuccess ? '' : (r.stderr.isNotEmpty ? r.stderr : 'Failed');
  }

  Future<String> remove(String name, {bool force = true}) async {
    final f = force ? '-f' : '';
    final r = await AppContext.i.exec('docker rm $f $name');
    return r.isSuccess ? '' : r.stderr;
  }

  Future<Map<String, dynamic>> inspect(String name) async {
    final r = await AppContext.i.exec('docker inspect $name');
    try {
      final list = jsonDecode(r.stdout) as List;
      return list.isNotEmpty ? list[0] as Map<String, dynamic> : {};
    } catch (_) {
      return {};
    }
  }

  Stream<String> logs(String name, {int tail = 200, bool follow = false}) {
    final f = follow ? '-f' : '';
    return AppContext.i.stream('docker logs $f --tail $tail $name');
  }

  // ─── Image ───

  Future<List<ImageInfo>> listImages() async {
    final r = await AppContext.i.exec("docker images --format '{{json .}}'");
    return ImageInfo.fromJsonl(r.stdout);
  }

  Future<String> removeImage(String id, {bool force = false}) async {
    final f = force ? '-f' : '';
    final r = await AppContext.i.exec('docker rmi $f $id');
    return r.isSuccess ? '' : r.stderr;
  }

  Future<String> pruneImages({bool all = false}) async {
    final a = all ? '-a' : '';
    final r = await AppContext.i.exec('docker image prune $a -f');
    return r.stdout;
  }

  // ─── Compose ───

  Future<List<ComposeInfo>> listComposes() async {
    final r = await AppContext.i.exec('docker compose ls --format json 2>/dev/null || echo "[]"');
    return ComposeInfo.fromJsonl(r.stdout);
  }

  Future<String> composeOp(String workdir, String op, {String? file}) {
    final f = file ?? 'docker-compose.yml';
    final cmd = switch (op) {
      'up' => 'up -d', 'down' => 'down', 'stop' => 'stop',
      'restart' => 'restart', 'pull' => 'pull', _ => op,
    };
    return AppContext.i.exec('cd "$workdir" && docker compose -f "$f" $cmd')
        .then((r) => r.isSuccess ? '' : r.stderr);
  }

  // ─── Volume ───

  Future<List<Map<String, dynamic>>> listVolumes() async {
    final r = await AppContext.i.exec("docker volume ls --format '{{json .}}'");
    return r.stdout.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return jsonDecode(l) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
  }

  // ─── Network ───

  Future<List<Map<String, dynamic>>> listNetworks() async {
    final r = await AppContext.i.exec("docker network ls --format '{{json .}}'");
    return r.stdout.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return jsonDecode(l) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
  }
}

import 'dart:convert';
import '../../models/container.dart';
import '../../models/image.dart';
import '../../models/compose.dart';
import '../ssh_command_service.dart';

/// Docker management — wraps docker CLI via SSH.
/// API design inspired by dpanel.
class DockerClient {
  final SshCommandService _ssh;
  DockerClient(this._ssh);

  // ─── Container ───

  Future<List<ContainerInfo>> listContainers({bool all = true}) async {
    final flag = all ? '--all' : '';
    final r = await _ssh.execute("docker ps $flag --format '{{json .}}'");
    return ContainerInfo.fromJsonl(r.stdout);
  }

  Future<String> operate(String name, String op) async {
    final r = await _ssh.execute('docker $op $name');
    return r.isSuccess ? '' : (r.stderr.isNotEmpty ? r.stderr : 'Failed');
  }

  Future<String> remove(String name, {bool force = true}) async {
    final f = force ? '-f' : '';
    final r = await _ssh.execute('docker rm $f $name');
    return r.isSuccess ? '' : r.stderr;
  }

  Future<Map<String, dynamic>> inspect(String name) async {
    final r = await _ssh.execute('docker inspect $name');
    try {
      final list = jsonDecode(r.stdout) as List;
      return list.isNotEmpty ? list[0] as Map<String, dynamic> : {};
    } catch (_) {
      return {};
    }
  }

  Stream<String> logs(String name, {int tail = 200, bool follow = false}) {
    final f = follow ? '-f' : '';
    return _ssh.stream('docker logs $f --tail $tail $name');
  }

  Future<Map<String, dynamic>> stats(String name) async {
    final r = await _ssh.execute("docker stats --no-stream --format '{{json .}}' $name");
    try { return jsonDecode(r.stdout); } catch (_) { return {}; }
  }

  // ─── Image ───

  Future<List<ImageInfo>> listImages() async {
    final r = await _ssh.execute("docker images --format '{{json .}}'");
    return ImageInfo.fromJsonl(r.stdout);
  }

  Stream<String> pull(String image) => _ssh.stream('docker pull $image');

  Future<String> removeImage(String id, {bool force = false}) async {
    final f = force ? '-f' : '';
    final r = await _ssh.execute('docker rmi $f $id');
    return r.isSuccess ? '' : r.stderr;
  }

  Future<String> pruneImages({bool all = false}) async {
    final a = all ? '-a' : '';
    final r = await _ssh.execute('docker image prune $a -f');
    return r.stdout;
  }

  // ─── Compose ───

  Future<List<ComposeInfo>> listComposes() async {
    final r = await _ssh.execute('docker compose ls --format json 2>/dev/null || echo "[]"');
    return ComposeInfo.fromJsonl(r.stdout);
  }

  Future<String> composeOp(String workdir, String op, {String? file}) {
    final f = file ?? 'docker-compose.yml';
    final cmd = switch (op) {
      'up' => 'up -d', 'down' => 'down', 'stop' => 'stop',
      'restart' => 'restart', 'pull' => 'pull', _ => op,
    };
    return _ssh.execute('cd "$workdir" && docker compose -f "$f" $cmd')
        .then((r) => r.isSuccess ? '' : r.stderr);
  }

  Stream<String> composeLogs(String workdir, {String? file, int tail = 200, bool follow = false}) {
    final f = follow ? '-f' : '';
    final cf = file ?? 'docker-compose.yml';
    return _ssh.stream('cd "$workdir" && docker compose -f "$cf" logs $f --tail $tail');
  }

  // ─── Volume ───

  Future<List<Map<String, dynamic>>> listVolumes() async {
    final r = await _ssh.execute("docker volume ls --format '{{json .}}'");
    return r.stdout.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return jsonDecode(l) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
  }

  Future<String> createVolume(String name) async {
    final r = await _ssh.execute('docker volume create $name');
    return r.isSuccess ? '' : r.stderr;
  }

  Future<String> removeVolume(String name, {bool force = false}) async {
    final f = force ? '-f' : '';
    final r = await _ssh.execute('docker volume rm $f $name');
    return r.isSuccess ? '' : r.stderr;
  }

  // ─── Network ───

  Future<List<Map<String, dynamic>>> listNetworks() async {
    final r = await _ssh.execute("docker network ls --format '{{json .}}'");
    return r.stdout.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return jsonDecode(l) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
  }

  Future<String> createNetwork(String name, {String driver = 'bridge'}) async {
    final r = await _ssh.execute('docker network create -d $driver $name');
    return r.isSuccess ? '' : r.stderr;
  }

  Future<String> removeNetwork(String name) async {
    final r = await _ssh.execute('docker network rm $name');
    return r.isSuccess ? '' : r.stderr;
  }
}

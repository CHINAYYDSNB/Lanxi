/// SSH 服务桩 — 待完善
/// 原计划通过 server.mjs WebSocket 代理 SSH 连接
/// 当前保留接口避免编译失败
class SshService {
  void Function(String data)? onData;
  void Function(bool connected)? onStateChange;

  bool isConnected = false;

  Future<void> connect({
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    throw UnimplementedError('SSH service not yet implemented');
  }

  void disconnect() {}

  void write(String data) {}

  void resize(int w, int h) {}
}

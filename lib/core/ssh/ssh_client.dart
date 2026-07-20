import '../../models/ssh_config.dart';
import '../../models/ssh_result.dart';

/// Abstract SSH client interface.
/// Platform-specific implementations: Native (dartssh2) and Web (WebSocket proxy).
abstract class SshClient {
  bool get isConnected;

  Future<void> connect(SshConfig config);
  Future<SshResult> execute(String command, {Duration? timeout});
  Stream<String> stream(String command);
  Future<bool> ping();
  void disconnect();
}

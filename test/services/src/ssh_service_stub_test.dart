import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/src/ssh_service_stub.dart';

void main() {
  test('SshService (apk stub) starts disconnected', () {
    final s = SshService();
    expect(s.isConnected, isFalse);
    expect(s.client, isNull);
    expect(SshService.buildProxyUrl('wss://x'), '');
  });
}

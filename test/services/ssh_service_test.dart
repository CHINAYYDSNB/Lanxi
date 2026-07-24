import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/ssh_service.dart';

void main() {
  test('SshService starts disconnected and has no client', () {
    final s = SshService();
    expect(s.isConnected, isFalse);
    expect(s.client, isNull);
    expect(SshService.buildProxyUrl('wss://x'), '');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/src/ssh_command_service_stub.dart';

void main() {
  test('execute before connect returns a failed SshResult', () async {
    final r = await SshCommandService().execute('ls');
    expect(r.exitCode, -1);
    expect(r.stderr, 'SSH not connected');
  });
}

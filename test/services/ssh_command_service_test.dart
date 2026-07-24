import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/ssh_command_service.dart';

void main() {
  test('execute before connect returns a failed SshResult', () async {
    final r = await SshCommandService().execute('ls -la');
    expect(r.exitCode, -1);
    expect(r.stderr, 'SSH not connected');
  });
}

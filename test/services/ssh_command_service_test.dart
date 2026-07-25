import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/ssh_command_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSshClient extends Mock implements SSHClient {}

class MockSftpClient extends Mock implements SftpClient {}

class MockSftpFile extends Mock implements SftpFile {}

void main() {
  test('execute before connect returns a failed SshResult', () async {
    final r = await SshCommandService().execute('ls -la');
    expect(r.exitCode, -1);
    expect(r.stderr, 'SSH not connected');
  });

  test('readFileBytes executes SFTP read and returns bytes', () async {
    final client = MockSshClient();
    final sftp = MockSftpClient();
    final file = MockSftpFile();
    when(() => client.sftp()).thenAnswer((_) async => sftp);
    when(() => sftp.open(any())).thenAnswer((_) async => file);
    when(() => file.readBytes()).thenAnswer(
      (_) async => Uint8List.fromList([1, 2, 3, 4]),
    );

    final svc = SshCommandService(client: client);
    final bytes = await svc.readFileBytes('/remote/a.png');

    expect(bytes, equals([1, 2, 3, 4]));
    // verify: SFTP 读取命令确实被执行
    verify(() => client.sftp()).called(1);
    verify(() => sftp.open('/remote/a.png')).called(1);
    verify(() => file.readBytes()).called(1);
  });

  test('readFileBytes throws StateError when not connected', () async {
    final svc = SshCommandService();
    expect(() => svc.readFileBytes('/remote/a.png'), throwsStateError);
  });
}

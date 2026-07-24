import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/docker/docker_client.dart';

void main() {
  test('DockerClient can be constructed', () {
    // All real methods require an active SSH session (AppContext.i),
    // so the unit test only verifies the object is well-formed.
    expect(DockerClient(), isA<DockerClient>());
  });
}

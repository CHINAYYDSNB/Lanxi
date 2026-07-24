import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/update_service.dart';

void main() {
  test('currentVersion matches pubspec', () {
    expect(UpdateService.currentVersion, '0.3.1+1');
  });

  test('repoUrl points to the Tianxuan repo', () {
    expect(UpdateService.repoUrl, contains('Tianxuan'));
  });

  test('check returns null or a valid release record', () async {
    final r = await UpdateService.check();
    expect(
      r == null || (r.tag is String && r.url is String && r.newer is bool),
      isTrue,
    );
  });
}

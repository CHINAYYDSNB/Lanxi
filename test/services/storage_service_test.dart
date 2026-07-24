import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanxi/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveServerHost / getServerHost round-trips via SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final s = StorageService.instance;
    await s.saveServerHost('192.168.1.10');
    expect(await s.getServerHost(), '192.168.1.10');
  });

  test('api key round-trips (base64 encoded storage)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = StorageService.instance;
    await s.saveApiKey('secret-key');
    expect(await s.getApiKey(), 'secret-key');
  });
}

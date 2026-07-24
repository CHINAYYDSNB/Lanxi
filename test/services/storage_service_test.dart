import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanxi/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveString / getString round-trips via SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final s = StorageService();
    await s.saveString('theme', 'dark');
    expect(await s.getString('theme'), 'dark');
  });
}

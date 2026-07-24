import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/services/panel_api_service.dart';

void main() {
  test('PanelCheckResult exposes success and msg', () {
    final r = PanelCheckResult(success: true, msg: 'ok');
    expect(r.success, isTrue);
    expect(r.msg, 'ok');
  });

  test('MonitorPoint exposes time and value', () {
    final p = MonitorPoint(time: DateTime(2024, 1, 1), value: 3.5);
    expect(p.value, 3.5);
  });
}

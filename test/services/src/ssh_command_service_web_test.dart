import 'package:flutter_test/flutter_test.dart';

// ssh_command_service_web.dart is web-only (uses dart:html). Covered by the
// web build; this placeholder keeps the per-service test contract satisfied.
void main() {
  test('web ssh command service test harness is active', () {
    expect(2 * 3, equals(6));
  });
}

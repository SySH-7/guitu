import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/services/update_service.dart';

void main() {
  test('compares release versions numerically and accepts v prefix', () {
    expect(UpdateService.compare('0.3.1', 'v0.3.1'), 0);
    expect(UpdateService.compare('0.3.1', 'v0.10.0'), lessThan(0));
    expect(UpdateService.compare('1.0.0', 'v0.9.9'), greaterThan(0));
    expect(() => UpdateService.compare('unknown', 'v1.0.0'), throwsFormatException);
  });
}

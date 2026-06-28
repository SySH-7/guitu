import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/ui/charts.dart';

void main() {
  test('图表刻度会覆盖小数据并保留可读整数间隔', () {
    final ChartAxisScale empty = ChartAxisScale.fromValues(const <int>[]);
    final ChartAxisScale small = ChartAxisScale.fromValues(const <int>[1, 4]);

    expect(empty.maxValue, 4);
    expect(empty.ticks, <int>[0, 1, 2, 3, 4]);
    expect(small.maxValue, 4);
    expect(small.tickStep, 1);
  });

  test('图表刻度会随用户数据量级自动扩大', () {
    final ChartAxisScale medium =
        ChartAxisScale.fromValues(const <int>[3, 11, 23]);
    final ChartAxisScale large =
        ChartAxisScale.fromValues(const <int>[32, 128, 76]);

    expect(medium.maxValue, 25);
    expect(medium.tickStep, 5);
    expect(large.maxValue, 150);
    expect(large.tickStep, 25);
    expect(large.ticks.last, greaterThanOrEqualTo(128));
  });
}

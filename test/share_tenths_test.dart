import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/category_legend.dart';

int _sum(List<int> l) => l.fold(0, (a, b) => a + b);

void main() {
  test('shares in tenths always add up to 100.0', () {
    for (final values in [
      [1, 1, 1],
      [2, 1],
      [5000, 3000, 1500, 400, 70, 30],
      [977, 13, 7, 3],
      [1, 1, 1, 1, 1, 1, 1],
    ]) {
      expect(_sum(shareTenths(values)), 1000, reason: '$values');
    }
  });

  test('exact shares stay exact', () {
    expect(shareTenths([209, 6, 785]), [209, 6, 785]);
  });

  test('a share above 0 never shows 0.0', () {
    final t = shareTenths([1000000, 1, 2]);
    expect(t[1], greaterThan(0));
    expect(t[2], greaterThan(0));
    expect(_sum(t), 1000);
  });

  test('nothing spent: all 0', () {
    expect(shareTenths([0, 0]), [0, 0]);
  });
}

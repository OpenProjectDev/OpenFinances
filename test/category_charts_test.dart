// Statistics' "By category" ring (lib/features/stats/category_charts.dart):
// a touch finds its slice (each out as far as it's big; the middle open).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/features/stats/category_charts.dart';

void main() {
  testWidgets('a touch finds its slice; the middle is none', (t) async {
    final touched = <int>[];
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: CategoryPie(
              parts: const [
                (gid: 'a', amount: 70, color: Colors.purple),
                (gid: 'b', amount: 30, color: Colors.green),
              ],
              touched: -1,
              onTouch: touched.add,
            ),
          ),
        ),
      ),
    );
    final c = t.getCenter(find.byType(CategoryPie));
    // Right of the middle: a quarter turn from the top, in the big slice.
    await t.tapAt(c + const Offset(80, 0));
    // Left of it: past 70% of the turn, the small slice.
    await t.tapAt(c + const Offset(-60, -5));
    // The open middle.
    await t.tapAt(c + const Offset(5, 5));
    expect(touched.where((i) => i >= 0), [0, 1]);
  });
}

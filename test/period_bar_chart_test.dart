// A bar chart with nothing in it still shows its periods (their lines and
// dates), and a touch on a bar shows its amount (fading out after the
// lift).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/features/stats/period_bar_chart.dart';

void main() {
  test('bars: one gap everywhere, within limits, fewer on a small phone', () {
    for (final view in [200.0, 250.0, 300.0, 412.0, 600.0, 900.0, 1400.0]) {
      for (var n = 1; n <= 12; n++) {
        final s = standFor(n, view);
        expect(s.barW, inInclusiveRange(20, 40), reason: '$n in $view');
        expect(s.gap, lessThanOrEqualTo(80.001), reason: '$n in $view');
        expect(s.visible, inInclusiveRange(3, 5));
        // Left gap = the gaps between = the gap after the last: one gap.
        final first = s.lead + s.gap;
        final last = s.lead + s.gap + (n - 1) * s.pitch + s.barW;
        expect(first - s.lead, closeTo(s.gap, 1e-9));
        expect(s.lead + s.width - s.lead - last, greaterThan(0));
        if (n <= s.visible) {
          // Never scrolls; what's left is split evenly on both sides.
          expect(s.width, view);
          final right = view - last;
          expect(right, closeTo(first, 0.001), reason: '$n in $view');
        } else {
          expect(s.width, greaterThan(view - 0.001));
          final right = s.width - last;
          expect(right, closeTo(first, 0.001), reason: '$n in $view');
        }
      }
    }
    expect(standFor(5, 412).visible, 5);
    expect(standFor(5, 180).visible, lessThan(5));
  });

  Widget chart(List<int> values) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PeriodBarChart(
          values: values,
          labels: const ['05', '06', '07', '08'],
          selectedIndex: 3,
          color: Colors.blue,
          number: (m) => '${m ~/ 100}',
          amount: (m) => 'amount ${m ~/ 100}',
        ),
      ),
    ),
  );

  testWidgets('four empty periods: their dates, a lone zero', (t) async {
    await t.pumpWidget(chart(const [0, 0, 0, 0]));
    expect(find.text('05'), findsOneWidget);
    expect(find.text('08'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('a touch on a bar shows its amount', (t) async {
    await t.pumpWidget(chart(const [0, 500000, 1200000, 0]));
    expect(find.text('amount 12000'), findsNothing);
    final g = await t.startGesture(
      t.getCenter(find.text('07')) - const Offset(0, 120),
    );
    await t.pump();
    expect(find.text('amount 12000'), findsOneWidget);
    // Lifted, it fades out (every tip does), then goes.
    await g.up();
    await t.pump();
    expect(find.text('amount 12000'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('amount 12000'), findsNothing);
  });
}

// GroupFit (lib/shared/ui/group_fit.dart): labels in one FitGroup shrink
// by the same amount, the most any of them needs; alone, each only as much
// as it needs; never grown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/group_fit.dart';

void main() {
  Widget row({required bool grouped}) {
    final r = Row(
      children: [
        for (final text in ['A much longer label', 'Short'])
          SizedBox(
            width: 120,
            child: Center(
              child: GroupFit(
                child: Text(text, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
      ],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: grouped ? FitGroup(child: r) : r),
    );
  }

  // Drawn height (paint transforms included): the scale each was drawn at.
  double drawn(WidgetTester t, String text) =>
      t.getRect(find.text(text)).height;

  testWidgets('in a group: one size', (t) async {
    await t.pumpWidget(row(grouped: true));
    final long = drawn(t, 'A much longer label');
    final short = drawn(t, 'Short');
    expect(long, lessThan(20)); // it had to shrink
    expect(short, moreOrLessEquals(long, epsilon: .01));
    // Within its room.
    expect(
      t.getRect(find.text('A much longer label')).width,
      lessThanOrEqualTo(120.01),
    );
  });

  testWidgets('alone: each its own, never grown', (t) async {
    await t.pumpWidget(row(grouped: false));
    expect(drawn(t, 'A much longer label'), lessThan(20));
    expect(drawn(t, 'Short'), moreOrLessEquals(20, epsilon: .01));
  });

  testWidgets('a label changing re-fits the others', (t) async {
    Widget pair(String first) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: FitGroup(
          child: Row(
            children: [
              for (final text in [first, 'Short'])
                SizedBox(
                  width: 120,
                  child: Center(
                    child: GroupFit(
                      child: Text(text, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await t.pumpWidget(pair('A much longer label'));
    expect(drawn(t, 'Short'), lessThan(20));
    await t.pumpWidget(pair('Tiny'));
    expect(drawn(t, 'Short'), moreOrLessEquals(20, epsilon: .01));
  });
}

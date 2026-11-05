// The day wheel (lib/shared/ui/day_wheel.dart): a bounded one stops at its
// last value (Statistics: no day after today); a looping one comes round.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/day_wheel.dart';

void main() {
  Future<List<int>> spin(WidgetTester t, {required bool loop}) async {
    final got = <int>[];
    var value = 1;
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 56,
            child: StatefulBuilder(
              builder: (context, set) => DayWheel(
                value: value,
                count: 10,
                max: loop ? null : 3,
                loop: loop,
                labelOf: (i) => 'd$i',
                style: const TextStyle(fontSize: 15, color: Colors.white),
                onChanged: (v) => set(() => got.add(value = v)),
              ),
            ),
          ),
        ),
      ),
    );
    // Up a long way: later values come in.
    await t.drag(find.byType(DayWheel), const Offset(0, -300));
    await t.pumpAndSettle();
    return got;
  }

  testWidgets('a bounded wheel stops at its last value', (t) async {
    expect(await spin(t, loop: false), [3]);
    expect(find.text('d4'), findsNothing);
  });

  testWidgets('a looping wheel comes round', (t) async {
    final got = await spin(t, loop: true);
    expect(got, hasLength(1));
    expect(got.single, inInclusiveRange(0, 9));
    expect(got.single, isNot(1));
  });
}

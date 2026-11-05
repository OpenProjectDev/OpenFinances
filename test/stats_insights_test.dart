// "At a glance" (lib/features/stats/stats_insights.dart): the shown
// period's spending, all of the month before, the months before on average
// and every day's; daily figures
// count from the app's first day and never past today.
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/features/stats/stats_insights.dart';

/// Calendar months; offset 0 = October 2026.
(DateTime, DateTime) _month(int k) => (
  DateTime(2026, 10 + k, 1),
  DateTime(2026, 11 + k, 1).subtract(const Duration(seconds: 1)),
);

Map<String, dynamic> _e(int m, int d, int whole) => {
  'occurredAtUtc': DateTime(2026, m, d, 12).toUtc(),
  'amountMinor': whole * 100,
};

void main() {
  final now = DateTime(2026, 10, 10, 9);
  final expenses = [
    _e(8, 3, 200), // August: 250
    _e(8, 20, 50),
    _e(9, 2, 100), // September: 1,000
    _e(9, 5, 300),
    _e(9, 20, 600),
    _e(10, 1, 200), // October so far: 800
    _e(10, 3, 500),
    _e(10, 9, 100),
  ];

  test('the period against all of last month and the average', () {
    final g = computeGlance(
      expenses: expenses,
      offset: 0,
      rangeOf: _month,
      now: now,
      firstUse: DateTime(2026, 8, 1),
    );
    expect(g.spent, 80000);
    expect(g.days, 10); // Oct 1-10, up to today
    expect(g.perDay, 8000);
    expect(g.lastTotal, 100000); // all of September
    expect(g.averageMonths, 2); // August and September
    expect(g.average, 62500); // (250 + 1,000) / 2
    // Every day since Aug 1: 2,050 over 71 days.
    expect(g.overallPerDay, 2900);
  });

  test('a past period: all of it', () {
    final g = computeGlance(
      expenses: expenses,
      offset: -1,
      rangeOf: _month,
      now: now,
      firstUse: DateTime(2026, 8, 1),
    );
    expect(g.spent, 100000);
    expect(g.days, 30);
    expect(g.lastTotal, 25000);
    expect(g.average, 25000);
  });

  test('days start at the first entry; nothing before it to compare', () {
    final g = computeGlance(
      // The app's first entry: the 3rd.
      expenses: [_e(10, 3, 500), _e(10, 9, 100)],
      offset: 0,
      rangeOf: _month,
      now: now,
    );
    expect(g.days, 8); // Oct 3-10
    expect(g.lastTotal, isNull);
    expect(g.average, isNull);
    // Since the 3rd: 600 over 8 days.
    expect(g.overallPerDay, 7500);
  });

  test('a month the app started in partway: last month, not the average', () {
    final g = computeGlance(
      expenses: [_e(9, 20, 600), _e(10, 2, 100)],
      offset: 0,
      rangeOf: _month,
      now: now,
    );
    expect(g.lastTotal, 60000);
    expect(g.average, isNull); // not in use from Sep 1
    // Since Sep 20: 700 over 21 days.
    expect(g.overallPerDay, 3300);
  });

  test(
    'the same day of every period, on average, over days in use (two at least)',
    () {
      final a = sameDayAverages(
        expenses: expenses,
        offset: 0,
        rangeOf: _month,
        now: now,
        firstUse: DateTime(2026, 8, 1),
      );
      expect(a.length, 31); // October's days
      expect(a[0], 6700); // 1st: Aug 0, Sep 0, Oct 200 → 200 / 3
      expect(a[1], 3300); // 2nd: Sep 100 / 3 (whole units)
      expect(a[2], 23300); // 3rd: Aug 200, Oct 500 → 700 / 3
      expect(a[19], 32500); // 20th: Aug 50, Sep 600; Oct's still to come
      expect(a[30], null); // 31st: August's alone (September has 30): one
      // Before the app's first day: not counted.
      final late = sameDayAverages(
        expenses: [
          for (final e in expenses)
            if (!(e['occurredAtUtc'] as DateTime).toLocal().isBefore(
              DateTime(2026, 9, 3),
            ))
              e,
        ],
        offset: 0,
        rangeOf: _month,
        now: now,
        firstUse: DateTime(2026, 9, 3),
      );
      expect(late[0], null); // Sep 1-2 not in use: October's alone, one
      expect(late[2], 25000); // 3rd: Sep 0, Oct 500 → 250
      expect(late[4], 15000); // 5th: Sep 300, Oct 0 → 150
      expect(late[30], null); // no 31st in use
    },
  );

  test('axis numbers: short, and none read alike', () {
    String m(num whole) => shortMoney((whole * 100).round());
    expect(m(0), '0');
    expect(m(500), '500');
    expect(m(1000), '1k');
    expect(m(1500), '1.5k');
    expect(m(2000), '2k');
    expect(m(2500), '2.5k');
    expect(m(1250), '1.25k');
    expect(m(12500), '12.5k');
    expect(m(150000), '150k');
    expect(m(1500000), '1.5m');
    expect(m(1000000000), '1b');
    expect(m(999), '999');
    expect(m(999600), '1m');
    // Every axis there can be: distinct numbers, for any top.
    for (final top in [80, 900, 3000, 7500, 12000, 250000, 4800000]) {
      final step = top / 4;
      final texts = [for (var k = 0; k <= 4; k++) m((k * step).round())];
      expect(texts.toSet().length, 5, reason: '$texts');
    }
  });

  group("the charts' days start from the first entry", () {
    (DateTime, DateTime) september() => _month(-1);
    (DateTime, DateTime) august() => _month(-2);
    (DateTime, DateTime) october() => _month(0);

    test("the first entry's period: its days from that day, none before", () {
      final d = dailyDaysOf(
        expenses: [_e(9, 15, 100), _e(9, 20, 50)],
        shown: september(),
        before: august(),
        firstEntry: DateTime(2026, 9, 15),
        now: now,
      );
      expect(d.days.first, DateTime(2026, 9, 15));
      expect(d.days.length, 16); // the 15th to the 30th
      expect(d.skipped, 14);
      expect(d.current.first, 10000);
      expect(d.current[1], 0);
      expect(d.current[5], 5000);
      expect(d.previous, isEmpty);
      expect(d.beforeDays, isEmpty);
    });

    test('the period after it: all its days, the one before late', () {
      final d = dailyDaysOf(
        expenses: [_e(9, 15, 100), _e(10, 2, 70)],
        shown: october(),
        before: september(),
        firstEntry: DateTime(2026, 9, 15),
        now: now,
      );
      expect(d.days.length, 31);
      expect(d.skipped, 0);
      expect(d.current[1], 7000);
      expect(d.current[9], 0); // today, the 10th
      expect(d.current[10], null); // to come
      expect(d.previous.length, 30);
      expect(d.previous[13], null); // the 14th: before the first entry
      expect(d.previous[14], 10000);
      expect(d.previous[15], 0);
    });

    test('all of it before the first entry: no days at all', () {
      final d = dailyDaysOf(
        expenses: [_e(9, 15, 100)],
        shown: august(),
        before: _month(-3),
        firstEntry: DateTime(2026, 9, 15),
        now: now,
      );
      expect(d.days, isEmpty);
      expect(d.previous, isEmpty);
    });

    test('no entry yet: the period as it is, nothing before it', () {
      final d = dailyDaysOf(
        expenses: const [],
        shown: october(),
        before: september(),
        firstEntry: null,
        now: now,
      );
      expect(d.days.length, 31);
      expect(d.current.first, 0);
      expect(d.previous, isEmpty);
    });
  });
}

// lib/features/stats/stats_insights.dart
// The numbers behind Statistics' "At a glance" (the owner, 2026-10-27: whole
// periods, no ranges): what was spent in the shown period, all of the month
// before, the months before on average, and per day against every day's
// (since the app's first). Daily figures count from the day the app was first used (the
// first entry ever), never from before it, nor past today. Pure: tested in
// test/stats_insights_test.dart.

/// A period's first and last moment (local time), [offset] periods from
/// the current one.
typedef PeriodRangeOf = (DateTime start, DateTime end) Function(int offset);

/// What "At a glance" says about the shown period (expenses only: the
/// owner, 2026-10-27). Amounts in minor units.
class StatsGlance {
  const StatsGlance({
    required this.spent,
    required this.days,
    required this.average,
    required this.averageMonths,
    required this.lastTotal,
    required this.overallPerDay,
  });

  /// Spent in the period.
  final int spent;

  /// The period's days the app was in use (up to today): per-day figures
  /// go by these.
  final int days;

  /// The months before on average, all of each (null: none to measure
  /// by), over [averageMonths] of them: those in use from their first day
  /// and with anything spent in them.
  final int? average;
  final int averageMonths;

  /// All of the month before (null: nothing recorded then).
  final int? lastTotal;

  /// Spent per day, in whole units.
  int get perDay => days == 0 ? 0 : _whole(spent / days);

  /// The spending per day over every day the app was in use, up to today
  /// (whole units; null: no such day).
  final int? overallPerDay;
}

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime a, DateTime b) =>
    // Calendar days (DST-proof: by UTC dates).
    DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Whole units (minor units would show stray decimals).
int _whole(num minor) => (minor / 100).round() * 100;

/// Works out [StatsGlance] for period [offset] (0: the current one), from
/// expense rows (`occurredAtUtc` DateTime, `amountMinor` int). [firstUse]:
/// the day of the first entry ever; null: the first expense's.
/// [minOffset]: the oldest period looked at.
StatsGlance computeGlance({
  required List<Map<String, dynamic>> expenses,
  required int offset,
  required PeriodRangeOf rangeOf,
  required DateTime now,
  DateTime? firstUse,
  int minOffset = -240,
}) {
  var oldest = firstUse ?? now;
  final byDay = <DateTime, int>{};
  for (final e in expenses) {
    final t = (e['occurredAtUtc'] as DateTime).toLocal();
    if (t.isBefore(oldest)) oldest = t;
    final amount = (e['amountMinor'] as int?) ?? 0;
    byDay.update(_date(t), (v) => v + amount, ifAbsent: () => amount);
  }
  final start = _date(oldest); // the app's first day

  /// Spent from [a] to [b] (dates, inclusive), and whether anything was.
  (int, bool) sum(DateTime a, DateTime b) {
    var total = 0;
    var any = false;
    for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) {
      final v = byDay[d];
      if (v != null) {
        total += v;
        any = true;
      }
    }
    return (total, any);
  }

  final (ps, pe) = rangeOf(offset);
  final a = _date(ps), b = _date(pe);
  final spent = sum(a, b).$1;

  // The months before, all of each.
  int? lastTotal;
  var total = 0, months = 0;
  for (var k = offset - 1; k >= minOffset; k--) {
    final (ks, ke) = rangeOf(k);
    final ka = _date(ks), kb = _date(ke);
    if (kb.isBefore(start)) break; // before the app
    final (whole, used) = sum(ka, kb);
    if (!used) continue;
    if (k == offset - 1) lastTotal = whole;
    if (!start.isAfter(ka)) {
      total += whole;
      months++;
    }
  }

  // Days in use: from the app's first day, up to today.
  final first = start.isAfter(a) ? start : a;
  final today = _date(now);
  final last = today.isBefore(b) ? today : b;
  final days = first.isAfter(last) ? 0 : _daysBetween(first, last) + 1;

  // Every day since the app's first, up to today.
  final allDays = start.isAfter(today) ? 0 : _daysBetween(start, today) + 1;
  final allSpent = sum(start, today).$1;

  return StatsGlance(
    spent: spent,
    days: days,
    average: months == 0 ? null : _whole(total / months),
    averageMonths: months,
    lastTotal: lastTotal,
    overallPerDay: allDays == 0 ? null : _whole(allSpent / allDays),
  );
}

/// The daily and pace charts' days: the period shown (each day's spending,
/// null for days to come) and the one before it, from their first days, none
/// of it before [firstEntry] (the owner, 2026-11-03). The period shown starts
/// from that day ([skipped]: the days left out); the one before has nulls up to
/// it, or no days at all if all of it was before. No entry at all ([firstEntry]
/// null): the period shown as it is, nothing on it, none before it.
({
  List<DateTime> days,
  List<int?> current,
  List<DateTime> beforeDays,
  List<int?> previous,
  int skipped,
})
dailyDaysOf({
  required List<Map<String, dynamic>> expenses,
  required (DateTime, DateTime) shown,
  required (DateTime, DateTime) before,
  required DateTime? firstEntry,
  required DateTime now,
}) {
  final today = _date(now);
  List<DateTime> daysOf((DateTime, DateTime) r) => [
    for (
      var d = _date(r.$1);
      !d.isAfter(_date(r.$2));
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
  bool inUse(DateTime d) => firstEntry != null && !d.isBefore(firstEntry);
  final whole = daysOf(shown);
  final days = firstEntry == null ? whole : whole.where(inUse).toList();
  final beforeDays = daysOf(before);
  final byDay = <DateTime, int>{};
  final from = _date(before.$1), to = _date(shown.$2);
  for (final e in expenses) {
    final d = _date((e['occurredAtUtc'] as DateTime).toLocal());
    if (d.isBefore(from) || d.isAfter(to)) continue;
    final amount = (e['amountMinor'] as int?) ?? 0;
    byDay.update(d, (v) => v + amount, ifAbsent: () => amount);
  }
  final anyBefore = beforeDays.any(inUse);
  return (
    days: days,
    current: [for (final d in days) d.isAfter(today) ? null : byDay[d] ?? 0],
    beforeDays: anyBefore ? beforeDays : const <DateTime>[],
    previous: anyBefore
        ? [for (final d in beforeDays) inUse(d) ? byDay[d] ?? 0 : null]
        : const <int?>[],
    skipped: whole.length - days.length,
  );
}

/// An axis number from minor units: short, up to three digits that count, so
/// no two of an axis' round numbers read alike (1,500 was "2k" beside 2,000's:
/// the owner, 2026-11-03). 950, 1.5k, 12.5k, 150k, 1.25m.
String shortMoney(int minor) {
  final major = minor / 100;
  for (final (size, unit) in const [
    (1000000000.0, 'b'),
    (1000000.0, 'm'),
    (1000.0, 'k'),
  ]) {
    // From just under: what would round up to 1000 of the next one down.
    if (major < size * .9995) continue;
    final n = major / size;
    final text = n.toStringAsFixed(n < 10 ? 2 : (n < 100 ? 1 : 0));
    final trimmed = text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
    return '$trimmed$unit';
  }
  return major.round().toString();
}

/// [value] against [reference] in whole percent (positive: more); null
/// when there's no reference to measure by (0).
int? percentAgainst(int value, int reference) =>
    reference > 0 ? ((value - reference) * 100 / reference).round() : null;

/// The daily chart's same-day average (the owner, 2026-11-01: "the 5th of
/// Aban against every 5th"): for each day of period [offset] (its [i]th
/// day), what was spent on the [i]th day of every period, on average, over
/// the periods where that day was in use (from the app's first day,
/// [firstUse] or the first expense's, up to today); null: fewer than two
/// such days (one is just itself: the owner, 2026-11-01). Whole units.
List<int?> sameDayAverages({
  required List<Map<String, dynamic>> expenses,
  required int offset,
  required PeriodRangeOf rangeOf,
  required DateTime now,
  DateTime? firstUse,
  int minOffset = -240,
}) {
  var oldest = firstUse ?? now;
  final byDay = <DateTime, int>{};
  for (final e in expenses) {
    final t = (e['occurredAtUtc'] as DateTime).toLocal();
    if (t.isBefore(oldest)) oldest = t;
    final amount = (e['amountMinor'] as int?) ?? 0;
    byDay.update(_date(t), (v) => v + amount, ifAbsent: () => amount);
  }
  final start = _date(oldest);
  final today = _date(now);
  final (ps, pe) = rangeOf(offset);
  final length = _daysBetween(_date(ps), _date(pe)) + 1;
  final sums = List<int>.filled(length, 0);
  final counts = List<int>.filled(length, 0);
  // Every period up to today's (none after it has a day in use).
  for (var k = 0; k >= minOffset; k--) {
    final (ks, ke) = rangeOf(k);
    final a = _date(ks), b = _date(ke);
    if (b.isBefore(start)) break; // before the app
    for (var i = 0; i < length; i++) {
      final d = DateTime(a.year, a.month, a.day + i);
      if (d.isAfter(b) || d.isAfter(today)) break;
      if (d.isBefore(start)) continue;
      sums[i] += byDay[d] ?? 0;
      counts[i]++;
    }
  }
  return [
    for (var i = 0; i < length; i++)
      counts[i] < 2 ? null : _whole(sums[i] / counts[i]),
  ];
}

// lib/shared/period_range.dart
// The budget period [offset] periods from the current one (0: the current,
// -1: the one before), periods starting on day [startDay] of the month:
// History, Budget and Statistics all ask it.
//
// Months are stepped from their first day: stepping today's date instead
// (the 30th or 31st) into a shorter month gave an impossible Shamsi date
// (a crash) or rolled a Gregorian one into the month after.

import 'package:shamsi_date/shamsi_date.dart' as s;

/// The Shamsi period: its first and last day.
(s.Jalali start, s.Jalali end) jalaliPeriod(
  int offset,
  int startDay, {
  s.Jalali? today,
}) {
  final now = today ?? s.Jalali.now();
  final month = s.Jalali(now.year, now.month, 1).addMonths(offset);

  // Before this month's start day (the last day, in a month too short to
  // have it), the period began the month before.
  final from = now.day >= startDay.clamp(1, now.monthLength)
      ? month
      : month.addMonths(-1);
  final start = s.Jalali(
    from.year,
    from.month,
    startDay.clamp(1, from.monthLength),
  );

  final next = s.Jalali(from.year, from.month, 1).addMonths(1);
  final end = s.Jalali(
    next.year,
    next.month,
    startDay.clamp(1, next.monthLength),
  ).addDays(-1);
  return (start, end);
}

/// The Gregorian period: its first moment and its last second.
(DateTime start, DateTime end) gregorianPeriod(
  int offset,
  int startDay, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final month = DateTime(now.year, now.month + offset, 1);

  final from = now.day >= startDay.clamp(1, _monthLength(now.year, now.month))
      ? month
      : DateTime(month.year, month.month - 1, 1);
  final start = DateTime(
    from.year,
    from.month,
    startDay.clamp(1, _monthLength(from.year, from.month)),
  );

  final next = DateTime(from.year, from.month + 1, 1);
  final end = DateTime(
    next.year,
    next.month,
    startDay.clamp(1, _monthLength(next.year, next.month)),
  ).subtract(const Duration(seconds: 1));
  return (start, end);
}

// In UTC: a clock change can't shorten a month by an hour.
int _monthLength(int year, int month) => DateTime.utc(
  year,
  month + 1,
  1,
).difference(DateTime.utc(year, month, 1)).inDays;

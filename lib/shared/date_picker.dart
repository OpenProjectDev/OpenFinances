import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/date_picker_dialog.dart';

/// Shows the date picker in the user's calendar (Jalali or Gregorian).
/// Returns a local date at midnight, or null if dismissed. [pastOnly]: a date
/// isn't expected in the future; [futureOnly]: nor in the past (it warns; it
/// can still be picked).
Future<DateTime?> pickDateForCalendar({
  required BuildContext context,
  required DateTime initial,
  required AppCalendar calendar,
  bool pastOnly = false,
  bool futureOnly = false,
}) => showAppDatePicker(
  context: context,
  initial: initial,
  calendar: calendar,
  pastOnly: pastOnly,
  futureOnly: futureOnly,
);

/// A date in numbers in [calendar], yyyy/MM/dd unless another order is chosen
/// ([appDateOrder]); Persian digits when [fa] (the UI language).
String formatDateForCalendar(
  DateTime dt,
  AppCalendar calendar, {
  required bool fa,
}) {
  final int year, month, day;
  if (calendar == AppCalendar.jalali) {
    final j = s.Jalali.fromDateTime(dt);
    (year, month, day) = (j.year, j.month, j.day);
  } else {
    (year, month, day) = (dt.year, dt.month, dt.day);
  }
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  final text = switch (appDateOrder) {
    DateOrder.dmy => '$d/$m/$year',
    DateOrder.mdy => '$m/$d/$year',
    DateOrder.ymd || DateOrder.standard => '$year/$m/$d',
  };
  return faDigitsFor(fa) ? toFaDigits(text) : text;
}

/// Same day next month in the user's calendar, clamped to the month's
/// length (e.g. Jalali 6/31 → 7/30, Jan 31 → Feb 28).
DateTime addOneMonthForCalendar(DateTime dt, AppCalendar calendar) {
  if (calendar == AppCalendar.jalali) {
    final j = s.Jalali.fromDateTime(dt);
    final y = j.month == 12 ? j.year + 1 : j.year;
    final m = j.month == 12 ? 1 : j.month + 1;
    final len = s.Jalali(y, m, 1).monthLength;
    return s.Jalali(y, m, j.day > len ? len : j.day).toDateTime();
  }
  final y = dt.month == 12 ? dt.year + 1 : dt.year;
  final m = dt.month == 12 ? 1 : dt.month + 1;
  final len = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, dt.day > len ? len : dt.day);
}

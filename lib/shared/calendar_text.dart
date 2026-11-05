import 'package:flutter/widgets.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/money_input.dart' show toFaDigits;
import 'package:openfinances/shared/digits.dart';

/// Date wording for both calendars in both languages. The calendar decides
/// the dates (Jalali or Gregorian); the app language decides the words and
/// the digits. (Before, Jalali always meant Persian text and digits, so an
/// English UI on the Jalali calendar showed Persian.)

bool isFaUi(BuildContext context) {
  // Whoever asks (to write digits, mostly) follows the digit choice too.
  DigitsScope.watch(context);
  return Localizations.localeOf(context).languageCode == 'fa';
}

/// [text]'s digits as numbers are written: the UI language's ([fa]), or
/// the digits chosen in Settings ([faDigitsFor]).
String uiDigits(String text, bool fa) =>
    faDigitsFor(fa) ? toFaDigits(text) : text;

const _jalaliFa = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', //
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];
const _jalaliEn = [
  'Farvardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar', //
  'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand',
];
const _gregorianFa = [
  'ژانویه', 'فوریه', 'مارس', 'آوریل', 'مه', 'ژوئن', //
  'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر',
];
const _gregorianEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// Indexed by DateTime.weekday - 1 (Monday first).
const _weekdayFa = [
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
  'شنبه',
  'یکشنبه',
];
const _weekdayEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayLetterFa = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];
const _weekdayLetterEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Day of month, month name and year of [d] in [cal].
({int day, String month, int year}) _parts(
  DateTime d,
  AppCalendar cal,
  bool fa,
) {
  if (cal == AppCalendar.jalali) {
    final j = s.Jalali.fromDateTime(d);
    return (
      day: j.day,
      month: (fa ? _jalaliFa : _jalaliEn)[j.month - 1],
      year: j.year,
    );
  }
  return (
    day: d.day,
    month: (fa ? _gregorianFa : _gregorianEn)[d.month - 1],
    year: d.year,
  );
}

/// A date's day and month in the order chosen ([appDateOrder]).
String _dayMonth(({int day, String month, int year}) p) =>
    appDateOrder == DateOrder.mdy || appDateOrder == DateOrder.ymd
    ? '${p.month} ${p.day}'
    : '${p.day} ${p.month}';

/// A whole date in the order chosen.
String _whole(({int day, String month, int year}) p) => switch (appDateOrder) {
  DateOrder.ymd => '${p.year} ${p.month} ${p.day}',
  DateOrder.mdy => '${p.month} ${p.day} ${p.year}',
  DateOrder.dmy || DateOrder.standard => '${p.day} ${p.month} ${p.year}',
};

/// "Sat 25 Mehr" / «شنبه ۲۵ مهر».
String dayTitle(DateTime d, AppCalendar cal, bool fa) {
  final p = _parts(d, cal, fa);
  final wd = (fa ? _weekdayFa : _weekdayEn)[d.weekday - 1];
  return uiDigits('$wd ${_dayMonth(p)}', fa);
}

/// "25 Mehr" / «۲۵ مهر» ([dayTitle] without its weekday, where a row is
/// short of room).
String dayShort(DateTime d, AppCalendar cal, bool fa) {
  return uiDigits(_dayMonth(_parts(d, cal, fa)), fa);
}

/// "25 Mehr 1405" / «۲۵ مهر ۱۴۰۵».
String dayWithYear(DateTime d, AppCalendar cal, bool fa) =>
    uiDigits(_whole(_parts(d, cal, fa)), fa);

/// "1 Mehr 1405 – 30 Mehr 1405".
String rangeText(DateTime start, DateTime end, AppCalendar cal, bool fa) {
  final a = _parts(start, cal, fa);
  final b = _parts(end, cal, fa);
  // The year once when both ends share it (shorter: the picker's bar is one
  // line high; the owner, 2026-10-28), on the end it reads from.
  final String from, to;
  if (a.year != b.year) {
    from = _whole(a);
    to = _whole(b);
  } else if (appDateOrder == DateOrder.ymd) {
    from = _whole(a);
    to = _dayMonth(b);
  } else {
    from = _dayMonth(a);
    to = _whole(b);
  }
  return uiDigits('$from – $to', fa);
}

/// The months' names in [cal], in the UI language.
List<String> monthNames(AppCalendar cal, bool fa) => cal == AppCalendar.jalali
    ? (fa ? _jalaliFa : _jalaliEn)
    : (fa ? _gregorianFa : _gregorianEn);

/// One-letter weekday headers in calendar order: Saturday first for
/// Jalali, Monday first for Gregorian.
List<String> weekdayLetters(AppCalendar cal, bool fa) {
  final letters = fa ? _weekdayLetterFa : _weekdayLetterEn;
  // Monday-first table; Jalali weeks start on Saturday (index 5).
  final start = cal == AppCalendar.jalali ? 5 : 0;
  return [for (var i = 0; i < 7; i++) letters[(start + i) % 7]];
}

/// Text direction for date text in the UI language.
TextDirection uiTextDirection(bool fa) =>
    fa ? TextDirection.rtl : TextDirection.ltr;

import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/period_range.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('Shamsi: the 30th steps into Esfand (29 days) without a crash', () {
    final today = Jalali(1405, 7, 30);
    // 7 months back from Mehr 1405 is Esfand 1404 (29 days).
    final (start, end) = jalaliPeriod(-7, 1, today: today);
    expect(start, Jalali(1404, 12, 1));
    expect(end, Jalali(1404, 12, 29));
  });

  test('Shamsi: a start day past the month end starts on its last day', () {
    // Esfand has 29 days: a period starting on the 30th starts on the 29th.
    final (start, end) = jalaliPeriod(0, 30, today: Jalali(1404, 12, 29));
    expect(start, Jalali(1404, 12, 29));
    expect(end, Jalali(1405, 1, 29));
    // The day before, still the period that began on 30 Bahman.
    final (s2, e2) = jalaliPeriod(0, 30, today: Jalali(1404, 12, 28));
    expect(s2, Jalali(1404, 11, 30));
    expect(e2, Jalali(1404, 12, 28));
  });

  test('Gregorian: the 31st steps back into a 30-day month', () {
    final today = DateTime(2026, 10, 31);
    final (start, end) = gregorianPeriod(-1, 1, today: today);
    expect(start, DateTime(2026, 9, 1));
    expect(end, DateTime(2026, 10, 1).subtract(const Duration(seconds: 1)));
  });

  test('Gregorian: before the start day, the period began last month', () {
    final today = DateTime(2026, 3, 5);
    final (start, _) = gregorianPeriod(0, 10, today: today);
    expect(start, DateTime(2026, 2, 10));
  });
}

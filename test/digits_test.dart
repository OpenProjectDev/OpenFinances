// Digits (lib/shared/digits.dart): English, or Persian when picked (Settings,
// in Persian only); kept in prefs.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/date_picker.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => appDigitStyle = DigitStyle.english);

  test('default: English, whatever the language', () {
    appDigitStyle = DigitStyle.english;
    expect(uiDigits('12,300', true), '12,300');
    expect(uiDigits('12,300', false), '12,300');
  });

  test('Persian when in effect, everywhere', () {
    appDigitStyle = DigitStyle.persian;
    expect(uiDigits('2026', false), '۲۰۲۶');
    expect(uiDigits('2026', true), '۲۰۲۶');
    expect(faDigitsFor(false), isTrue);
  });

  test('English in English; the choice comes back with Persian', () async {
    SharedPreferences.setMockInitialValues({'digits': 'persian'});
    final sp = SettingsProvider();
    await sp.ready;
    expect(sp.digitStyle, DigitStyle.persian);
    await sp.setLocale(const Locale('en'));
    expect(sp.digitStyle, DigitStyle.english);
    expect(appDigitStyle, DigitStyle.english);
    expect(sp.fontFamily, 'ManropeNum');
    await sp.setLocale(const Locale('fa'));
    expect(sp.digitStyle, DigitStyle.persian);
    expect(sp.fontFamily, 'VazirNum');
    // Started in English with Persian picked: the same.
    SharedPreferences.setMockInitialValues({
      'digits': 'persian',
      'locale': 'en',
    });
    final again = SettingsProvider();
    await again.ready;
    expect(again.digitStyle, DigitStyle.english);
  });

  test(
    'the date order: as always by default; kept; each writes its way',
    () async {
      final d = DateTime(2026, 11, 3);
      addTearDown(() => appDateOrder = DateOrder.standard);
      SharedPreferences.setMockInitialValues({'locale': 'en'});
      final sp = SettingsProvider();
      await sp.ready;
      expect(sp.dateOrder, DateOrder.standard);
      String words() => dayWithYear(d, AppCalendar.gregorian, false);
      String short() => dayShort(d, AppCalendar.gregorian, false);
      String nums() =>
          formatDateForCalendar(d, AppCalendar.gregorian, fa: false);
      String range() => rangeText(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 30),
        AppCalendar.gregorian,
        false,
      );
      expect(words(), '3 Nov 2026');
      expect(short(), '3 Nov');
      expect(nums(), '2026/11/03');
      expect(range(), '1 Nov – 30 Nov 2026');

      await sp.setDateOrder(DateOrder.dmy);
      expect(nums(), '03/11/2026');
      expect(words(), '3 Nov 2026');

      await sp.setDateOrder(DateOrder.mdy);
      expect(nums(), '11/03/2026');
      expect(words(), 'Nov 3 2026');
      expect(short(), 'Nov 3');
      expect(range(), 'Nov 1 – Nov 30 2026');

      await sp.setDateOrder(DateOrder.ymd);
      expect(nums(), '2026/11/03');
      expect(words(), '2026 Nov 3');
      expect(range(), '2026 Nov 1 – Nov 30');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dateOrder'), 'ymd');
      appDateOrder = DateOrder.standard;
      final again = SettingsProvider();
      await again.ready;
      expect(again.dateOrder, DateOrder.ymd);
    },
  );

  test(
    'turning tips on also brings back hints and "never show again"',
    () async {
      SharedPreferences.setMockInitialValues({});
      final sp = SettingsProvider();
      await sp.ready;
      await sp.markScrollLearned('chipsRow');
      await sp.markNeverShown('date.future');
      await sp.markTipSeen('add');
      expect(sp.neverShown('date.future'), isTrue);
      // Turned off, nothing comes back.
      await sp.setTipsOn(false);
      expect(sp.scrollLearned('chipsRow'), isTrue);
      expect(sp.neverShown('date.future'), isTrue);

      await sp.setTipsOn(true);
      expect(sp.tipSeen('add'), isFalse);
      expect(sp.scrollLearned('chipsRow'), isFalse);
      expect(sp.neverShown('date.future'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('neverShownV1'), isNull);
      expect(prefs.getStringList('scrollLearnedV1'), isNull);
    },
  );

  test('kept in prefs; read back on start; an old "auto" is English', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = SettingsProvider();
    await sp.ready;
    expect(sp.digitStyle, DigitStyle.english);
    await sp.setDigitStyle(DigitStyle.persian);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('digits'), 'persian');

    appDigitStyle = DigitStyle.english;
    SharedPreferences.setMockInitialValues({'digits': 'persian'});
    final again = SettingsProvider();
    await again.ready;
    expect(again.digitStyle, DigitStyle.persian);
    expect(appDigitStyle, DigitStyle.persian);

    appDigitStyle = DigitStyle.persian;
    SharedPreferences.setMockInitialValues({'digits': 'auto'});
    final old = SettingsProvider();
    await old.ready;
    expect(old.digitStyle, DigitStyle.english);
  });
}

// The app's date picker (the owner, 2026-11-02): the button shows and returns
// the day picked, Cancel returns nothing; where a date isn't expected in the
// future, one that is warns (and can still be confirmed); Jalali months have
// their own lengths; the months swipe and step; a year can be jumped to.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart' show AppCalendar;
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/date_picker_dialog.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

void main() {
  final warning = lookupAppLocalizations(const Locale('en')).futureDateWarning;
  final cancel = lookupAppLocalizations(const Locale('en')).cancel;
  final pastWarning = lookupAppLocalizations(
    const Locale('en'),
  ).pastDateWarning;
  final confirm = find.byKey(const ValueKey('datePicker.confirm'));

  Future<void> open(
    WidgetTester t, {
    required DateTime initial,
    required void Function(DateTime?) done,
    AppCalendar calendar = AppCalendar.gregorian,
    bool pastOnly = false,
    bool futureOnly = false,
    double width = 412,
    double text = 1,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(text)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => done(
                  await showAppDatePicker(
                    context: context,
                    initial: initial,
                    calendar: calendar,
                    pastOnly: pastOnly,
                    futureOnly: futureOnly,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  testWidgets('the button shows and returns the day picked', (t) async {
    DateTime? got;
    await open(t, initial: DateTime(2026, 3, 10), done: (d) => got = d);
    expect(
      find.descendant(of: confirm, matching: find.text('10 Mar 2026')),
      findsOneWidget,
    );
    await t.tap(find.text('21'));
    await t.pump(const Duration(milliseconds: 200));
    expect(
      find.descendant(of: confirm, matching: find.text('21 Mar 2026')),
      findsOneWidget,
    );
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(got, DateTime(2026, 3, 21));
  });

  testWidgets('Cancel returns nothing', (t) async {
    DateTime? got = DateTime(2000);
    await open(t, initial: DateTime(2026, 3, 10), done: (d) => got = d);
    await t.tap(find.text(cancel));
    await t.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('a future day warns where none is expected, and still confirms', (
    t,
  ) async {
    DateTime? got;
    final future = DateTime(today.year + 1, 3, 10);
    await open(t, initial: future, pastOnly: true, done: (d) => got = d);
    expect(find.text(warning), findsOneWidget);
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(got, future);
  });

  testWidgets('a past day warns where the future is expected, and confirms', (
    t,
  ) async {
    DateTime? got;
    final past = DateTime(today.year - 1, 3, 10);
    await open(t, initial: past, futureOnly: true, done: (d) => got = d);
    expect(find.text(pastWarning), findsOneWidget);
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(got, past);
  });

  testWidgets('a future day is fine where the future is expected', (t) async {
    await open(
      t,
      initial: DateTime(today.year + 1, 3, 10),
      futureOnly: true,
      done: (_) {},
    );
    expect(find.text(pastWarning), findsNothing);
    expect(find.text(warning), findsNothing);
  });

  testWidgets('the warning is one chip, its button nested', (t) async {
    await open(
      t,
      initial: DateTime(today.year + 1, 3, 10),
      pastOnly: true,
      done: (_) {},
    );
    final never = find.text(
      lookupAppLocalizations(const Locale('en')).neverWarn,
    );
    expect(never, findsOneWidget);
    final chip = find.byKey(const ValueKey('datePicker.warning'));
    // At least as tall as the button (the test font is wider than ours, so the
    // words take more lines here).
    expect(
      t.getSize(chip).height,
      greaterThanOrEqualTo(t.getSize(confirm).height),
    );
    // The words and the button are both inside the one chip.
    final box = t.getRect(chip);
    expect(box.contains(t.getCenter(never)), isTrue);
    expect(box.contains(t.getCenter(find.text(warning))), isTrue);
  });

  testWidgets('a day picked is a true square, not its cell\'s shape', (
    t,
  ) async {
    final day = DateTime(today.year, today.month, 15);
    await open(t, initial: day, done: (_) {});
    final box = find
        .ancestor(of: find.text('15'), matching: find.byType(AnimatedContainer))
        .first;
    final size = t.getSize(box);
    expect(size.width, size.height);
  });

  testWidgets('no warning for a past day, or where the future is fine', (
    t,
  ) async {
    await open(
      t,
      initial: DateTime(today.year - 1, 3, 10),
      pastOnly: true,
      done: (_) {},
    );
    expect(find.text(warning), findsNothing);
    await t.tap(find.text(cancel));
    await t.pumpAndSettle();
    await open(t, initial: DateTime(today.year + 1, 3, 10), done: (_) {});
    expect(find.text(warning), findsNothing);
  });

  testWidgets('Jalali: its own month lengths and the day it returns', (
    t,
  ) async {
    DateTime? got;
    // Mehr 1405 has 30 days; Shahrivar's 31 aren't in it.
    await open(
      t,
      initial: s.Jalali(1405, 7, 5).toDateTime(),
      calendar: AppCalendar.jalali,
      done: (d) => got = d,
    );
    expect(find.text('Mehr'), findsOneWidget);
    expect(find.text('1405'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('31'), findsNothing);
    await t.tap(find.text('30'));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(got, s.Jalali(1405, 7, 30).toDateTime());
  });

  testWidgets('the months swipe', (t) async {
    await open(t, initial: DateTime(2026, 3, 10), done: (_) {});
    await t.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await t.pumpAndSettle();
    expect(find.text('Apr'), findsOneWidget);
  });

  testWidgets('the year chip opens years, the month chip months', (t) async {
    DateTime? got;
    await open(t, initial: DateTime(2026, 3, 10), done: (d) => got = d);
    await t.tap(find.text('2026'));
    await t.pumpAndSettle();
    await t.tap(find.text('2024'));
    await t.pumpAndSettle();
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('Mar'), findsOneWidget);
    await t.tap(find.text('Mar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Jul'));
    await t.pumpAndSettle();
    expect(find.text('Jul'), findsOneWidget);
    await t.tap(find.text('15'));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(got, DateTime(2024, 7, 15));
  });

  testWidgets('Today goes to today and picks it', (t) async {
    DateTime? got;
    final today_ = lookupAppLocalizations(const Locale('en')).today;
    await open(t, initial: DateTime(2020, 3, 10), done: (d) => got = d);
    await t.tap(find.text(today_));
    await t.pumpAndSettle();
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(got, today);
  });

  testWidgets('fits a narrow phone with large text', (t) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = old);
    await open(
      t,
      initial: DateTime(today.year + 1, 3, 10),
      pastOnly: true,
      width: 320,
      text: 1.5,
      done: (_) {},
    );
    expect(errors, isEmpty);
  });
}

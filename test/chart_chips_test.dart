// The daily and pace charts' chips (the owner, 2026-11-01): a tap turns a
// series off and on, one area always stays on (trying says so), and the
// daily average's line doesn't count as one.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/features/stats/daily_area_chart.dart';
import 'package:openfinances/features/stats/pace_chart.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/app_notice.dart';

final _keepOne = lookupAppLocalizations(const Locale('en')).chartKeepOne;

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    ...AppLocalizations.localizationsDelegates,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Color _chip(WidgetTester t, String label) {
  final box = t.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pump(const Duration(milliseconds: 400));
}

/// The notice saying so is up; it's closed for the next step.
Future<void> _expectRefused(WidgetTester t) async {
  expect(find.text(_keepOne), findsOneWidget);
  AppNotice.dismiss();
  await t.pump();
}

void main() {
  testWidgets('pace: the last chip on stays on', (t) async {
    await t.pumpWidget(
      _app(
        PaceChart(
          current: const [100, 200, null],
          previous: const [50, 100, 150],
          sameDay: const [null, null, null],
          average: 60,
          dateOf: (i) => '$i',
          number: (m) => '$m',
          amount: (m) => '$m',
          labels: const {
            PaceSeries.current: 'now',
            PaceSeries.previous: 'before',
            PaceSeries.sameDay: 'same',
            PaceSeries.average: 'avg',
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final nowOn = _chip(t, 'now'), beforeOn = _chip(t, 'before');
    await _tap(t, 'now');
    expect(_chip(t, 'now'), isNot(nowOn));
    expect(find.text(_keepOne), findsNothing);
    await _tap(t, 'before'); // the only one on
    expect(_chip(t, 'before'), beforeOn);
    await _expectRefused(t);
    await _tap(t, 'now');
    expect(_chip(t, 'now'), nowOn);
    await _tap(t, 'before');
    expect(_chip(t, 'before'), isNot(beforeOn));
    // The line goes off and on freely, and isn't the one that stays on.
    final avgOn = _chip(t, 'avg');
    await _tap(t, 'avg');
    expect(_chip(t, 'avg'), isNot(avgOn));
    await _tap(t, 'avg');
    expect(_chip(t, 'avg'), avgOn);
    await _tap(t, 'now'); // the last area, the line on too
    expect(_chip(t, 'now'), nowOn);
    await _expectRefused(t);
    // No data for the same days' average: its chip stays, and a tap says why.
    expect(find.text('same'), findsOneWidget);
    final noData = lookupAppLocalizations(
      const Locale('en'),
    ).statsNotEnoughData;
    await _tap(t, 'same');
    expect(find.text(noData), findsOneWidget);
    AppNotice.dismiss();
    await t.pump();
  });

  testWidgets('daily: the last chip on stays on', (t) async {
    await t.pumpWidget(
      _app(
        DailyAreaChart(
          current: const [100, 0, 300, null, null, null, null],
          previous: const [50, 100, 0, 200, 100, 50, 20],
          sameDay: const [70, 60, null, 100, 90, 80, 10],
          average: 80,
          today: 2,
          dayLabel: (i) => '${i + 1}',
          dateOf: (i) => '$i',
          number: (m) => '$m',
          amount: (m) => '$m',
          labels: const {
            DailySeries.current: 'now',
            DailySeries.previous: 'before',
            DailySeries.sameDay: 'same',
            DailySeries.average: 'avg',
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final avgOn = _chip(t, 'avg'), sameOn = _chip(t, 'same');
    await _tap(t, 'now');
    await _tap(t, 'before');
    expect(find.text(_keepOne), findsNothing);
    // The last area stays on, though the average's line is on too.
    await _tap(t, 'same');
    expect(_chip(t, 'same'), sameOn);
    await _expectRefused(t);
    // The line goes off and on freely, with one area on.
    await _tap(t, 'avg');
    expect(_chip(t, 'avg'), isNot(avgOn));
    expect(find.text(_keepOne), findsNothing);
    await _tap(t, 'avg');
    expect(_chip(t, 'avg'), avgOn);
  });

  testWidgets('daily: another period is in place in the frame showing it', (
    t,
  ) async {
    Widget chart(int today, String first) => _app(
      DailyAreaChart(
        current: const [100, 0, 300, 50, 60, 70, 80, 90, 10, 20],
        previous: const [50, 100, 0, 200, 100, 50, 20, 10, 5, 1],
        sameDay: const [70, 60, 50, 40, 30, 20, 10, 5, 4, 3],
        average: 80,
        today: today,
        dayLabel: (i) => '${i + 1}',
        dateOf: (i) => '$first$i',
        number: (m) => '$m',
        amount: (m) => '$m',
        labels: const {
          DailySeries.current: 'now',
          DailySeries.previous: 'before',
          DailySeries.sameDay: 'same',
          DailySeries.average: 'avg',
        },
      ),
    );
    ScrollPosition days() => t
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(DailyAreaChart),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    await t.pumpWidget(chart(8, 'a'));
    await t.pumpAndSettle();
    expect(days().pixels, greaterThan(0)); // on today, far along
    await t.pumpWidget(chart(-1, 'b')); // ONE frame
    expect(days().pixels, 0);
  });

  // It opened easing up from a placeholder scale, every amount millions of
  // pixels off: walking the edges' dots on those frames froze the app.
  {
    testWidgets('daily opens at its scale at once', (t) async {
      final clock = Stopwatch()..start();
      await t.pumpWidget(
        _app(
          DailyAreaChart(
            current: const [
              120000,
              60000,
              240000,
              0,
              90000,
              310000,
              150000,
              70000,
            ],
            previous: const [
              90000,
              200000,
              110000,
              160000,
              280000,
              70000,
              0,
              190000,
            ],
            sameDay: const [
              130000,
              140000,
              170000,
              120000,
              180000,
              160000,
              90000,
              130000,
            ],
            average: 140000,
            today: 7, // far along: the view jumps there on opening
            dayLabel: (i) => '${i + 1}',
            dateOf: (i) => '$i',
            number: (m) => '$m',
            amount: (m) => '$m',
            labels: const {
              DailySeries.current: 'now',
              DailySeries.previous: 'before',
              DailySeries.sameDay: 'same',
              DailySeries.average: 'avg',
            },
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 16));
      // Nothing left easing: its scale was set, not started toward.
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(clock.elapsed.inSeconds, lessThan(5));
    });
  }

  testWidgets('pace: the axis fits the lines, top and bottom, and moves', (
    t,
  ) async {
    Widget chart() => _app(
      PaceChart(
        current: const [5100, 5400, 6000, null],
        previous: const [5000, 5200, 5900, 7000],
        sameDay: const [null, null, null, null],
        average: null,
        dateOf: (i) => '$i',
        number: (m) => '$m',
        amount: (m) => '$m',
        labels: const {
          PaceSeries.current: 'now',
          PaceSeries.previous: 'before',
          PaceSeries.sameDay: 'same',
          PaceSeries.average: 'avg',
        },
      ),
    );
    await t.pumpWidget(chart());
    await t.pumpAndSettle();
    // From the lines' own lowest to their highest; round ones between.
    expect(find.text('5000'), findsOneWidget);
    expect(find.text('7000'), findsOneWidget);
    expect(find.text('6000'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    // Without that line, the rest's: no number they don't reach.
    await _tap(t, 'before');
    await t.pumpAndSettle();
    expect(find.text('5100'), findsOneWidget);
    expect(find.text('6000'), findsOneWidget);
    expect(find.text('5000'), findsNothing);
    expect(find.text('7000'), findsNothing);
  });
}

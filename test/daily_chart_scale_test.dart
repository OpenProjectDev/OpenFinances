// The daily chart over days with nothing (the owner, 2026-11-03: with two series
// on, reaching a stretch of 5+ empty days froze the app for good; easing from one
// lagged badly). The scale fell to almost nothing there, every amount elsewhere
// then stood millions of pixels off, and the dotted edges walked those curves.
// A regression here HANGS the test rather than failing it.
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/features/stats/daily_area_chart.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';

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

Widget _chart(
  List<int?> current,
  List<int?> previous, {
  int today = -1,
  int? average,
}) => DailyAreaChart(
  current: current,
  previous: previous,
  sameDay: const [],
  average: average,
  today: today,
  dayLabel: (i) => 'd$i',
  dateOf: (i) => 'date $i',
  number: (m) => '$m',
  amount: (m) => '$m',
  labels: const {
    DailySeries.current: 'This',
    DailySeries.previous: 'Last',
    DailySeries.sameDay: 'Same',
    DailySeries.average: 'Average',
  },
);

/// A phone's width: five days in view, 60 or so apart.
void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(412, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// [days] of nothing between two stretches of big amounts.
List<int?> _gapped(int amount, {int days = 12}) => [
  for (var i = 0; i < 6; i++) amount,
  for (var i = 0; i < days; i++) 0,
  for (var i = 0; i < 6; i++) amount,
];

/// The axis' numbers now (the texts that parse as numbers).
Set<String> _axis(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => int.tryParse(s) != null)
    .toSet();

/// What [paintEdgeDots] draws.
class _DotsCanvas implements Canvas {
  final dots = <Offset>[];

  @override
  void drawRawPoints(PointMode mode, Float32List points, Paint paint) {
    for (var i = 0; i + 1 < points.length; i += 2) {
      dots.add(Offset(points[i], points[i + 1]));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('two series: over the empty days the scale stays', (t) async {
    _phone(t);
    await t.pumpWidget(
      _app(_chart(_gapped(90000000000), _gapped(40000000000))),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final before = _axis(t);
    expect(before, isNotEmpty);

    // Into the empty days (days 6 to 17; the view all inside them): nothing
    // eases, and no frame hangs.
    final view = find.byType(SingleChildScrollView).last;
    final controller = t.widget<SingleChildScrollView>(view).controller!;
    final pitch =
        t.getCenter(find.text('d1')).dx - t.getCenter(find.text('d0')).dx;
    controller.jumpTo(8 * pitch);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 500));
    expect(_axis(t), before);

    // And out to the data again.
    controller.jumpTo(controller.position.maxScrollExtent);
    await t.pump();
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(_axis(t), isNotEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('a very small day beside huge ones paints as quickly', (t) async {
    // The scale for the small day; the huge ones just out of view stand a
    // billion times over it.
    _phone(t);
    final current = <int?>[
      for (var i = 0; i < 8; i++) 900000000000000,
      for (var i = 0; i < 8; i++) 900,
      for (var i = 0; i < 8; i++) 900000000000000,
    ];
    await t.pumpWidget(_app(_chart(current, [...current])));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final view = find.byType(SingleChildScrollView).last;
    final controller = t.widget<SingleChildScrollView>(view).controller!;
    final pitch =
        t.getCenter(find.text('d1')).dx - t.getCenter(find.text('d0')).dx;
    final clock = Stopwatch()..start();
    controller.jumpTo(9 * pitch);
    await t.pump();
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    clock.stop();
    expect(t.takeException(), isNull);
    expect(clock.elapsedMilliseconds, lessThan(2000));
  });

  testWidgets('opening on empty days fits the whole period', (t) async {
    _phone(t);
    await t.pumpWidget(
      _app(_chart(_gapped(90000000000), _gapped(40000000000), today: 12)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(
      _axis(t).map(int.parse).reduce((a, b) => a > b ? a : b),
      greaterThan(1000),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('no days of the first period before the first entry paint', (
    t,
  ) async {
    // Starting with a day alone: it's still drawn, and nothing throws.
    await t.pumpWidget(_app(_chart(const [5000, null, null], const [])));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    expect(find.text('d0'), findsOneWidget);
    expect(find.text('d2'), findsOneWidget);
  });

  test('the dots run along the edge, only where something covers it', () {
    // The edge level at 100; the cover's top 150 from x 100 to 200, so the
    // edge is over it, uncovered, then the cover rising to 50 covers it.
    const edge = [Offset(0, 100), Offset(300, 100)];
    const cover = [Offset(100, 150), Offset(200, 150), Offset(300, 50)];
    final canvas = _DotsCanvas();
    paintEdgeDots(canvas, const [edge], const [cover], Colors.red);
    expect(canvas.dots, isNotEmpty);
    for (final d in canvas.dots) {
      expect(d.dy, closeTo(100, .001));
      // Past where the cover's curve reaches the edge's height (halfway from
      // 200 to 300, by its symmetry).
      expect(d.dx, greaterThanOrEqualTo(249));
      expect(d.dx, lessThanOrEqualTo(300));
    }
    // Evenly, close together.
    final xs = canvas.dots.map((d) => d.dx).toList()..sort();
    for (var i = 0; i + 1 < xs.length; i++) {
      expect(xs[i + 1] - xs[i], closeTo(2.2, .3));
    }
  });

  test('the dots stop at the top: however high the edge, few of them', () {
    const edge = [Offset(0, 100), Offset(60, -360), Offset(120, 100)];
    const cover = [Offset(0, 0), Offset(120, 0)];
    final canvas = _DotsCanvas();
    paintEdgeDots(canvas, const [edge], const [cover], Colors.red);
    expect(canvas.dots.every((d) => d.dy >= 0), isTrue);
  });
}

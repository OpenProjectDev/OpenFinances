// About's bug (the owner, 2026-11-03): glitches once, 700 to 2200 ms after it
// comes into view, then never again until it has been out of view and back; how
// long it lasts and how fast it goes are random, its speed never even.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/glitch_icon.dart';

/// A 1x1 white PNG.
final _png = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/'
    'PchI7wAAAABJRU5ErkJggg==',
  ),
);

Widget _page(ScrollController scroll, {bool ticking = true}) => MaterialApp(
  home: Scaffold(
    body: TickerMode(
      enabled: ticking,
      child: ListView(
        controller: scroll,
        children: [
          GlitchIcon(_png, size: 40, color: Colors.white),
          const SizedBox(height: 5000),
        ],
      ),
    ),
  ),
);

bool _glitching(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((p) => p.painter is GlitchPainter);

/// Pumps [ms] in small steps; how many glitches started, and when the first did.
Future<(int, int?)> _watch(WidgetTester t, int ms) async {
  const step = 10;
  var starts = 0;
  int? first;
  var was = _glitching(t);
  for (var at = 0; at < ms; at += step) {
    await t.pump(const Duration(milliseconds: step));
    final now = _glitching(t);
    if (now && !was) {
      starts++;
      first ??= at + step;
    }
    was = now;
  }
  return (starts, first);
}

Future<void> _load(WidgetTester t) async {
  await t.runAsync(
    () => precacheImage(_png, t.element(find.byType(GlitchIcon))),
  );
  await t.pump();
}

/// What a glitch draws, and where.
class _Canvas implements Canvas {
  final at = <Rect>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      at.add(dst);

  @override
  void drawRect(Rect rect, Paint paint) => at.add(rect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('it stays in its chip, for About\'s bug', (t) async {
    // 54 in a 68 chip, its ink .64 of that: 7 either side of the file. The
    // ink's own bands may slip; what's off the ink never leaves the chip.
    final image = (await t.runAsync(
      () => createTestImage(width: 4, height: 4),
    ))!;
    const size = Size.square(54);
    const inkLeft = 54 * .18, inkRight = 54 - inkLeft;
    for (var seed = 0; seed < 300; seed++) {
      final beats = glitchBeats(math.Random(seed));
      for (var i = 0; i < beats.length; i++) {
        final canvas = _Canvas();
        GlitchPainter(
          image: image,
          color: Colors.white,
          ink: .64,
          beats: beats,
          beat: ValueNotifier(i),
          seed: seed,
        ).paint(canvas, size);
        for (final r in canvas.at) {
          // The whole file (ink and its margins), moved: its ink stays inside.
          if (r.width == 54) {
            expect(r.left + inkLeft, greaterThanOrEqualTo(-7));
            expect(r.left + inkRight, lessThanOrEqualTo(61));
          } else {
            expect(r.left, greaterThanOrEqualTo(-7), reason: '$r');
            expect(r.right, lessThanOrEqualTo(61), reason: '$r');
          }
        }
      }
    }
  });

  testWidgets('in view: once, in its time, then never', (t) async {
    final scroll = ScrollController();
    await t.pumpWidget(_page(scroll));
    await _load(t);
    final (starts, first) = await _watch(t, 12000);
    expect(starts, 1);
    // The wait, plus up to one look to notice it's in view.
    expect(first, greaterThanOrEqualTo(kGlitchWaitMin));
    expect(first, lessThanOrEqualTo(kGlitchWaitMax + 200));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('out of view and back: once more', (t) async {
    final scroll = ScrollController();
    await t.pumpWidget(_page(scroll));
    await _load(t);
    expect((await _watch(t, 4000)).$1, 1);

    scroll.jumpTo(2000);
    await t.pump();
    expect((await _watch(t, 3000)).$1, 0, reason: 'out of view');

    scroll.jumpTo(0);
    await t.pump();
    expect((await _watch(t, 3000)).$1, 1, reason: 'back in view');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('leaving before its time: no glitch, a new wait', (t) async {
    final scroll = ScrollController();
    await t.pumpWidget(_page(scroll));
    await _load(t);
    await _watch(t, 300);
    scroll.jumpTo(2000);
    await t.pump();
    expect((await _watch(t, 3000)).$1, 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a hidden tab (no tickers) is out of view', (t) async {
    final scroll = ScrollController();
    await t.pumpWidget(_page(scroll, ticking: false));
    await _load(t);
    expect((await _watch(t, 3000)).$1, 0);
    await t.pumpWidget(_page(scroll));
    await t.pump();
    expect((await _watch(t, 3000)).$1, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a page over it is out of view', (t) async {
    final scroll = ScrollController();
    await t.pumpWidget(_page(scroll));
    await _load(t);
    expect((await _watch(t, 4000)).$1, 1);
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(builder: (_) => const SizedBox()));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 300));
    nav.pop();
    await t.pumpAndSettle();
    expect((await _watch(t, 3000)).$1, 1, reason: 'back from the page');
    await t.pumpWidget(const SizedBox());
  });

  test('its length is random, between its limits', () {
    final lengths = <int>{};
    for (var seed = 0; seed < 300; seed++) {
      final beats = glitchBeats(math.Random(seed));
      final total = beats.fold<int>(0, (a, b) => a + b.ms);
      expect(total, inInclusiveRange(kGlitchPlayMin, kGlitchPlayMax));
      lengths.add(total);
    }
    expect(lengths.length, greaterThan(100));
  });

  test('its speed runs up and slows down, every time', () {
    for (var seed = 0; seed < 2000; seed++) {
      final beats = glitchBeats(math.Random(seed));
      final torn = [
        for (final b in beats.take(beats.length - 1))
          if (b.bands > 0) b.ms,
      ];
      expect(torn.length, greaterThan(3), reason: 'seed $seed');
      expect(torn.reduce(math.max), lessThanOrEqualTo(kGlitchHoldMax));
      // Never one even pace: quick moments and slow ones in every glitch, and
      // both getting quicker and getting slower.
      expect(torn.where((ms) => ms <= 24), isNotEmpty, reason: 'seed $seed');
      expect(torn.where((ms) => ms >= 35), isNotEmpty, reason: 'seed $seed');
      var faster = false, slower = false;
      for (var i = 0; i + 1 < torn.length; i++) {
        if (torn[i + 1] < torn[i] - 5) faster = true;
        if (torn[i + 1] > torn[i] + 5) slower = true;
      }
      expect(faster && slower, isTrue, reason: 'seed $seed: $torn');
    }
  });

  test('it ends on a small twitch', () {
    for (var seed = 0; seed < 100; seed++) {
      final last = glitchBeats(math.Random(seed)).last;
      expect(last.bands, lessThanOrEqualTo(3));
      expect(last.bits, 0);
    }
  });
}

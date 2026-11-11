// A regression guard (developer, 2026-11-11: «چهارشنبه» in the Now box sat
// "way lower than center"): text drawn with the app's real fonts, in both
// orders of the font list (Persian digits put VazirNum first, English
// digits ManropeNum), must have its ink in the middle of its box.
//
// The cause was InkMetrics's line middle: under InkText's strut it read the
// line's ascent and descent, which are the letters' own fonts', while the
// strut's font places the baseline. Persian words sat 2.5 dp low with
// ManropeNum first, Latin 2.5 high with VazirNum first.
//
// "In the middle" here: halfway between the ink's bounds' middle and its
// weight's, within a dp and a quarter (texts sit by their font's shared
// band). Words with descenders ("Wednesday") or a Persian word with no tall
// letter («توضیح») aren't checked: by the band they keep the baseline the
// words beside them have, their tails hanging.
//
// Ported from OpenTracker (its test/regressions/ink_center_test.dart,
// 2026-11-11), which found the bug in the code it had taken from here.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/ink_text.dart';

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _loadAppFonts() async {
  const m = 'assets/fonts/manrope';
  const d = 'assets/fonts/digits';
  await _load('Manrope', [
    for (final w in [300, 400, 500, 600, 700, 800]) '$m/Manrope-$w.ttf',
  ]);
  await _load('ManropeNum', [
    for (final w in [200, 300, 400, 500, 600, 700]) '$d/ManropeNum-$w.ttf',
  ]);
  await _load('VazirNum', [
    for (final w in [200, 300, 400, 500, 600, 700]) '$d/VazirNum-$w.ttf',
  ]);
  await _load('Shabnam', [
    'assets/fonts/shabnam/Shabnam-Light.ttf',
    'assets/fonts/shabnam/Shabnam-Medium.ttf',
    'assets/fonts/shabnam/Shabnam-Bold.ttf',
  ]);
}

/// How far (dp, down positive) the ink of [key]'s picture sits from its
/// middle: halfway between its bounds' middle and its weight's.
Future<double> _inkOffCenter(WidgetTester tester, Key key) async {
  const ratio = 4.0;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final img = (await tester.runAsync(() => ro.toImage(pixelRatio: ratio)))!;
  final data = (await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final b = data.buffer.asUint8List();
  int? top, bottom;
  var w = 0.0, m = 0.0;
  for (var y = 0; y < img.height; y++) {
    var row = 0;
    for (var x = 0; x < img.width; x++) {
      row += 255 - b[(y * img.width + x) * 4]; // black ink on white
    }
    if (row < 255 * 2) continue;
    top ??= y;
    bottom = y;
    w += row;
    m += row * (y + .5);
  }
  final h = img.height / ratio;
  final bounds = (top! + bottom! + 1) / 2 / ratio - h / 2;
  final mass = m / w / ratio - h / 2;
  img.dispose();
  return (bounds + mass) / 2;
}

void main() {
  setUpAll(_loadAppFonts);

  const orders = {
    'VazirNum first': ['VazirNum', 'ManropeNum', 'Manrope', 'Shabnam'],
    'ManropeNum first': ['ManropeNum', 'VazirNum', 'Manrope', 'Shabnam'],
  };
  const sizes = [
    (12.5, FontWeight.w400),
    (14.0, FontWeight.w600),
    (16.0, FontWeight.w700),
  ];
  const level = [
    'چهارشنبه',
    'شنبه',
    'هزینه',
    'بازیابی',
    'آبان',
    '۱۴۰۵',
    '۲۰',
    '2026',
    '20',
    'Hello',
    'Restore',
  ];

  for (final MapEntry(key: order, value: fonts) in orders.entries) {
    for (final (size, weight) in sizes) {
      {
        for (final text in level) {
          testWidgets('$order, $size w${weight.value}: "$text" centered', (
            tester,
          ) async {
            final style = TextStyle(
              fontFamily: fonts.first,
              fontFamilyFallback: fonts.sublist(1),
              fontSize: size,
              fontWeight: weight,
              color: Colors.black,
            );
            await tester.runAsync(() => InkMetrics.instance.prepare(style));
            const key = ValueKey('box');
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.rtl,
                child: Center(
                  child: RepaintBoundary(
                    key: key,
                    child: Container(
                      width: 200,
                      height: 40,
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: InkText(
                        text,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                  ),
                ),
              ),
            );
            final off = await _inkOffCenter(tester, key);
            // The band is the font's, not the word's: a quarter dp over one.
            expect(
              off.abs(),
              lessThanOrEqualTo(1.25),
              reason: '"$text" is ${off.toStringAsFixed(2)} dp off center',
            );
          });
        }
      }
    }
  }
}

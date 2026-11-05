// test/ink_text_test.dart
// Text is centered by its font's band, not by each word's own letters: one
// font and size, one line ("Budget", its «g» dipping, sat higher than "Desc"
// beside it; the owner, 2026-10-26).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/ink_text.dart';

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  const style = TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: ['Shabnam'],
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  setUpAll(() async {
    await _font('Shabnam', [
      'assets/fonts/shabnam/Shabnam-Light.ttf',
      'assets/fonts/shabnam/Shabnam-Medium.ttf',
      'assets/fonts/shabnam/Shabnam-Bold.ttf',
    ]);
    await _font('ManropeNum', ['assets/fonts/digits/ManropeNum-200.ttf']);
    await _font('VazirNum', ['assets/fonts/digits/VazirNum-200.ttf']);
    await _font('Manrope', ['assets/fonts/manrope/Manrope-600.ttf']);
  });

  testWidgets('words in one font and size share a line', (t) async {
    await t.runAsync(() => InkMetrics.instance.prepare(style));
    double dy(String s) =>
        InkMetrics.instance.offset(s, style, TextScaler.noScaling);
    // Measured (a font not measured moves nothing).
    expect(dy('Budget'), isNot(0));
    expect(dy('Budget'), closeTo(dy('Desc'), .01));
    expect(dy('Manage'), closeTo(dy('Desc'), .01));
    // Signs alone still go by their own ink.
    expect(dy('+'), isNot(closeTo(dy('Desc'), .01)));
  });
}

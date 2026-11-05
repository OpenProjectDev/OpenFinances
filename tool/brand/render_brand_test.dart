// Renders the brand's images with the app's own drawing code (BrandMark,
// BrandLockup's mark size), so the launcher icon, the splash and the app match exactly.
// Run through tool/make_brand_icons.py (it sizes and places the results):
//   flutter test tool/brand/render_brand_test.dart --update-goldens
// Writes build/brand/*.png (transparent where nothing is drawn).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/brand_mark.dart';
import 'package:openfinances/app/branding_screen.dart';

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  setUpAll(() async {
    await _font('Manrope', [
      'assets/fonts/manrope/Manrope-400.ttf',
      'assets/fonts/manrope/Manrope-500.ttf',
      'assets/fonts/manrope/Manrope-600.ttf',
      'assets/fonts/manrope/Manrope-700.ttf',
      'assets/fonts/manrope/Manrope-800.ttf',
    ]);
  });

  Future<void> render(
    WidgetTester t,
    String name,
    double logical,
    double ratio,
    Widget child,
  ) async {
    t.view.physicalSize = Size.square(logical * ratio);
    t.view.devicePixelRatio = ratio;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );
    // The whole view, in physical pixels.
    await expectLater(
      find.byType(Directionality).first,
      matchesGoldenFile('../../build/brand/$name.png'),
    );
  }

  testWidgets('brand', (t) async {
    // The mark (launcher icons, web): 1024 px.
    await render(t, 'mark', 1024, 1, const BrandMark(size: 1024));
    // Adaptive icon foreground: the leaf in the 72 of 108 dp safe zone.
    await render(
      t,
      'foreground',
      1024,
      1,
      const BrandMark(size: 1024, plate: BrandPlate.none, leafScale: .66),
    );
    // Play Store: full square plate.
    await render(
      t,
      'playstore',
      1024,
      1,
      const BrandMark(size: 1024, plate: BrandPlate.square),
    );
    // Android 12+ splash icon: 288 dp at 4 px a dp, the mark alone at the
    // middle (as the branding screen's first frame).
    await render(t, 'splash', 288, 4, const BrandMark(size: BrandLockup.kMark));
  });
}

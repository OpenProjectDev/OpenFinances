// Boxes show whole and show that they scroll by moving (the owner,
// 2026-10-31): one whose content goes on, until a box of its kind has been
// scrolled by hand, scrolls a little and back once in view; one that fits
// doesn't; scrolled by hand once, the kind never does it again (kept in
// prefs, so in full backups).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a box that scrolls shows it until scrolled by hand', (t) async {
    SharedPreferences.setMockInitialValues({});
    late SettingsProvider sp;
    await t.runAsync(() async {
      sp = SettingsProvider();
      await sp.ready;
    });

    Widget box(int rows, {Key? key}) => ChangeNotifierProvider.value(
      value: sp,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: key,
              height: 200,
              child: HintedScroll(
                id: ScrollHint.categoryChips,
                builder: (context, scroll) => ListView(
                  controller: scroll,
                  children: [
                    for (var i = 0; i < rows; i++)
                      SizedBox(height: 50, child: Text('row $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    double offset() =>
        t.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

    // It fits: it stays.
    await t.pumpWidget(box(3));
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 400));
    expect(offset(), 0);

    // It goes on: a moment after it shows, a little on, then back.
    await t.pumpWidget(box(10, key: const ValueKey(1)));
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 380));
    expect(offset(), greaterThan(20));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(offset(), 0);
    expect(sp.scrollLearned(ScrollHint.categoryChips), isFalse);

    // Scrolled by hand: learned, and saved.
    await t.drag(find.byType(ListView), const Offset(0, -60));
    await t.pumpAndSettle();
    expect(sp.scrollLearned(ScrollHint.categoryChips), isTrue);
    await t.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('scrollLearnedV1'), [
        ScrollHint.categoryChips,
      ]);
    });

    // A new box of that kind: still.
    await t.pumpWidget(box(10, key: const ValueKey(2)));
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 380));
    expect(offset(), 0);
    await t.pumpAndSettle();
  });
}

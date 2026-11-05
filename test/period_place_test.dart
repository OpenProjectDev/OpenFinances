// Changing the period leaves the page where it is (the owner, 2026-11-01):
// the section being read stays put when one above it changes height, a
// period too short holds as far as it can and the place comes back after it,
// and so does a list that's gone for a period. All of it in the very frame
// that shows the new period (a frame later is a flicker: the owner): each
// check here pumps ONE frame.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/period_place.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A page whose first section is [above]`(period)` tall; the second section,
/// [below]`(period)` tall (0: none, the page is short).
Widget _sections(
  SettingsProvider sp,
  RememberedScroll c,
  double Function(int) above,
  double Function(int) below,
) => MaterialApp(
  home: ChangeNotifierProvider.value(
    value: sp,
    child: Scaffold(
      body: Consumer<SettingsProvider>(
        builder: (context, s, _) => PeriodPlace(
          controller: c,
          child: SingleChildScrollView(
            controller: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FoldSection(
                  id: 'test.above',
                  title: 'above',
                  initiallyOpen: true,
                  child: SizedBox(height: above(s.periodOffset)),
                ),
                FoldSection(
                  id: 'test.read',
                  title: 'read',
                  initiallyOpen: true,
                  child: SizedBox(height: below(s.periodOffset)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

/// A plain list of [countOf]`(period)` rows; none: no list at all.
Widget _list(
  SettingsProvider sp,
  RememberedScroll c,
  int Function(int) countOf,
) => MaterialApp(
  home: ChangeNotifierProvider.value(
    value: sp,
    child: Scaffold(
      body: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          final n = countOf(s.periodOffset);
          return PeriodPlace(
            controller: c,
            child: n == 0
                ? const Center(child: Text('nothing'))
                : ListView.builder(
                    controller: c,
                    itemCount: n,
                    itemExtent: 50,
                    itemBuilder: (_, i) => Text('row $i'),
                  ),
          );
        },
      ),
    ),
  ),
);

void main() {
  late SettingsProvider sp;

  Future<void> make(WidgetTester t) => t.runAsync(() async {
    SharedPreferences.setMockInitialValues({'rememberScroll': false});
    sp = SettingsProvider();
    await sp.ready;
  });

  Future<void> period(WidgetTester t, int offset) async {
    sp.setPeriodOffset(offset);
    await t.pump();
  }

  double topOf(WidgetTester t, String title) =>
      t.getTopLeft(find.text(title)).dy;

  testWidgets('the section read stays put when one above changes height', (
    t,
  ) async {
    await make(t);
    final c = RememberedScroll('test', sp);
    addTearDown(c.dispose);
    await t.pumpWidget(
      _sections(sp, c, (p) => p == 0 ? 1000 : 700, (_) => 1500),
    );
    await t.pump();
    c.jumpTo(1050);
    await t.pump();
    final before = topOf(t, 'read');
    await period(t, -1);
    expect(topOf(t, 'read'), closeTo(before, .5));
    await period(t, 0);
    expect(topOf(t, 'read'), closeTo(before, .5));
    expect(c.offset, closeTo(1050, .5));
  });

  testWidgets('at the very top it stays at the top', (t) async {
    await make(t);
    final c = RememberedScroll('test', sp);
    addTearDown(c.dispose);
    await t.pumpWidget(
      _sections(sp, c, (p) => p == 0 ? 1000 : 700, (_) => 1500),
    );
    await t.pump();
    await period(t, -1);
    expect(c.offset, 0);
  });

  testWidgets('a short period holds, the place comes back after it', (t) async {
    await make(t);
    final c = RememberedScroll('test', sp);
    addTearDown(c.dispose);
    await t.pumpWidget(_list(sp, c, (p) => p == -1 ? 16 : 100));
    await t.pump();
    c.jumpTo(3000);
    await t.pump();
    await period(t, -1);
    expect(c.offset, c.position.maxScrollExtent);
    expect(c.offset, lessThan(3000));
    await period(t, -2);
    expect(c.offset, closeTo(3000, .5));
  });

  testWidgets('moved during a short period: that is the place now', (t) async {
    await make(t);
    final c = RememberedScroll('test', sp);
    addTearDown(c.dispose);
    await t.pumpWidget(_list(sp, c, (p) => p == -1 ? 16 : 100));
    await t.pump();
    c.jumpTo(3000);
    await t.pump();
    await period(t, -1);
    c.jumpTo(40);
    await t.pump();
    await period(t, 0);
    expect(c.offset, closeTo(40, .5));
  });

  testWidgets('a list gone for a period comes back to its place', (t) async {
    await make(t);
    final c = RememberedScroll('test', sp);
    addTearDown(c.dispose);
    await t.pumpWidget(_list(sp, c, (p) => p == -1 ? 0 : 100));
    await t.pump();
    c.jumpTo(2000);
    await t.pump();
    await period(t, -1);
    expect(c.hasClients, isFalse);
    await period(t, 0);
    expect(c.offset, closeTo(2000, .5));
  });
}

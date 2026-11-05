// Tips (lib/shared/ui/tips.dart): off by default; on, each shows once, by what
// it's about, in order, only while that's in view. Any touch sends it away and
// still reaches the page; the page is never blurred or moved.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/tips.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _l = lookupAppLocalizations(const Locale('en'));

/// The tip's card (by its label: a long tip is laid out word by word).
Finder _tip(String text) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == text);

Widget _app(SettingsProvider sp, Widget child) => ChangeNotifierProvider.value(
  value: sp,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

/// Long enough for the page to look again.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<SettingsProvider> _sp({bool on = true}) async {
  SharedPreferences.setMockInitialValues({'tipsOn': on, 'locale': 'en'});
  final sp = SettingsProvider();
  await sp.ready;
  return sp;
}

void main() {
  final a = GlobalKey(), b = GlobalKey();
  final tips = [
    Tip('history.period', [a], (l) => l.tipPeriod),
    Tip('history.cards', [b], (l) => l.tipCards),
  ];
  Widget page({VoidCallback? onTap}) => TipsTrigger(
    tips: () => tips,
    child: Column(
      children: [
        SizedBox(key: a, height: 50, child: const Text('A')),
        GestureDetector(
          onTap: onTap,
          child: SizedBox(key: b, height: 50, child: const Text('B')),
        ),
      ],
    ),
  );

  testWidgets('off: nothing shows', (t) async {
    await t.pumpWidget(_app(await _sp(on: false), page()));
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsNothing);
  });

  testWidgets('on: each once, in order, then remembered', (t) async {
    final sp = await _sp();
    await t.pumpWidget(_app(sp, page()));
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsOneWidget);
    expect(_tip(_l.tipCards), findsNothing, reason: 'one at a time');

    await t.tap(find.text('A'));
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsNothing);
    expect(_tip(_l.tipCards), findsOneWidget);

    await t.tap(find.text('A'));
    await _settle(t);
    expect(_tip(_l.tipCards), findsNothing);
    expect(sp.tipSeen('history.period'), isTrue);
    expect(sp.tipSeen('history.cards'), isTrue);

    // Remembered: a new page shows none.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app(sp, page()));
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('it leaves the page alone: a touch goes through, no blur', (
    t,
  ) async {
    var tapped = 0;
    final sp = await _sp();
    await t.pumpWidget(_app(sp, page(onTap: () => tapped++)));
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is BackdropFilter && w.filter is ImageFilter,
      ),
      findsNothing,
    );
    await t.tap(find.text('B'));
    await t.pump();
    expect(tapped, 1, reason: 'the page got the tap');
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('it waits for what it\'s about to come into view', (t) async {
    t.view.physicalSize = const Size(400, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final later = GlobalKey();
    final scroll = ScrollController();
    final sp = await _sp();
    await t.pumpWidget(
      _app(
        sp,
        TipsTrigger(
          tips: () => [
            Tip('history.tiles', [later], (l) => l.tipTiles),
          ],
          child: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 2000),
              SizedBox(key: later, height: 50, child: const Text('later')),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await _settle(t);
    expect(_tip(_l.tipTiles), findsNothing);
    expect(scroll.offset, 0, reason: 'the page is never moved for a tip');
    scroll.jumpTo(1800);
    await _settle(t);
    expect(_tip(_l.tipTiles), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a tip about the page shows without a target', (t) async {
    final sp = await _sp();
    await t.pumpWidget(
      _app(
        sp,
        TipsTrigger(
          tips: () => [Tip('history.welcome', const [], (l) => l.tipWelcome)],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await _settle(t);
    expect(_tip(_l.tipWelcome), findsOneWidget);
    // A small card in the middle, not the screen's height; on a Material, so
    // with the theme's text.
    final word = find.textContaining('Welcome');
    final card = find
        .ancestor(of: word, matching: find.byType(DecoratedBox))
        .first;
    expect(t.getSize(card).height, lessThan(300));
    expect(
      find.ancestor(of: word, matching: find.byType(Material)),
      findsWidgets,
    );
    final style = DefaultTextStyle.of(t.element(word)).style;
    expect(style.decoration, isNot(TextDecoration.underline));
    await t.pumpWidget(const SizedBox());
  });

  test('no line of a tip ends in a period, a comma or the like', () {
    expect(
      tipLines(['Tap a section, ', 'tap again.', 'یک ردیف،', 'یکی؛', 'Hi!']),
      'Tap a section\ntap again\nیک ردیف\nیکی\nHi!',
    );
    expect(tipLines(['one, two. three']), 'one, two. three');
  });

  testWidgets('a tip\'s text is centered, its target left untinted', (t) async {
    final sp = await _sp();
    await t.pumpWidget(_app(sp, page()));
    await _settle(t);
    final text = find.textContaining('Data is shown');
    expect(t.widget<Text>(text).textAlign, TextAlign.center);
    // The target's own place is painted by nothing of the tip's: just its card.
    final boxes = t
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(Overlay).first,
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((d) => (d.decoration as BoxDecoration).color != null)
        .where((d) => (d.decoration as BoxDecoration).borderRadius != null)
        .where(
          (d) =>
              (d.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(14),
        );
    expect(boxes, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a point toward each of its targets; one there: just it', (
    t,
  ) async {
    final left = GlobalKey(), right = GlobalKey();
    final sp = await _sp();
    await t.pumpWidget(
      _app(
        sp,
        TipsTrigger(
          tips: () => [
            Tip('history.cards', [left, right], (l) => l.tipCards),
          ],
          child: Row(
            children: [
              Expanded(child: SizedBox(key: left, height: 50)),
              Expanded(child: SizedBox(key: right, height: 50)),
            ],
          ),
        ),
      ),
    );
    await _settle(t);
    Iterable<RenderBox> points() => t.renderObjectList<RenderBox>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_Point',
      ),
    );
    expect(points().length, 2);
    final xs = points().map((b) => b.localToGlobal(Offset.zero).dx).toList()
      ..sort();
    expect(xs[1], greaterThan(xs[0] + 50), reason: 'apart, one to each');
    await t.pumpWidget(const SizedBox());

    // A filtered History has one card: one point, the tip not held back.
    SharedPreferences.setMockInitialValues({'tipsOn': true});
    final sp2 = await _sp();
    await t.pumpWidget(
      _app(
        sp2,
        TipsTrigger(
          tips: () => [
            Tip('history.cards', [left, right], (l) => l.tipCards),
          ],
          child: Row(
            children: [Expanded(child: SizedBox(key: left, height: 50))],
          ),
        ),
      ),
    );
    await _settle(t);
    expect(points().length, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('its card is solid', (t) async {
    final sp = await _sp();
    await t.pumpWidget(_app(sp, page()));
    await _settle(t);
    final card = t.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.textContaining('Data is shown'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((card.decoration as BoxDecoration).color!.a, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('none under a sheet or on a hidden tab', (t) async {
    final sp = await _sp();
    await t.pumpWidget(_app(sp, TickerMode(enabled: false, child: page())));
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsNothing, reason: 'hidden tab');

    await t.pumpWidget(_app(sp, page()));
    await t.pump();
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => const SizedBox(),
      ),
    );
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsNothing, reason: 'under a sheet');
    nav.pop();
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('all seen: tips turn themselves off', (t) async {
    final sp = await _sp();
    for (final id in kTipIds.skip(1)) {
      await sp.markTipSeen(id);
    }
    await t.pumpWidget(
      _app(
        sp,
        TipsTrigger(
          tips: () => [
            Tip(kTipIds.first, [a], (l) => l.tipPeriod),
          ],
          child: SizedBox(key: a, height: 50, child: const Text('A')),
        ),
      ),
    );
    await _settle(t);
    expect(_tip(_l.tipPeriod), findsOneWidget);
    await t.tap(find.text('A'));
    await _settle(t);
    expect(sp.tipsOn, isFalse);
    await t.pumpWidget(const SizedBox());
  });
}

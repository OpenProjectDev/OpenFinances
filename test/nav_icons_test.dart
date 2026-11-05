import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';

void main() {
  // A page with its own bar ("+" adding something else) pushed and popped:
  // the "+" below takes over (and tilts) without building during the
  // teardown ("setState() called when widget tree was locked").
  testWidgets('the "+" below takes over cleanly when a page is popped', (
    t,
  ) async {
    Widget page(AddSheet adds) => Scaffold(
      body: Center(
        child: AddNavIcon(
          adds: adds,
          color: Colors.blue,
          plusColor: Colors.black,
          size: 64,
        ),
      ),
    );
    await t.pumpWidget(MaterialApp(home: page(AddSheet.entry)));
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => page(AddSheet.category)));
    await t.pumpAndSettle();
    nav.pop();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  // The bar lays out on phones of any width and with a system inset (a "+"
  // box shorter than the bar once broke layout: the app never drew).
  for (final width in [320.0, 412.0, 600.0]) {
    testWidgets('the bottom bar lays out at $width dp', (t) async {
      t.view.physicalSize = Size(width * 3, 800 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
            child: Scaffold(
              bottomNavigationBar: AppBottomBar(
                selected: 0,
                onTab: (_) {},
                onAdd: () {},
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(AddNavIcon), findsOneWidget);
    });
  }

  // The plus tilts only when the SHEET the "+" opens changes (an expense and
  // an income are one sheet): Settings' "+" and the SMS tab's (showing
  // income) are the same, no tilt between them.
  testWidgets('the plus tilts only when the sheet changes', (t) async {
    Widget plus(AddSheet adds, Color color) => MaterialApp(
      home: Center(
        child: AddNavIcon(
          adds: adds,
          color: color,
          plusColor: Colors.black,
          size: 64,
        ),
      ),
    );
    await t.pumpWidget(plus(AddSheet.entry, Colors.blue));
    await t.pumpAndSettle();
    // Same sheet, the bar rebuilt (another page of the main page).
    await t.pumpWidget(plus(AddSheet.entry, Colors.green));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    // Another sheet: it tilts.
    await t.pumpWidget(plus(AddSheet.debt, Colors.green));
    await t.pump();
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
  });

  // A page with its own bar pushed over the main page's: both "+"s are
  // there at once, and the main one is still there after the pop (one key
  // in both bars once moved it out of the main bar: it vanished).
  testWidgets('a pushed bar leaves the main bar its "+"', (t) async {
    Widget bar({bool main = false}) => Scaffold(
      bottomNavigationBar: AppBottomBar(
        selected: 0,
        onTab: (_) {},
        onAdd: () {},
        tipTarget: main,
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: bar(main: true),
      ),
    );
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => bar()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    expect(find.byType(AddNavIcon), findsNWidgets(2));
    await t.pumpAndSettle();
    nav.pop();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(AddNavIcon), findsOneWidget);
    expect(AppBottomBar.addTipKey.currentContext, isNotNull);
  });
}

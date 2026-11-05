// History's calendar reads the list at a line (the owner, 2026-10-31): at
// the list's top until its last screen, then running down to its last row,
// so the last days (too short to scroll up to the top) get the frame by
// scrolling too; a day picked is scrolled to where that line meets it, so a
// nudge of the list doesn't move the frame to the day before.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/features/expenses/day_strip.dart';
import 'package:openfinances/features/expenses/expenses_page.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Six days inside this month's period whatever the date (the 2nd to the
  // 7th; later ones are listed too): "n days before" the newest.
  final now = DateTime.now();
  DateTime daysAgo(int n) => DateTime(now.year, now.month, 7 - n);
  final today = daysAgo(0);

  testWidgets('the frame reaches the last days and stays on a day picked', (
    t,
  ) async {
    t.view.physicalSize = const Size(384 * 3, 832 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    late SettingsProvider sp;
    late ExpenseProvider ep;
    late IncomeProvider ip;
    await t.runAsync(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await AppDb.instance.open(path: inMemoryDatabasePath);
      SharedPreferences.setMockInitialValues({
        'locale': 'en',
        'calendar': 'gregorian',
        'startDay': 1,
      });
      sp = SettingsProvider();
      await sp.ready;
      ep = ExpenseProvider();
      ip = IncomeProvider();
      await ep.init();
      await ip.init();
      // Today and three days before it, three rows each; then two short
      // days at the list's end (two rows, then one).
      for (final (ago, n) in [(0, 3), (1, 3), (2, 3), (3, 3), (4, 2), (5, 1)]) {
        for (var i = 0; i < n; i++) {
          await ep.addExpense(
            title: 'day $ago #$i',
            amountMinor: 100 + i,
            occurredLocal: daysAgo(ago).add(Duration(hours: 9 + i)),
          );
        }
      }
    });
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('openfinances/bank_notifications'),
      (c) async => c.method == 'readLog' ? [] : null,
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sp),
          ChangeNotifierProvider.value(value: ep),
          ChangeNotifierProvider.value(value: ip),
          ChangeNotifierProvider(create: (_) => UpcomingProvider()),
          ChangeNotifierProvider(create: (_) => DebtProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExpensesPage(),
        ),
      ),
    );
    Future<void> settle([int n = 20]) async {
      for (var i = 0; i < n; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    await settle();
    final l = lookupAppLocalizations(const Locale('en'));
    await t.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == l.calendarJump,
      ),
    );
    await settle();

    HistoryCalendar cal() => t.widget(find.byType(HistoryCalendar));
    final sc = t.widget<ListView>(find.byType(ListView).first).controller!;
    Future<void> scrollTo(double o) async {
      sc.jumpTo(o.clamp(0, sc.position.maxScrollExtent));
      await t.pump();
      await t.pump();
    }

    // Opened at the list's top: today.
    expect(cal().selected, today);
    expect(cal().whole, isTrue);

    // A touch outside it (the list's margin): folded to its week.
    final listBox = t.getRect(find.byType(ListView).first);
    await t.tapAt(Offset(listBox.left + 3, listBox.top + 40));
    await settle(20);
    expect(cal().whole, isFalse);
    expect(find.byType(BottomSheet), findsNothing);
    expect(sc.position.maxScrollExtent, greaterThan(200));

    // The last day picked: the list can't bring it to the top; it stays
    // framed, nudged.
    cal().onPick(daysAgo(5));
    await settle(30);
    expect(cal().selected, daysAgo(5));
    await scrollTo(sc.offset - 3);
    expect(cal().selected, daysAgo(5));

    // The day before it, the same (nudged toward it; back down to the
    // end, the line, at the last day, has the frame).
    cal().onPick(daysAgo(4));
    await settle(30);
    expect(cal().selected, daysAgo(4));
    await scrollTo(sc.offset - 4);
    expect(cal().selected, daysAgo(4));
    await scrollTo(sc.position.maxScrollExtent);
    expect(cal().selected, daysAgo(5));

    // Scrolled by hand: the top is today, the end the last day.
    await scrollTo(0);
    expect(cal().selected, today);
    await scrollTo(sc.position.maxScrollExtent);
    expect(cal().selected, daysAgo(5));

    // A day picked starts right under the calendar wherever it can come
    // up that far (the long days here can), else the list is at its end
    // (never further: the owner, 2026-10-31). It's framed, and stays so
    // nudged toward it.
    final rowsOf = {0: 3, 1: 3, 2: 3, 3: 3, 4: 2, 5: 1};
    final listTop = t.getTopLeft(find.byType(ListView).first).dy;
    // The day's first row (the newest entered).
    double firstRowTop(int ago) =>
        t.getTopLeft(find.text('day $ago #${rowsOf[ago]! - 1}')).dy - listTop;
    await scrollTo(0);
    final atTop = firstRowTop(0);
    for (var ago = 0; ago <= 5; ago++) {
      cal().onPick(daysAgo(ago));
      await settle(30);
      final top = firstRowTop(ago);
      final atEnd = sc.offset >= sc.position.maxScrollExtent - .5;
      if (ago <= 3) {
        expect((top - atTop).abs(), lessThan(.5), reason: 'day $ago');
      } else {
        expect(atEnd && top > atTop, isTrue, reason: 'day $ago');
      }
      expect(cal().selected, daysAgo(ago));
      for (final d in atEnd ? [-3.0] : [-3.0, 3.0]) {
        final at = sc.offset;
        await scrollTo(at + d);
        expect(cal().selected, daysAgo(ago), reason: 'day $ago nudged $d');
        await scrollTo(at);
      }
    }

    // The last day, then the one before it (in view already, as high as
    // it gets): the list stays where it is.
    cal().onPick(daysAgo(5));
    await settle(30);
    final end = sc.offset;
    cal().onPick(daysAgo(4));
    await settle(30);
    expect(sc.offset, end);
    expect(cal().selected, daysAgo(4));
    // Up toward it: still it; then the line reaches it and goes on.
    await scrollTo(sc.offset - 3);
    expect(cal().selected, daysAgo(4));

    // A day far off (not built yet): the list glides there, never a jump
    // in one frame (the owner, 2026-11-01: it flashed there).
    await scrollTo(sc.position.maxScrollExtent);
    cal().onPick(daysAgo(0));
    var last = sc.offset, step = 0.0;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
      step = (sc.offset - last).abs() > step ? (sc.offset - last).abs() : step;
      last = sc.offset;
    }
    expect(sc.offset, 0);
    expect(step, lessThan(200));

    // On the way down to it, the days come in order.
    final seen = <DateTime>[];
    for (var o = 0.0; o <= sc.position.maxScrollExtent; o += 4) {
      await scrollTo(o);
      final d = cal().selected!;
      if (seen.isEmpty || seen.last != d) seen.add(d);
    }
    expect(seen, [for (var i = 0; i <= 5; i++) daysAgo(i)]);
    await t.pumpAndSettle();

    // The home icon: the list's top first, the calendar last: it folds, then
    // closes (the owner, 2026-11-02).
    await scrollTo(200);
    mainTabReselected.value++;
    await settle(40);
    expect(sc.offset, 0);
    expect(cal().whole, isFalse); // still its week: the top came first
    mainTabReselected.value++;
    await settle(40);
    expect(find.byType(HistoryCalendar), findsNothing);
    await t.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == l.calendarJump,
      ),
    );
    await settle();
    expect(cal().whole, isTrue);
    mainTabReselected.value++;
    await settle();
    expect(cal().whole, isFalse);
    mainTabReselected.value++;
    await settle(40);
    expect(find.byType(HistoryCalendar), findsNothing);
    await t.pumpAndSettle();
  });
}

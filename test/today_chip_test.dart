// History's today chip lights up once the newest day's last row has wholly
// left the list's top, measured AFTER layout: measured when the scroll
// notified (before layout), the step that pushed the row out still saw it in
// view, and the chip stayed off at the bottom one time in two (the owner,
// 2026-10-25, with screenshots).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/features/expenses/expenses_page.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Gregorian months from the 1st: today and two earlier days in one
  // period (from the 3rd on).
  final now = DateTime.now();

  testWidgets(
    'the step that pushes the row out lights the chip',
    (t) async {
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
        // Nothing today: the newest day is yesterday (one row, the anchor),
        // then enough older rows to scroll.
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        await ep.addExpense(
          title: 'newest',
          amountMinor: 100,
          occurredLocal: yesterday,
        );
        for (var i = 0; i < 8; i++) {
          await ep.addExpense(
            title: 'older $i',
            amountMinor: 100,
            occurredLocal: yesterday.subtract(Duration(days: 1, minutes: i)),
          );
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
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      bool lit() {
        final c = t.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey('today')),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final bg = (c.decoration as BoxDecoration).color;
        return bg ==
            Theme.of(t.element(find.byType(ExpensesPage))).colorScheme.primary;
      }

      final list = t.widget<ListView>(find.byType(ListView).first);
      final sc = list.controller!;
      // The anchor row: the newest day's (its Padding holds the GlobalKey).
      final anchor = find.byWidgetPredicate(
        (w) => w is Padding && w.key is GlobalKey,
      );
      final listTop = t.getTopLeft(find.byType(ListView).first).dy;
      final bottom = t.getBottomLeft(anchor.first).dy - listTop;
      expect(lit(), isFalse);

      // Two pixels of it in view, then the step that pushes it out.
      sc.jumpTo(bottom - 2);
      await t.pump();
      await t.pump();
      expect(lit(), isFalse);
      sc.jumpTo(bottom + 1);
      await t.pump();
      await t.pump();
      expect(lit(), isTrue);

      // And back: a pixel of it in view again.
      sc.jumpTo(bottom - 1);
      await t.pump();
      await t.pump();
      expect(lit(), isFalse);
      await t.pumpAndSettle();
    },
    skip: now.day < 3, // yesterday in last month's period
  );
}

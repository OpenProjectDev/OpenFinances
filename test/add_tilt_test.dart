// The "+" tilts only when the sheet it opens changes, on the real main page:
// across main tabs and Expenses sub-tabs (it once lagged a step behind the
// sub-tab, and tilted between pages that open the same sheet).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/main_page.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('the "+" tilts exactly when its sheet changes', (t) async {
    t.view.physicalSize = const Size(412 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('openfinances/app'),
      (c) async => '1',
    );
    m.setMockMethodCallHandler(
      const MethodChannel('openfinances/bank_notifications'),
      (c) async => switch (c.method) {
        'hasAccess' => true,
        'canPostNotifications' => true,
        'readLog' => [],
        'listFormats' => [],
        _ => null,
      },
    );
    late SettingsProvider sp;
    await t.runAsync(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await AppDb.instance.open(path: inMemoryDatabasePath);
      SharedPreferences.setMockInitialValues({
        'tabUpcoming': true,
        'tabDebts': true,
        'tabSms': true,
      });
      sp = SettingsProvider();
      await sp.ready;
    });
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sp),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()..init()),
          ChangeNotifierProvider(create: (_) => IncomeProvider()..init()),
          ChangeNotifierProvider(create: (_) => UpcomingProvider()..init()),
          ChangeNotifierProvider(create: (_) => DebtProvider()..init()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainPage(),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<int> step(String what, void Function() go) async {
      final before = AddNavIcon.debugTilts;
      go();
      await settle();
      final n = AddNavIcon.debugTilts - before;
      return n;
    }

    await settle();
    // [tilts]: 1 when the sheet changes, 0 when it stays the same.
    for (final (what, go, tilts) in <(String, void Function(), int)>[
      ('home (history) -> settings', () => mainTab.value = 3, 0),
      ('settings -> home (history)', () => mainTab.value = 0, 0),
      (
        'history -> upcoming',
        () => expensesSubTabRequest.value = 'incoming',
        1,
      ),
      ('upcoming -> settings', () => mainTab.value = 3, 1),
      ('settings -> home (upcoming)', () => mainTab.value = 0, 1),
      ('upcoming -> debts', () => expensesSubTabRequest.value = 'debts', 1),
      ('debts -> sms', () => expensesSubTabRequest.value = 'sms', 1),
      ('sms -> settings', () => mainTab.value = 3, 0),
      ('settings -> home (sms)', () => mainTab.value = 0, 0),
    ]) {
      expect(await step(what, go), tilts, reason: what);
    }
  });
}

// tool/render_check_template.dart
// A render check of real screens with the sample data, without running the
// app (the owner tests on the phone; no emulators):
//   1. python tool/make_sample_backup.py --today YYYY-MM-DD   (→ build/sample_backup)
//   2. copy this file to test/zz_render_test.dart and write the checks at
//      the end of main() (an example is there);
//   3. flutter test test/zz_render_test.dart --update-goldens
//      → build/r_<name>.png at 3 px a dp (crop / measure them with PIL);
//   4. delete test/zz_render_test.dart and build/r_*.png before committing.
// Notes: asset images need t.runAsync(delay) + pump to show (the Telegram
// icon often doesn't); shadows render as black rims; call
// InkMetrics.instance.prepare(style) in t.runAsync first so text is
// centered as on the phone. A screen-size sweep is in tool/screen_sweep_template.dart.
// It's a test once copied into test/; here the analyzer doesn't know that.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/features/expenses/expenses_page.dart';
import 'package:openfinances/features/settings/settings_page.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<Map<String, dynamic>> _list(Object? v) =>
    List<Map<String, dynamic>>.from((v as List?) ?? const []);

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  late SettingsProvider sp;
  late ExpenseProvider ep;
  late IncomeProvider ip;
  late UpcomingProvider up;
  late DebtProvider dp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
    await _font('Shabnam', [
      'assets/fonts/shabnam/Shabnam-Light.ttf',
      'assets/fonts/shabnam/Shabnam-Medium.ttf',
      'assets/fonts/shabnam/Shabnam-Bold.ttf',
    ]);
    await _font('ManropeNum', ['assets/fonts/digits/ManropeNum-200.ttf']);
    await _font('VazirNum', ['assets/fonts/digits/VazirNum-200.ttf']);
    await _font('Manrope', [
      'assets/fonts/manrope/Manrope-400.ttf',
      'assets/fonts/manrope/Manrope-500.ttf',
      'assets/fonts/manrope/Manrope-600.ttf',
      'assets/fonts/manrope/Manrope-700.ttf',
      'assets/fonts/manrope/Manrope-800.ttf',
    ]);
    await _font('UIconsSR', ['assets/fonts/uicons/uicons-solid-rounded.ttf']);
    await _font('UIconsBR', ['assets/fonts/uicons/uicons-bold-rounded.ttf']);
    await _font('MaterialIcons', [
      'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  Future<void> boot(WidgetTester t, {bool suggestions = false}) async {
    await t.runAsync(() async {
      final f = Directory('build/sample_backup').listSync().first as File;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      SharedPreferences.setMockInitialValues({
        'locale': 'fa',
        'themeMode': 'dark',
        'tabUpcoming': true,
        'tabDebts': true,
        'tabSms': true,
        'suggestionsOn': suggestions,
      });
      sp = SettingsProvider();
      ep = ExpenseProvider();
      ip = IncomeProvider();
      up = UpcomingProvider();
      dp = DebtProvider();
      await ep.importFromBackup(
        categoriesJson: _list(data['categories']),
        expensesJson: _list(data['expenses']),
      );
      await ip.importFromBackup(
        categoriesJson: _list(data['incomeCategories']),
        incomesJson: _list(data['incomes']),
      );
      await up.importFromBackup(
        upcomingJson: _list(data['upcoming']),
        historyJson: _list(data['upcomingHistory']),
      );
      await dp.importFromBackup(
        debtsJson: _list(data['debts']),
        paymentsJson: _list(data['debtPayments']),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('openfinances/app'),
      (c) async => '1.0.6+10',
    );
    m.setMockMethodCallHandler(
      const MethodChannel('openfinances/bank_notifications'),
      (c) async => switch (c.method) {
        'hasAccess' => true,
        'canPostNotifications' => false,
        'readLog' => [],
        'listFormats' => [],
        _ => null,
      },
    );
  }

  Widget app(Widget home) {
    final base =
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: Colors.blue,
          onPrimary: Colors.white,
          surface: kAppBg,
          surfaceContainerHigh: const Color(0xFF26282C),
        );
    final dark = base.copyWith(surfaceContainerHighest: surfaceTone(base, 2));
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sp),
        ChangeNotifierProvider.value(value: ep),
        ChangeNotifierProvider.value(value: ip),
        ChangeNotifierProvider.value(value: up),
        ChangeNotifierProvider.value(value: dp),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        debugShowCheckedModeBanner: false,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme:
            openFinancesDarkTheme(
              fontFamily: 'ManropeNum',
              fontFamilyFallback: const ['VazirNum', 'Manrope', 'Shabnam'],
            ).copyWith(
              colorScheme: dark,
              scaffoldBackgroundColor: kAppBg,
              canvasColor: kAppBg,
            ),
        builder: (context, child) => DigitsScope(
          style: context.select<SettingsProvider, DigitStyle>(
            (s) => s.digitStyle,
          ),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  Future<void> shot(WidgetTester t, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../build/r_$name.png'),
    );
  }

  Future<void> settle(WidgetTester t, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  void size(WidgetTester t) {
    t.view.physicalSize = const Size(412 * 3, 915 * 3);
    t.view.devicePixelRatio = 3;
  }

  // Example: the Expenses page's Upcoming tab and Settings.
  testWidgets('pages', (t) async {
    size(t);
    await boot(t);
    await t.runAsync(
      () => InkMetrics.instance.prepare(
        openFinancesDarkTheme(
          fontFamily: 'ManropeNum',
          fontFamilyFallback: const ['VazirNum', 'Manrope', 'Shabnam'],
        ).textTheme.bodyMedium!,
      ),
    );
    await t.pumpWidget(app(const ExpensesPage()));
    await settle(t);
    await t.tap(find.text('پیش‌رو'));
    await settle(t);
    await shot(t, 'upcoming');
    await t.pumpWidget(app(const SettingsPage()));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settle(t);
    await shot(t, 'settings');
  });
}

// tool/screen_sweep_template.dart
// Screen-size sweep: the whole app (MainPage, every tab and Expenses
// sub-tab, every Settings section open) at phone and tablet widths and
// larger text, both languages. Layout errors (overflows, bad constraints)
// are printed per place, not thrown. No emulator needed.
//   1. python tool/make_sample_backup.py --today YYYY-MM-DD
//   2. copy to test/zz_sweep_test.dart; flutter test test/zz_sweep_test.dart
//      (about a minute; lines starting "[fa 360.0@1.3] settings: ..." are
//      problems; none = clean)
//   3. delete test/zz_sweep_test.dart.
// Last run (2026-10-24): clean at 320-800 dp and text 1.0-1.5; it does
// catch overflows (at 200 dp the Debts tab overflows).

// It's a test once copied into test/; here the analyzer doesn't know that.
// ignore_for_file: invalid_use_of_visible_for_testing_member, unused_element, unused_import, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/main_page.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
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

  Future<void> boot(
    WidgetTester t, {
    bool suggestions = false,
    String lang = 'fa',
  }) async {
    await t.runAsync(() async {
      final f = Directory('build/sample_backup').listSync().first as File;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      SharedPreferences.setMockInitialValues({
        'locale': lang,
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

  Widget app(Widget home, [String lang = 'fa']) {
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
        locale: Locale(lang),
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

  // Every main page at each screen width and text size: any layout error
  // (overflow, bad constraints) is collected, not thrown.
  for (final lang in ['fa', 'en']) {
    for (final (w, h, scale) in [
      (320.0, 568.0, 1.0),
      (360.0, 640.0, 1.0),
      (360.0, 640.0, 1.3),
      (412.0, 915.0, 1.0),
      (412.0, 915.0, 1.5),
      (480.0, 1000.0, 1.0),
      (600.0, 960.0, 1.0),
      (800.0, 1280.0, 1.0),
    ]) {
      testWidgets('sweep $lang $w x $h @$scale', (t) async {
        t.view.physicalSize = Size(w * 3, h * 3);
        t.view.devicePixelRatio = 3;
        await boot(t, lang: lang);
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(
          d.exceptionAsString().split('\n').first +
              ' @ ${d.context?.toDescription() ?? ''}',
        );
        Future<void> look(String where) async {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await settle(t, 8);
          for (final e in errors) {
            debugPrint('[$lang $w@$scale] $where: $e');
          }
          errors.clear();
        }

        await t.runAsync(
          () => InkMetrics.instance.prepare(
            openFinancesDarkTheme(
              fontFamily: 'ManropeNum',
              fontFamilyFallback: const ['VazirNum', 'Manrope', 'Shabnam'],
            ).textTheme.bodyMedium!,
          ),
        );
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(w, h),
              devicePixelRatio: 3,
              textScaler: TextScaler.linear(scale),
            ),
            child: app(const MainPage(), lang),
          ),
        );
        await look('home');
        for (final sub in ['incoming', 'debts', 'sms', 'history']) {
          expensesSubTabRequest.value = sub;
          await look('home/$sub');
        }
        for (final (tab, name) in [
          (1, 'budget'),
          (2, 'stats'),
          (3, 'settings'),
        ]) {
          mainTab.value = tab;
          await look(name);
        }
        // Settings with every section open.
        for (final f in find.byType(FoldSection).evaluate().toList()) {
          // Not awaited: its animation runs on the frames pumped below.
          ((f as StatefulElement).state as FoldSectionState).open();
        }
        await look('settings/open');
        mainTab.value = 0;
        await look('home again');
        FlutterError.onError = old;
      });
    }
  }
}

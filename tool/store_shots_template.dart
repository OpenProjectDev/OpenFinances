// tool/store_shots_template.dart
// The raw store screenshots: the real app shell, a demo backup restored through
// the real restore, drawn at 1440x3120 (3.75 px a dp) with no device needed.
//   1. python tool/make_store_demo_backup.py --today YYYY-MM-DD
//   2. copy this file to test/zz_store_shots.dart
//   3. flutter test test/zz_store_shots.dart --update-goldens --plain-name "en"
//      and again with "fa", in separate runs (the database and themes are shared)
//      → build/store_raw/<language>/*.png
//   4. delete test/zz_store_shots.dart and test/failures before committing.
// Renders draw no glows, and shadows draw as rims. The bank messages' readings
// are given here, since the reader is native; those layouts are tested in
// BankMessageReaderTest.
// It's a test once copied into test/; here the analyzer doesn't know that.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/data/backup.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/main.dart';
import 'package:openfinances/shared/ui/check_box.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _family(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await l.load();
}

List<String> _ttf(String folder, [String prefix = '']) => [
  for (final f in Directory(folder).listSync().whereType<File>())
    if (f.path.endsWith('.ttf') &&
        f.uri.pathSegments.last.startsWith(prefix))
      f.path,
];

// Amount, unit, income? for each of the demo's bank messages, in their order.
const _readings = [
  (8345000, 'IRR', false),
  (40008000, 'IRR', false),
  (120000000, 'IRR', true),
  (345000, 'IRT', false),
  (1250000, 'IRT', false),
  (250000000, 'IRR', true),
  (1135000000, 'IRR', true),
  (89000, 'IRT', false),
  (1100000, 'IRR', false),
  (6500000, 'IRR', false),
];

// Made-up names: no real bank on a store page.
const _senders = ['بانک آبی', 'بانک سبز', 'بانک نمونه'];

const _words = {
  'en': {
    'category': 'By category',
    'daily': 'Daily spending',
    'due': 'Due',
    'debt': 'Debt',
    'general': 'General',
    'dining': 'Dining out',
    'title': 'Dinner with friends',
    'amount': '64.50',
  },
  'fa': {
    'category': 'سهم دسته‌ها',
    'daily': 'هزینه روزانه',
    'due': 'پیش‌رو',
    'debt': 'بدهی',
    'sms': 'پیامک',
    'general': 'عمومی',
    'dining': 'رستوران',
    'title': 'شام با دوستان',
    'amount': '1950000',
  },
};

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _family('Shabnam', _ttf('assets/fonts/shabnam'));
    await _family('Manrope', _ttf('assets/fonts/manrope'));
    await _family('ManropeNum', _ttf('assets/fonts/digits', 'ManropeNum'));
    await _family('VazirNum', _ttf('assets/fonts/digits', 'VazirNum'));
    await _family('UIconsSR', ['assets/fonts/uicons/uicons-solid-rounded.ttf']);
    await _family('UIconsBR', ['assets/fonts/uicons/uicons-bold-rounded.ttf']);
    await _family('UIconsBrands', ['assets/fonts/uicons/uicons-brands.ttf']);
  });

  void view(WidgetTester t) {
    t.view.physicalSize = const Size(1440, 3120);
    t.view.devicePixelRatio = 3.75;
    addTearDown(t.view.reset);
  }

  void channels(WidgetTester t, List<Map<String, Object?>> log) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (c) async => false,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('openfinances/app'),
      (c) async => c.method == 'version' ? '1.0.12+16' : null,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('openfinances/bank_notifications'),
      (c) async => switch (c.method) {
        'hasAccess' => true,
        'canPostNotifications' => true,
        'readLog' => log,
        'listFormats' => [
          for (final e in log)
            {'skeleton': e['format'], 'name': e['sender'], 'kind': 'expense', 'unit': 'IRR'},
        ],
        'takeSeen' => <String>[],
        _ => null,
      },
    );
  }

  late ExpenseProvider ep;
  late IncomeProvider ip;
  late UpcomingProvider up;
  late DebtProvider dp;

  // Loaded before the first frame: a provider made during a pump can't finish
  // reading the database, which needs real time.
  Future<void> load(SettingsProvider sp) async {
    ep = ExpenseProvider();
    ip = IncomeProvider();
    up = UpcomingProvider();
    dp = DebtProvider();
    await Future.wait([ep.init(), ip.init(), up.init(), dp.init()]);
    ep.setDisplayCurrency(sp.currencyCode);
    ip.setDisplayCurrency(sp.currencyCode);
    up.setDisplayCurrency(sp.currencyCode);
    dp.setDisplayCurrency(sp.currencyCode);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Widget shell(SettingsProvider sp) => Phoenix(
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: sp),
        ChangeNotifierProvider<ExpenseProvider>.value(value: ep),
        ChangeNotifierProvider<IncomeProvider>.value(value: ip),
        ChangeNotifierProvider<UpcomingProvider>.value(value: up),
        ChangeNotifierProvider<DebtProvider>.value(value: dp),
      ],
      child: const OpenFinancesApp(),
    ),
  );

  Future<void> settle(WidgetTester t, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> images(WidgetTester t) async {
    final context = t.element(find.byType(MaterialApp));
    await t.runAsync(() async {
      for (final folder in ['assets/icons', 'assets/nav']) {
        for (final f in Directory(folder).listSync().whereType<File>()) {
          if (f.path.endsWith('.png')) {
            await precacheImage(
              AssetImage('$folder/${f.uri.pathSegments.last}'),
              context,
            );
          }
        }
      }
    });
    await t.pump();
  }

  Future<void> scrollTo(WidgetTester t, String title) async {
    for (var i = 0; i < 30 && find.text(title).evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -350));
      await settle(t, 6);
    }
    await _ensureShown(t, find.text(title).first);
  }

  for (final code in ['en', 'fa']) {
    final words = _words[code]!;

    Future<void> shot(WidgetTester t, String name) async {
      await t.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/store_raw/$code/$name.png'),
      );
    }

    testWidgets('$code first page', (t) async {
      view(t);
      channels(t, const []);
      late SettingsProvider sp;
      await t.runAsync(() async {
        await AppDb.instance.open(path: inMemoryDatabasePath);
        SharedPreferences.setMockInitialValues({
          'locale': code,
          'calendar': code == 'fa' ? 'jalali' : 'gregorian',
          'themeMode': 'dark',
          if (code == 'fa') 'currency': 'IRT',
        });
        sp = SettingsProvider();
        await sp.ready;
        await load(sp);
        await InkMetrics.instance.prepare(
          TextStyle(
            fontFamily: sp.fontFamily,
            fontFamilyFallback: sp.fontFamilyFallback,
          ),
        );
      });
      await t.pumpWidget(shell(sp));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await images(t);
      await settle(t, 120);
      if (code == 'fa') {
        await t.tap(find.text('فارسی').first);
        await settle(t, 20);
      }
      await t.tap(find.byType(CheckBoxMark).first);
      await settle(t, 20);
      await shot(t, 'first');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('$code pages', (t) async {
      view(t);
      late Map<String, dynamic> raw;
      late SettingsProvider sp;
      await t.runAsync(() async {
        await AppDb.instance.open(path: inMemoryDatabasePath);
        SharedPreferences.setMockInitialValues({});
        raw = jsonDecode(
          await File('build/store_demo/OpenFinances-demo-$code.json').readAsString(),
        ) as Map<String, dynamic>;
        await BackupData.fromJson(raw).restore(merge: false);
        sp = SettingsProvider();
        await sp.ready;
        await load(sp);
        await InkMetrics.instance.prepare(
          TextStyle(
            fontFamily: sp.fontFamily,
            fontFamilyFallback: sp.fontFamilyFallback,
          ),
        );
      });
      final messages = ((raw['bankData'] as Map?)?['messages'] as List?) ?? const [];
      final log = <Map<String, Object?>>[
        for (final (i, m) in messages.indexed)
          {
            'key': m['key'],
            'text': m['text'],
            'sender': _senders[i % _senders.length],
            'postedAt': m['postedAt'],
            'status': 'learned',
            'format': 'format${i % _senders.length}',
            'guesses': [
              {
                'amount': _readings[i].$1,
                'unit': _readings[i].$2,
                'kind': _readings[i].$3 ? 'income' : 'expense',
                'runIndex': 0,
                'start': 0,
                'end': 1,
              },
            ],
          },
      ];
      channels(t, log);
      await t.pumpWidget(shell(sp));
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await images(t);
      await settle(t, 60);
      await shot(t, '01-history');

      await t.tap(find.byType(AddNavIcon).first);
      await settle(t, 12);
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), words['title']!);
      await settle(t, 3);
      await t.enterText(fields.at(1), words['amount']!);
      await settle(t, 3);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t, 8);
      await t.tap(find.text(words['general']!).last);
      await settle(t, 8);
      await t.tap(find.text(words['dining']!).last);
      await settle(t, 12);
      await shot(t, '04-add');
      // ignore: invalid_use_of_protected_member
      await t.binding.handlePopRoute();
      await settle(t, 12);

      mainTab.value = 1;
      await settle(t, 24);
      await shot(t, '06-budget');

      mainTab.value = 2;
      await settle(t, 24);
      await shot(t, '02-glance');
      await scrollTo(t, words['category']!);
      await settle(t, 12);
      await shot(t, '03-ring');
      await scrollTo(t, words['daily']!);
      await settle(t, 16);
      await shot(t, '05-daily');

      mainTab.value = 0;
      await settle(t, 12);
      await t.tap(find.text(words['due']!).first);
      await settle(t, 16);
      await shot(t, '07-due');
      await t.tap(find.text(words['debt']!).first);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(t, 16);
      await shot(t, '08-debts');
      if (words['sms'] != null) {
        await t.tap(find.text(words['sms']!).first);
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await settle(t, 16);
        await shot(t, '09-sms');
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }
}

Future<void> _ensureShown(WidgetTester t, Finder f) async {
  Scrollable.ensureVisible(t.element(f), alignment: 0.02);
  await t.pump();
}

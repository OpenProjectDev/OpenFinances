// tool/growth_sweep_template.dart
// Growth sweep: what users can make grow (long titles, notes, names, huge
// amounts, long calculator expressions), in every sheet and page reachable
// from the main page, at small and large screens and text sizes, both
// languages. Reported per place, not thrown:
//   - layout errors (overflows, bad constraints);
//   - "spill": a text drawn outside the box it's in (a fixed height too
//     small for it: no error is raised for that);
//   - "cut": a text that ran out of lines (maxLines; an ellipsis).
// No emulator needed.
//   1. python tool/make_sample_backup.py --today YYYY-MM-DD
//   2. copy to test/zz_growth_test.dart; flutter test test/zz_growth_test.dart
//      (a few minutes; lines starting "[fa 360x640@1.3] add/long: ..." are
//      problems; none = clean)
//   3. delete test/zz_growth_test.dart.

// It's a test once copied into test/; here the analyzer doesn't know that.
// ignore_for_file: invalid_use_of_visible_for_testing_member, unused_element, unused_import, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/main_page.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/data/upcoming_provider.dart';
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

/// What's typed into every field: long words, long runs without a space,
/// and digits (an amount field keeps only those).
const _long =
    'آزمایش متن خیلی بلند برای دیدن اینکه چه می‌شود وقتی کاربر زیاد می‌نویسد '
    'Averyveryverylongwordwithoutanyspacesatallthatgoesonandon '
    '123456789012345678901234567890';

void main() {
  late SettingsProvider sp;
  late ExpenseProvider ep;
  late IncomeProvider ip;
  late UpcomingProvider up;
  late DebtProvider dp;
  late List<Map<String, dynamic>> bankMessages;

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

  Future<void> boot(WidgetTester t, String lang) async {
    await t.runAsync(() async {
      final f = Directory('build/sample_backup').listSync().first as File;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      bankMessages = [
        for (final m in _list((data['bankData'] as Map?)?['messages']))
          {
            ...m,
            'status': 'guess',
            'guesses': [
              {
                'amount': 8345000,
                'unit': 'IRR',
                'kind': 'expense',
                'runIndex': 0,
                'start': 0,
                'end': 1,
              },
            ],
          },
      ];
      SharedPreferences.setMockInitialValues({
        'locale': lang,
        'themeMode': 'dark',
        'tabUpcoming': true,
        'tabDebts': true,
        'tabSms': true,
        'suggestionsOn': true,
        'catBudgetsV1': jsonEncode(data['budgets'] ?? const {}),
        '_budget_migrated_v3': true,
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
        'readLog' => bankMessages,
        'listFormats' => [],
        _ => null,
      },
    );
  }

  Widget app(Widget home, String lang) {
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

  Future<void> settle(WidgetTester t, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  /// Texts drawn outside the box they're in, or out of lines.
  List<String> textFaults(WidgetTester t) {
    final out = <String>[];
    void visit(RenderObject o, RenderBox? box) {
      var inBox = box;
      if (o is RenderBox && o.hasSize) {
        if (o is RenderDecoratedBox ||
            o is RenderPhysicalShape ||
            o is RenderPhysicalModel ||
            o is RenderClipRRect ||
            o is RenderClipRect) {
          inBox = o;
        }
        // A scroll view's content may be anywhere (scrolled out of view):
        // only boxes inside it count.
        if (o is RenderViewportBase ||
            o.runtimeType.toString().contains('Viewport')) {
          inBox = null;
        }
      }
      if (o is RenderParagraph && o.hasSize && o.attached) {
        final text = o.text.toPlainText().replaceAll('\n', ' ');
        if (text.trim().isNotEmpty) {
          if (o.didExceedMaxLines) out.add('cut "${_short(text)}"');
          final b = inBox;
          if (b != null && b.attached) {
            final r = MatrixUtils.transformRect(
              o.getTransformTo(null),
              Offset.zero & o.size,
            );
            final br = MatrixUtils.transformRect(
              b.getTransformTo(null),
              Offset.zero & b.size,
            );
            // Two dp of slack: the ink shift, rounding.
            if (r.top < br.top - 2 ||
                r.bottom > br.bottom + 2 ||
                r.left < br.left - 2 ||
                r.right > br.right + 2) {
              out.add(
                'spill "${_short(text)}" text ${_rect(r)} in box ${_rect(br)}',
              );
            }
          }
        }
      }
      o.visitChildren((c) => visit(c, inBox));
    }

    for (final v in t.binding.renderViews) {
      visit(v, null);
    }
    return out;
  }

  for (final lang in ['fa', 'en']) {
    for (final (w, h, scale) in [
      (320.0, 568.0, 1.0),
      (360.0, 640.0, 1.3),
      (384.0, 832.0, 1.0),
      (412.0, 915.0, 1.5),
    ]) {
      testWidgets('growth $lang $w x $h @$scale', (t) async {
        t.view.physicalSize = Size(w * 3, h * 3);
        t.view.devicePixelRatio = 3;
        await boot(t, lang);
        final where = '$lang ${w.toInt()}x${h.toInt()}@$scale';
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(
          d.exceptionAsString().split('\n').first +
              ' @ ${d.context?.toDescription() ?? ''}',
        );
        final seen = <String>{};
        Future<void> look(String place) async {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await settle(t, 12);
          for (final e in [...errors, ...textFaults(t)]) {
            // Each fault once per run (it shows at every step after).
            if (seen.add(e)) debugPrint('[$where] $place: $e');
          }
          errors.clear();
        }

        NavigatorState nav() => t.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        Future<void> closeAll() async {
          nav().popUntil((r) => r.isFirst);
          await settle(t, 16);
        }

        Future<bool> tapIf(Finder f) async {
          if (f.evaluate().isEmpty) return false;
          await t.tap(f.first, warnIfMissed: false);
          await settle(t, 16);
          return true;
        }

        /// Every field in the top sheet / page gets the long text.
        Future<void> stress(String place) async {
          await look(place);
          final fields = find.byType(EditableText);
          final n = fields.evaluate().length;
          for (var i = 0; i < n; i++) {
            if (i >= fields.evaluate().length) break;
            await t.enterText(fields.at(i), _long);
            await t.pump();
          }
          await look('$place/long');
          // The keyboard down again (a field's room comes back).
          FocusManager.instance.primaryFocus?.unfocus();
          await look('$place/long, keyboard down');
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
        final l = AppLocalizations.of(t.element(find.byType(MainPage)))!;
        final plus = find.byKey(AppBottomBar.addTipKey);

        // History: the add sheet, its calculator, an entry's edit sheet.
        if (await tapIf(plus)) {
          await stress('add');
          final calc = find.byWidgetPredicate(
            (x) => x is ImageIcon && x.image == AppIcons.calculator,
          );
          if (await tapIf(calc)) {
            await look('calculator');
            for (var i = 0; i < 40; i++) {
              await t.tap(find.text('${(i * 7) % 10}').last);
              if (i % 3 == 2) await t.tap(find.text('000').last);
              await t.pump();
            }
            await look('calculator/long');
          }
          await closeAll();
        }
        if (await tapIf(find.text('نانوایی'))) {
          await stress('entry');
          await closeAll();
        }

        // Due: a payment's sheet, its editor, the add sheet.
        expensesSubTabRequest.value = 'incoming';
        await look('due');
        if (await tapIf(find.text('قبض گاز'))) {
          await look('due/sheet');
          if (await tapIf(find.byType(EditSquare))) await stress('due/edit');
          await closeAll();
        }
        if (await tapIf(plus)) {
          await stress('due/add');
          await closeAll();
        }

        // Debts: a debt's pay sheet, the add sheet.
        expensesSubTabRequest.value = 'debts';
        await look('debts');
        if (await tapIf(find.text('قرض برای اجاره'))) {
          await stress('debts/pay');
          if (await tapIf(find.byType(EditSquare))) await stress('debts/edit');
          await closeAll();
        }
        if (await tapIf(plus)) {
          await stress('debts/add');
          await closeAll();
        }

        // SMS: a message's sheet.
        expensesSubTabRequest.value = 'sms';
        await look('sms');
        if (await tapIf(find.textContaining('برداشت')) ||
            await tapIf(find.textContaining('Blu')) ||
            await tapIf(find.textContaining('8,345'))) {
          await stress('sms/sheet');
          await closeAll();
        }
        expensesSubTabRequest.value = 'history';

        // Budget: a category's budget sheet, the categories page and a
        // category's sheet.
        mainTab.value = 1;
        await look('budget');
        if (await tapIf(find.byType(EditSquare))) {
          await stress('budget/edit');
          await closeAll();
        }
        if (await tapIf(find.text(l.manageCategories))) {
          await look('categories');
          if (await tapIf(find.text('خواربار'))) {
            await stress('categories/edit');
          }
          await closeAll();
        }

        mainTab.value = 2;
        await look('stats');

        // Settings, every section open; the pages it opens.
        mainTab.value = 3;
        await look('settings');
        for (final f in find.byType(FoldSection).evaluate().toList()) {
          ((f as StatefulElement).state as FoldSectionState).open();
        }
        await look('settings/open');
        await stress('settings');
        if (await tapIf(find.text(l.smsFormats))) {
          await look('sms formats');
          await closeAll();
        }
        if (await tapIf(find.text('Open-source licenses'))) {
          await look('licenses');
          await closeAll();
        }
        mainTab.value = 0;
        await look('home again');
        FlutterError.onError = old;
      });
    }
  }
}

String _short(String s) => s.length > 40 ? s.substring(0, 40) : s;

String _rect(Rect r) =>
    '[${r.left.toStringAsFixed(0)},${r.top.toStringAsFixed(0)} '
    '${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}]';

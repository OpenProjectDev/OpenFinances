// Statistics' bar charts always show at least five periods (the owner): empty
// ones before the first with data are an absence of data, not data from before
// the first entry, so that rule doesn't take them away (2026-11-03).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/stats/period_bar_chart.dart';
import 'package:openfinances/features/stats/statistics_page.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
  });

  testWidgets('one period with data: still five bars, four of them empty', (
    t,
  ) async {
    t.view.physicalSize = const Size(412, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late SettingsProvider sp;
    late ExpenseProvider ep;
    late IncomeProvider ip;
    await t.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        'locale': 'en',
        'calendar': 'gregorian',
        'currency': 'USD',
      });
      sp = SettingsProvider();
      ep = ExpenseProvider();
      ip = IncomeProvider();
      final now = DateTime.now().toUtc().toIso8601String();
      await ep.importFromBackup(
        categoriesJson: const [],
        expensesJson: [
          {
            'gid': 'only-entry',
            'title': 'Only entry',
            'amountMinor': 150000,
            'currency': 'USD',
            'occurredAtUtc': now,
            'createdAtUtc': now,
            'updatedAtUtc': now,
            'categoryGid': 'c',
            'version': 1,
            'isDeleted': false,
            'isDirty': true,
          },
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('openfinances/app'),
      (c) async => '1.0.0+1',
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sp),
          ChangeNotifierProvider.value(value: ep),
          ChangeNotifierProvider.value(value: ip),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const StatisticsPage(),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final charts = t
        .widgetList<PeriodBarChart>(find.byType(PeriodBarChart))
        .toList();
    expect(charts, isNotEmpty);
    for (final chart in charts) {
      expect(chart.values.length, kMinPeriods);
      expect(chart.labels.length, kMinPeriods);
      // The data's the last one; the rest are empty.
      expect(chart.values.last, greaterThan(0));
      expect(chart.values.take(kMinPeriods - 1).every((v) => v == 0), isTrue);
      expect(chart.selectedIndex, kMinPeriods - 1);
    }
    await t.pumpWidget(const SizedBox());
  });
}

// The first page (lib/app/initial_setup.dart): it starts as the branding
// screen's last picture; English to start, with its calendar and currency;
// a language picked sets its own unless they were changed there; Continue
// waits for the privacy row (ticked by reading the policy to its end);
// tips as ticked.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/app/brand_mark.dart';
import 'package:openfinances/app/branding_screen.dart';
import 'package:openfinances/app/initial_setup.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
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

  testWidgets('pick, change, agree, continue', (t) async {
    // A phone's screen (the S25 Edge's, in dp).
    t.view.physicalSize = const Size(384 * 3, 832 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    late SettingsProvider sp;
    late ExpenseProvider ep;
    late IncomeProvider ip;
    await t.runAsync(() async {
      SharedPreferences.setMockInitialValues({'locale': 'fa'});
      sp = SettingsProvider();
      await sp.ready;
      ep = ExpenseProvider();
      ip = IncomeProvider();
    });
    var done = false;
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sp),
          ChangeNotifierProvider.value(value: ep),
          ChangeNotifierProvider.value(value: ip),
        ],
        // The app follows the language picked (as main.dart's does).
        child: ListenableBuilder(
          listenable: sp,
          builder: (_, _) => MaterialApp(
            locale: sp.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: InitialSetupPage(onFinished: () => done = true),
          ),
        ),
      ),
    );
    Future<void> frames([int n = 30]) async {
      for (var i = 0; i < n; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    // Under the branding screen: the lockup exactly where that screen
    // leaves it (no jump at the hand-over).
    await frames(3);
    final place = BrandingOverlay.designedPlace(
      t.view.physicalSize / t.view.devicePixelRatio,
    );
    final mark = t.getRect(find.byType(BrandMark));
    expect(mark.top, moreOrLessEquals(place.top, epsilon: .01));
    expect(mark.center.dx, moreOrLessEquals(place.middle, epsilon: .01));

    // Handed over: the lockup moves up, the rows come in under it.
    brandingOver.complete();
    await frames(40);
    expect(t.getRect(find.byType(BrandMark)).top, lessThan(place.top));
    // English to start, with its calendar and currency.
    expect(sp.locale.languageCode, 'en');
    expect(sp.calendar, AppCalendar.gregorian);
    expect(sp.currencyCode, 'EUR');

    // Not yet: the privacy row isn't ticked.
    await t.ensureVisible(find.text('Continue'));
    await t.tap(find.text('Continue'));
    await frames(10);
    expect(done, isFalse);

    // A calendar changed here stays; the currency follows the language.
    await t.tap(find.text('More options'));
    await frames(20);
    await t.tap(find.text('Shamsi'));
    await frames(5);
    await t.tap(find.text('Gregorian'));
    await frames(5);
    await t.tap(find.text('فارسی'));
    await frames(20);
    expect(sp.locale.languageCode, 'fa');
    expect(sp.calendar, AppCalendar.gregorian);
    expect(sp.currencyCode, 'IRT');

    // The policy's name opens it; closed any other way than "Got it" (here
    // Back: it fills the screen), nothing's ticked.
    await t.ensureVisible(find.text('حریم خصوصی'));
    await t.tap(find.text('حریم خصوصی'));
    await frames(20);
    expect(find.text('چیزی از گوشی شما بیرون نمی‌رود'), findsOneWidget);
    await t.binding.handlePopRoute();
    await frames(20);
    await t.ensureVisible(find.text('ادامه'));
    await t.tap(find.text('ادامه'));
    await frames(10);
    expect(done, isFalse);

    // Read to its "Got it": the row is ticked.
    await t.ensureVisible(find.text('حریم خصوصی'));
    await t.tap(find.text('حریم خصوصی'));
    await frames(20);
    await t.ensureVisible(find.text('متوجه شدم'));
    await t.tap(find.text('متوجه شدم'));
    await frames(20);
    // Restore beside Tips (a backup goes straight into the app).
    expect(find.text('بازیابی'), findsOneWidget);
    await t.ensureVisible(find.text('آموزش'));
    await t.tap(find.text('آموزش'));
    await frames(5);
    await t.ensureVisible(find.text('ادامه'));
    await t.tap(find.text('ادامه'));
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await frames(10);
    expect(done, isTrue);
    expect(sp.tipsOn, isTrue);
    // The default category in the language picked.
    expect(ep.categories.map((c) => c.name), contains('عمومی'));
  });
}

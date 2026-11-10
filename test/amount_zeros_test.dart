// The amount field's "000" button (lib/shared/ui/entry_fields.dart): there
// once something is typed (Settings: on by default for toman and rial, off
// for dollars and euros, whatever the language), it puts
// three zeros where the cursor is, grouped like typed ones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<TextEditingController> open(
    WidgetTester t,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = SettingsProvider();
    await sp.ready;
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: sp,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AmountFieldRow(controller: c, hint: 'Amount'),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('000 adds three grouped zeros, only once something is typed', (
    t,
  ) async {
    // Toman, the default currency: on by default, in English too.
    final c = await open(t, {'locale': 'en'});
    expect(find.text('000'), findsNothing);
    await t.enterText(find.byType(TextField), '12');
    await t.pump();
    await t.tap(find.text('000'));
    await t.pump();
    expect(c.text, '12,000');
    await t.tap(find.text('000'));
    await t.pump();
    expect(c.text, '12,000,000');
  });

  testWidgets('off by default for euros, in Persian too; the setting turns '
      'it on', (t) async {
    await open(t, {'locale': 'fa', 'currency': 'EUR'});
    await t.enterText(find.byType(TextField), '5');
    await t.pump();
    expect(find.text('000'), findsNothing);
    await open(t, {'locale': 'fa', 'currency': 'EUR', 'quickZeros': true});
    await t.enterText(find.byType(TextField), '5');
    await t.pump();
    expect(find.text('000'), findsOneWidget);
  });

  test(
    'the default follows the currency; a change of kind resets a choice',
    () async {
      Future<SettingsProvider> with_(Map<String, Object> prefs) async {
        SharedPreferences.setMockInitialValues(prefs);
        final sp = SettingsProvider();
        await sp.ready;
        return sp;
      }

      for (final (code, on) in [
        ('IRT', true),
        ('IRR', true),
        ('USD', false),
        ('EUR', false),
      ]) {
        expect((await with_({'currency': code})).quickZeros, on, reason: code);
      }

      // Turned off on toman: stays off on rial (same kind), then euros take
      // their own default, and toman again its own.
      final sp = await with_({'currency': 'IRT'});
      await sp.setQuickZeros(false);
      await sp.setCurrency('IRR');
      expect(sp.quickZeros, isFalse);
      await sp.setCurrency('EUR');
      expect(sp.quickZeros, isFalse);
      await sp.setQuickZeros(true);
      await sp.setCurrency('USD');
      expect(sp.quickZeros, isTrue);
      await sp.setCurrency('IRT');
      expect(sp.quickZeros, isTrue);
      expect(
        (await SharedPreferences.getInstance()).containsKey('quickZeros'),
        isFalse,
      );
    },
  );
}

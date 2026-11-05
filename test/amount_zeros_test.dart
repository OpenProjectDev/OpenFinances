// The amount field's "000" button (lib/shared/ui/entry_fields.dart): there
// once something is typed (Settings: on in Persian by default), it puts
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
    // Persian saved as the language: on by default.
    final c = await open(t, {'locale': 'fa'});
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

  testWidgets('off by default in English; the setting turns it on', (t) async {
    await open(t, {'locale': 'en'});
    await t.enterText(find.byType(TextField), '5');
    await t.pump();
    expect(find.text('000'), findsNothing);
    await open(t, {'locale': 'en', 'quickZeros': true});
    await t.enterText(find.byType(TextField), '5');
    await t.pump();
    expect(find.text('000'), findsOneWidget);
  });
}

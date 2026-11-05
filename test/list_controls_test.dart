// ListControlsRow (lib/shared/ui/list_controls.dart): "All" appearing in
// front of the other chips must not hand them each other's animations
// (unkeyed, the sort chip's fixed width was animated into "All"'s free one:
// an error every frame, and the app hung after "See last entry").
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/list_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('"All" coming and going keeps the row whole', (t) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.ready;

    Widget row({VoidCallback? onAll, bool away = false}) =>
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListControlsRow(
                onAll: onAll,
                byAmount: false,
                onSort: () {},
                onToday: away ? () {} : null,
                todayAway: away,
              ),
            ),
          ),
        );

    await t.pumpWidget(row(away: true));
    await t.pumpWidget(row(onAll: () {}, away: true)); // "All" comes in
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpWidget(row()); // and goes, today back
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}

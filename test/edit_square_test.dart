// The square by what it edits: a pencil; with nothing to edit yet (a category
// with no budget: the owner, 2026-11-04), a plus, its label saying so. One size,
// the row doesn't shift when a budget is set.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a pencil, or with nothing to edit a plus; one size', (t) async {
    final l = lookupAppLocalizations(const Locale('en'));
    var taps = 0;
    await t.pumpWidget(
      app(EditSquare(onTap: () => taps++, background: Colors.grey)),
    );
    final square = find.byType(EditSquare);
    expect(find.byType(ImageIcon), findsOneWidget);
    expect(find.bySemanticsLabel(l.edit), findsOneWidget);
    final pencil = t.getSize(square);

    await t.pumpWidget(
      app(
        EditSquare(
          onTap: () => taps++,
          background: Colors.grey,
          addLabel: l.addBudget,
        ),
      ),
    );
    expect(find.byType(ImageIcon), findsNothing);
    expect(find.bySemanticsLabel(l.addBudget), findsOneWidget);
    expect(t.getSize(square), pencil);
    await t.tap(square);
    expect(taps, 1);
  });
}

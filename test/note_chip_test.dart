// The note on add sheets (the owner, 2026-11-04): a small chip at the end of the
// title's row; a tap opens the field under it; empty, a tap outside folds it back.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';

final _l = lookupAppLocalizations(const Locale('en'));

Future<NoteFold> _open(WidgetTester t, {String text = ''}) async {
  final title = TextEditingController();
  final fold = NoteFold(TextEditingController(text: text));
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NoteRow(
              fold: fold,
              field: TextField(key: const ValueKey('title'), controller: title),
            ),
            NoteSection(fold: fold),
            const SizedBox(key: ValueKey('outside'), height: 200),
          ],
        ),
      ),
    ),
  );
  await t.pump();
  return fold;
}

Finder get _noteField => find.byKey(const ValueKey('noteField'));

void main() {
  testWidgets('closed: just the chip, as narrow as its word', (t) async {
    await _open(t);
    expect(_noteField, findsNothing);
    expect(find.text(_l.noteLabel), findsOneWidget);
    final row = t.getSize(find.byType(NoteRow)).width;
    final chip = t.getSize(find.byKey(const ValueKey('noteChip'))).width;
    expect(chip, lessThan(row / 2));
    // As tall as the field beside it.
    expect(
      t.getSize(find.byKey(const ValueKey('noteChip'))).height,
      t.getSize(find.byKey(const ValueKey('title'))).height,
    );
  });

  testWidgets('a tap opens it, focused; outside, empty, it folds back', (
    t,
  ) async {
    final fold = await _open(t);
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    expect(_noteField, findsOneWidget);
    expect(fold.focus.hasFocus, isTrue);

    await t.tap(find.byKey(const ValueKey('outside')));
    await t.pumpAndSettle();
    expect(_noteField, findsNothing);
    expect(fold.open, isFalse);
  });

  testWidgets('from the note to another field the keyboard stays up', (
    t,
  ) async {
    final fold = await _open(t);
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    expect(fold.focus.hasFocus, isTrue);

    t.testTextInput.log.clear();
    await t.tap(find.byKey(const ValueKey('title')));
    await t.pumpAndSettle();
    expect(fold.open, isFalse);
    expect(
      t.testTextInput.log.where((c) => c.method == 'TextInput.hide'),
      isEmpty,
      reason: 'never closed on the way',
    );
    expect(t.testTextInput.isVisible, isTrue);
  });

  testWidgets('from the note to nothing the keyboard goes', (t) async {
    final fold = await _open(t);
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('outside')));
    await t.pumpAndSettle();
    expect(fold.open, isFalse);
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('tapping inside it leaves it open', (t) async {
    await _open(t);
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    await t.tap(_noteField);
    await t.pumpAndSettle();
    expect(_noteField, findsOneWidget);
  });

  testWidgets('with text it stays open, outside taps or not', (t) async {
    final fold = await _open(t);
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    await t.enterText(_noteField, 'for the car');
    await t.tap(find.byKey(const ValueKey('outside')));
    await t.pumpAndSettle();
    expect(_noteField, findsOneWidget);
    expect(fold.controller.text, 'for the car');

    // Tapping the chip with text doesn't fold it either.
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    expect(_noteField, findsOneWidget);
  });

  testWidgets('a note already there opens it from the start', (t) async {
    await _open(t, text: 'old note');
    expect(_noteField, findsOneWidget);
  });

  testWidgets('a note arriving later (a draft) opens it', (t) async {
    final fold = await _open(t);
    fold.controller.text = 'from a draft';
    await t.pumpAndSettle();
    expect(_noteField, findsOneWidget);
  });

  testWidgets('the title keeps its text and focus as the note folds', (
    t,
  ) async {
    final fold = await _open(t);
    await t.enterText(find.byKey(const ValueKey('title')), 'Lunch');
    await t.tap(find.byKey(const ValueKey('noteChip')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('title')));
    await t.pumpAndSettle();
    expect(fold.open, isFalse);
    expect(find.text('Lunch'), findsOneWidget);
  });
}

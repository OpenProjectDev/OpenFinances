import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';

/// Types [keys] into a fresh calculator ("( ) + - × ÷ . <" and digits; "<"
/// is backspace, "k" the "000" key) and returns its result.
String calc(String keys) {
  final c = CalcExpression();
  for (final k in keys.split('')) {
    switch (k) {
      case '(':
        c.openParen();
      case ')':
        c.closeParen();
      case '.':
        c.decimal();
      case '<':
        c.backspace();
      case 'k':
        c.zeros();
      case '+' || '-' || '×' || '÷':
        c.op(k);
      default:
        c.digit(k);
    }
  }
  return c.result();
}

void main() {
  test('precedence and parentheses', () {
    expect(calc('2+3×4'), '14');
    expect(calc('(2+3)×4'), '20');
    expect(calc('(2+3)4'), '20'); // implicit times
    expect(calc('2(3+4)'), '14');
    expect(calc('100÷(2+3'), '20'); // closes itself
    expect(calc('10-(-3)'), '13');
  });

  test('edits and edge cases', () {
    expect(calc(''), '0');
    expect(calc('12+'), '12'); // trailing operator ignored
    expect(calc('12+×3'), '36'); // operator replaced
    expect(calc('5÷0'), '5');
    expect(calc('0.1+0.2'), '0.3');
    expect(calc('123<<4'), '14');
    expect(calc('2)'), '2'); // nothing to close
  });

  test('the 000 key', () {
    expect(calc('12k'), '12000');
    expect(calc('1.5k'), '1.5');
    expect(calc('k'), '0'); // nothing to add zeros to
    expect(calc('0k'), '0');
    expect(calc('2+k'), '2');
    expect(calc('3kk<'), '300000');
  });

  test('amounts stop at 15 digits; a bigger result does not fit', () {
    expect(calc('1234567890123456789'), '123456789012345');
    expect(calc('123456789012k'), '123456789012000');
    expect(calc('1234567890123k'), '1234567890123'); // 000 would pass 15
    final c = CalcExpression();
    for (final k in '999999999999999'.split('')) {
      c.digit(k);
    }
    expect(c.fits(), isTrue);
    c.op('×');
    c.digit('9');
    expect(c.fits(), isFalse);
    expect(c.result(), isNot(contains('e')));
    // The fields take 15 digits too.
    final f = ThousandsSeparatorFormatter();
    const old = TextEditingValue(text: '999,999,999,999,999');
    expect(
      f.formatEditUpdate(old, const TextEditingValue(text: '9999999999999999')),
      old,
    );
  });

  // No C key (the owner, 2026-10-26): backspace takes one off, held it
  // clears everything.
  testWidgets('backspace held clears', (t) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CalculatorSheet(initialValue: '')),
      ),
    );
    for (final k in ['1', '2', '3']) {
      await t.tap(find.text(k));
    }
    await t.pump();
    expect(find.text('123'), findsOneWidget);
    expect(find.text('C'), findsNothing);
    await t.tap(find.byIcon(UIcons.backspace));
    await t.pump();
    expect(find.text('12'), findsOneWidget);
    await t.longPress(find.byIcon(UIcons.backspace));
    await t.pump();
    expect(find.text('12'), findsNothing);
    expect(find.text('0'), findsNWidgets(2)); // the display and the 0 key
  });
}

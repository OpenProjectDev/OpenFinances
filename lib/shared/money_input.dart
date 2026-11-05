// lib/shared/money_input.dart
// Shared money-entry helpers (thousands formatter, digit conversion,
// calculator sheet) used by the Add/Edit Expense and Add/Edit Income
// sheets, so the calculator UI isn't duplicated per feature.

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:flutter/material.dart';
import 'package:openfinances/app/theme.dart';
import 'package:flutter/services.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/haptics.dart';

/// The most digits an amount has before its point: 999 trillion (amounts
/// are kept in minor units, and a 64-bit int holds about 92 thousand
/// trillion; longer, a 30-digit amount became "1.2e+29" in the calculator).
const int kMaxAmountDigits = 15;

/// Live thousands formatter with a custom separator; keeps one decimal
/// point; a digit past [kMaxAmountDigits] isn't taken.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  ThousandsSeparatorFormatter({this.separator = ','});
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return const TextEditingValue(text: '');

    final parts = newValue.text.split('.');
    final integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    if (parts.length > 2) return oldValue;
    if (integerPart.length > kMaxAmountDigits) return oldValue;

    final buf = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      final idxFromRight = integerPart.length - i;
      buf.write(integerPart[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) buf.write(separator);
    }

    String formatted = buf.toString();
    if (parts.length == 2) {
      final decimalPart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      formatted = '$formatted.$decimalPart';
    }

    final selectionFromRight = newValue.text.length - newValue.selection.end;
    var newOffset = formatted.length - selectionFromRight;
    newOffset = newOffset.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

const _kFaDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const _kEnDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

String toFaDigits(String s) {
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(_kEnDigits[i], _kFaDigits[i]);
  }
  return s;
}

String faToEnDigits(String s) {
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(_kFaDigits[i], _kEnDigits[i]);
  }
  return s;
}

/// Formats minor units (e.g. cents) as a comma-grouped major-unit string,
/// e.g. 123456 -> "1,234.56" (decimals omitted when zero).
String formatMinorWithCommas(int minor) {
  final major = minor / 100;
  final intPart = major.floor();
  final decPart = (major - intPart) * 100;

  final s0 = intPart.toString();
  final b = StringBuffer();
  for (int i = 0; i < s0.length; i++) {
    final idxFromRight = s0.length - i;
    b.write(s0[i]);
    if (idxFromRight > 1 && idxFromRight % 3 == 1) b.write(',');
  }

  if (decPart > 0) {
    b.write('.');
    b.write(decPart.round().toString().padLeft(2, '0'));
  }

  return b.toString();
}

String currencyLabelFor(String code, AppLocalizations l) {
  switch (code) {
    case 'IRT':
      return l.currencyToman;
    case 'IRR':
      return l.currencyRial;
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    default:
      return code;
  }
}

/// Public API: shows the shared calculator bottom sheet and returns the
/// resulting value as a plain (comma-free) numeric string, or null if
/// dismissed without pressing Done.
Future<String?> showCalculatorSheet({
  required BuildContext context,
  required String initialValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CalculatorSheet(initialValue: initialValue),
  );
}

class CalculatorSheet extends StatefulWidget {
  final String initialValue;
  const CalculatorSheet({super.key, required this.initialValue});

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

/// The sheet's arithmetic: an expression as tokens (numbers, + - × ÷, and
/// parentheses), evaluated with the usual precedence (× ÷ before + -).
/// Unclosed parentheses close themselves; a trailing operator is ignored;
/// dividing by zero leaves the number as it was.
class CalcExpression {
  final List<String> tokens = [];

  static const ops = {'+', '-', '×', '÷'};

  bool _isNum(String t) => !ops.contains(t) && t != '(' && t != ')';
  String? get _last => tokens.isEmpty ? null : tokens.last;
  int get _open =>
      tokens.where((t) => t == '(').length -
      tokens.where((t) => t == ')').length;

  /// [n] with [more] digits added still an amount ([kMaxAmountDigits]
  /// before its point).
  static bool _fits(String n, int more) =>
      n.contains('.') || n.length + more <= kMaxAmountDigits;

  void digit(String d) {
    final last = _last;
    if (last != null && _isNum(last)) {
      if (last != '0' && !_fits(last, 1)) return;
      tokens[tokens.length - 1] = last == '0' ? d : last + d;
      return;
    }
    if (last == ')') tokens.add('×'); // "(2+3)4" means times
    tokens.add(d);
  }

  /// "000" on the number being typed (nothing on an empty or a 0 one).
  void zeros() {
    final last = _last;
    if (last == null || !_isNum(last) || last == '0') return;
    if (!_fits(last, 3)) return;
    tokens[tokens.length - 1] = '${last}000';
  }

  void decimal() {
    final last = _last;
    if (last != null && _isNum(last)) {
      if (!last.contains('.')) tokens[tokens.length - 1] = '$last.';
      return;
    }
    if (last == ')') tokens.add('×');
    tokens.add('0.');
  }

  void op(String o) {
    final last = _last;
    if (last == null) {
      tokens.addAll(['0', o]);
    } else if (ops.contains(last)) {
      tokens[tokens.length - 1] = o; // changed its mind
    } else if (last == '(') {
      if (o == '-') tokens.addAll(['0', '-']); // "(-3" reads as "(0-3"
    } else {
      tokens.add(o);
    }
  }

  void openParen() {
    final last = _last;
    if (last != null && (_isNum(last) || last == ')')) tokens.add('×');
    tokens.add('(');
  }

  void closeParen() {
    final last = _last;
    if (_open > 0 && last != null && (_isNum(last) || last == ')')) {
      tokens.add(')');
    }
  }

  void backspace() {
    final last = _last;
    if (last == null) return;
    if (_isNum(last) && last.length > 1) {
      tokens[tokens.length - 1] = last.substring(0, last.length - 1);
    } else {
      tokens.removeLast();
    }
  }

  void clear() => tokens.clear();

  /// The value (0 when empty), as a plain number string.
  String result() {
    final t = [...tokens];
    while (t.isNotEmpty && (ops.contains(t.last) || t.last == '(')) {
      t.removeLast();
    }
    if (t.isEmpty) return '0';
    var open = 0;
    for (final x in t) {
      if (x == '(') open++;
      if (x == ')') open--;
    }
    t.addAll(List.filled(open < 0 ? 0 : open, ')'));
    var i = 0;
    double expr() {
      double term() {
        double factor() {
          if (i >= t.length) return 0;
          final x = t[i++];
          if (x == '(') {
            final v = expr();
            if (i < t.length && t[i] == ')') i++;
            return v;
          }
          return double.tryParse(x) ?? 0;
        }

        var v = factor();
        while (i < t.length && (t[i] == '×' || t[i] == '÷')) {
          final o = t[i++];
          final r = factor();
          if (o == '×') {
            v *= r;
          } else if (r != 0) {
            v /= r;
          }
        }
        return v;
      }

      var v = term();
      while (i < t.length && (t[i] == '+' || t[i] == '-')) {
        final o = t[i++];
        final r = term();
        v = o == '+' ? v + r : v - r;
      }
      return v;
    }

    final v = expr();
    // Too big for an amount: all its digits (no "e+20", no int clamping);
    // [fits] says no.
    if (v.abs() >= 1e15) return v.toStringAsFixed(0);
    // Float noise off (0.1 + 0.2), then no ".0" on whole numbers.
    final rounded = double.parse(v.toStringAsFixed(6));
    return rounded == rounded.truncateToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }

  /// The result is an amount the fields take ([kMaxAmountDigits]).
  bool fits() =>
      result().replaceFirst('-', '').split('.').first.length <=
      kMaxAmountDigits;
}

class _CalculatorSheetState extends State<CalculatorSheet>
    with SingleTickerProviderStateMixin {
  final _calc = CalcExpression();

  /// The expression flashing red: its result is too big for an amount.
  late final _tooBig = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(() => setState(() {}));

  /// = or Confirm with a result too big: the expression flashes red and
  /// stays (nothing is put in the field).
  bool _refuseTooBig() {
    if (_calc.fits()) return false;
    _tooBig.forward(from: 0).then((_) {
      if (mounted) _tooBig.reverse();
    });
    return true;
  }

  /// The expression's scroll (it starts at its end: [reverse]).
  final _expression = ScrollController();

  @override
  void dispose() {
    _tooBig.dispose();
    _expression.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialValue.isNotEmpty) {
      final cleaned = widget.initialValue.replaceAll(RegExp(r'[,٬،\s]'), '');
      final value = double.tryParse(faToEnDigits(cleaned));
      if (value != null && value > 0) {
        _calc.tokens.add(
          value == value.toInt() ? value.toInt().toString() : value.toString(),
        );
      }
    }
  }

  String _formatNumber(String num) {
    final parts = num.split('.');
    final intPart = parts[0];
    final formatted = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final idxFromRight = intPart.length - i;
      formatted.write(intPart[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) formatted.write(',');
    }
    if (parts.length > 1) formatted.write('.${parts[1]}');
    return formatted.toString();
  }

  String _display() {
    if (_calc.tokens.isEmpty) return '0';
    final b = StringBuffer();
    for (final t in _calc.tokens) {
      if (CalcExpression.ops.contains(t)) {
        b.write(' ${t == '-' ? '−' : t} ');
      } else if (t == '(' || t == ')') {
        b.write(t);
      } else {
        // A number too long for a line goes on after a comma, never inside
        // a group of digits (a zero-width space there); a shorter one
        // stays whole (the expression breaks at its operators).
        final n = _formatNumber(t);
        b.write(n.length > 10 ? n.replaceAll(',', ',\u200B') : n);
      }
    }
    return b.toString();
  }

  /// One line of [style]'s text, as tall as it's drawn.
  static double _lineHeight(BuildContext context, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(
        text: '0',
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final h = tp.height;
    tp.dispose();
    return h;
  }

  /// A key: the expression changes and shows its end again.
  void _do(void Function() f) {
    setState(f);
    if (_expression.hasClients) _expression.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    // kind: 0 number, 1 operator / parenthesis, 2 clear / backspace (red),
    // 3 equals (theme color).
    // A key ([onLongPress]: what holding it does).
    Widget key(
      Object label,
      VoidCallback onPressed, [
      int kind = 0,
      VoidCallback? onLongPress,
    ]) {
      final bg = switch (kind) {
        1 => scheme.secondaryContainer,
        2 => kStrongRed,
        3 => scheme.primary,
        _ => scheme.surfaceContainerHigh,
      };
      final fg = switch (kind) {
        1 => scheme.onSecondaryContainer,
        2 => Colors.white,
        3 => context.textOnStrong,
        _ => scheme.onSurface,
      };
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              onTap: onPressed,
              onLongPress: onLongPress,
              child: Container(
                height: 58,
                alignment: Alignment.center,
                // Digits and "." as text; operators drawn alike
                // (_OpMark); backspace as its icon.
                child: label is _OpMark
                    ? CustomPaint(
                        size: const Size.square(_OpMarkPainter.width),
                        painter: _OpMarkPainter(label, fg),
                      )
                    : label is IconData
                    ? Icon(label, size: 20, color: fg)
                    // Centered by its own letters (InkText), in any font.
                    : InkText(
                        '$label',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    Widget num(String d) => key(d, () => _do(() => _calc.digit(d)));
    Widget op(_OpMark shown, String o) =>
        key(shown, () => _do(() => _calc.op(o)), 1);

    final expressionStyle = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    final actionStyle = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The expression, the whole width: one line sits at the
                // right; a long one takes more lines (never shrunk), each
                // starting from the left like written lines; past three it
                // scrolls, its end in view (the owner, 2026-10-26: it grew
                // till the sheet overflowed). On a short screen it gives up
                // lines first, the keys never (Flexible: only the room the
                // keys leave).
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 76),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          scheme.surfaceContainerHigh,
                          kStrongRed,
                          _tooBig.value,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // As tall as its text (Container's own alignment
                      // would fill all the room Flexible allows).
                      child: Align(
                        alignment: Alignment.centerRight,
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                3 * _lineHeight(context, expressionStyle),
                          ),
                          child: SingleChildScrollView(
                            controller: _expression,
                            reverse: true,
                            child: InkText(
                              _display(),
                              textAlign: TextAlign.left,
                              style: expressionStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: kSheetRowGap - 4),
                // Four columns (the owner, 2026-10-26): the parentheses side
                // by side over the digits, backspace by them (held: clear);
                // "000" by 0; the operators down the right, = at the bottom.
                Row(
                  children: [
                    key('(', () => _do(_calc.openParen), 1),
                    key(')', () => _do(_calc.closeParen), 1),
                    // Held: clears it all (no C key: the expression has
                    // the room; the owner, 2026-10-26).
                    key(UIcons.backspace, () => _do(_calc.backspace), 2, () {
                      Haptics.tap(context);
                      _do(_calc.clear);
                    }),
                    op(_OpMark.divide, '÷'),
                  ],
                ),
                Row(
                  children: [
                    num('7'),
                    num('8'),
                    num('9'),
                    op(_OpMark.times, '×'),
                  ],
                ),
                Row(
                  children: [
                    num('4'),
                    num('5'),
                    num('6'),
                    op(_OpMark.minus, '-'),
                  ],
                ),
                Row(
                  children: [
                    num('1'),
                    num('2'),
                    num('3'),
                    op(_OpMark.plus, '+'),
                  ],
                ),
                Row(
                  children: [
                    // Latin in both languages («۰۰۰» reads as dots).
                    key('000', () => _do(_calc.zeros)),
                    num('0'),
                    key('.', () => _do(_calc.decimal)),
                    key(_OpMark.equals, () {
                      if (_refuseTooBig()) return;
                      _do(() {
                        final r = _calc.result();
                        _calc.clear();
                        if (r != '0') _calc.tokens.add(r);
                      });
                    }, 3),
                  ],
                ),
                const SizedBox(height: kSheetRowGap),
                // Cancel (keeps the field as it was) and Confirm (puts the
                // result in), like every sheet's action row.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: cancelButtonStyle(actionStyle),
                        onPressed: () => Navigator.pop(context),
                        child: InkText(l.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: saveButtonStyle(context, actionStyle),
                        onPressed: () {
                          if (_refuseTooBig()) return;
                          Navigator.pop(context, _calc.result());
                        },
                        child: InkText(l.done),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The calculator's operators.
enum _OpMark { plus, minus, times, divide, equals }

/// An operator key's mark. All five are drawn alike, so none looks bigger
/// or bolder than the next: one stroke with round ends (UIcons Bold
/// Rounded's look and proportions: ÷'s dots, ='s gap), one width, × with
/// arms as long as +'s, centered in the key.
class _OpMarkPainter extends CustomPainter {
  const _OpMarkPainter(this.mark, this.color);
  final _OpMark mark;
  final Color color;

  /// The marks' width (about a digit's height) and their stroke (about a
  /// bold digit's).
  static const double width = 15, stroke = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    // Half a bar, between the centers of its round ends.
    const h = (width - stroke) / 2;
    void bar(double dy) =>
        canvas.drawLine(c + Offset(-h, dy), c + Offset(h, dy), p);
    switch (mark) {
      case _OpMark.plus:
        bar(0);
        canvas.drawLine(c + const Offset(0, -h), c + const Offset(0, h), p);
      case _OpMark.minus:
        bar(0);
      case _OpMark.times:
        const d = h / 1.4142;
        canvas.drawLine(c + const Offset(-d, -d), c + const Offset(d, d), p);
        canvas.drawLine(c + const Offset(-d, d), c + const Offset(d, -d), p);
      case _OpMark.divide:
        bar(0);
        final dot = Paint()
          ..color = color
          ..isAntiAlias = true;
        const r = stroke * .83, at = width * .313;
        canvas.drawCircle(c + const Offset(0, -at), r, dot);
        canvas.drawCircle(c + const Offset(0, at), r, dot);
      case _OpMark.equals:
        bar(-width * .1875);
        bar(width * .1875);
    }
  }

  @override
  bool shouldRepaint(_OpMarkPainter old) =>
      old.mark != mark || old.color != color;
}

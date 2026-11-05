// lib/features/sms/define_format_sheet.dart
// Defining a bank message's format: the message, with every number that
// could be the amount marked; the user taps the right one, says which way
// the money went and in which unit, and saves. Messages laid out the same
// way are read exactly from then on. Or: ignore the format (not
// transactions) or the sender (never read its messages). Both sheets here
// open from a tap on a message: the sender heads them, after the red close
// square (no Cancel; nothing to delete, messages stay).

import 'package:openfinances/shared/calendar_text.dart' show isFaUi;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/sms/bank_notifications.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/group_fit.dart';

/// Opens [m] the way it reads: a defined format goes straight to the add
/// sheet, an unknown one first to the define-format sheet (then the add
/// sheet, if saved).
Future<void> openBankMessage(BuildContext context, BankMessage m) async {
  final l = AppLocalizations.of(context)!;
  if (m.isIgnored) return _openIgnored(context, m);
  BankGuess? g = m.status == BankReadStatus.learned ? m.guesses.first : null;
  if (g == null) {
    final r = await showModalBottomSheet<(_Choice, BankGuess?, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => KeyboardInset(child: _DefineFormatSheet(message: m)),
    );
    if (r == null || !context.mounted) return;
    switch (r.$1) {
      case _Choice.ignoreFormat:
        await BankNotifications.ignore(m);
        return;
      case _Choice.ignoreSender:
        await BankNotifications.setSenderIgnored(m.sender, true);
        if (!context.mounted) return;
        showAppNotice(
          context,
          l.senderIgnored(m.sender),
          kind: NoticeKind.success,
          actionLabel: l.undo,
          onAction: () => BankNotifications.setSenderIgnored(m.sender, false),
        );
        return;
      case _Choice.save:
        g = r.$2!;
        await BankNotifications.confirm(m, g, name: r.$3);
    }
  }
  if (!context.mounted) return;
  await BankNotifications.addToLedger(
    context,
    key: m.key,
    recordedMinor: g.recordedMinor,
    unit: g.unit,
    kind: g.kind,
    date: m.date,
  );
}

/// An ignored message: the text, and a way to stop ignoring it (its
/// sender, or else its format).
Future<void> _openIgnored(BuildContext context, BankMessage m) async {
  final l = AppLocalizations.of(context)!;
  final sender = m.sender.isEmpty ? l.bankMessageFallback : m.sender;
  final scheme = Theme.of(context).colorScheme;
  final style = OutlinedButton.styleFrom(
    overlayColor: Colors.transparent,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide.none,
    backgroundColor: scheme.surfaceContainerHigh,
  );
  final restore = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetAmountHeader(
              title: sender,
              onClose: () => Navigator.of(sheet).pop(),
            ),
            const SizedBox(height: kSheetTitleGap),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkText(
                m.text,
                textDirection: RegExp(r'[؀-ۿ]').hasMatch(m.text)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.8),
              ),
            ),
            const SizedBox(height: kSheetRowGap),
            OutlinedButton(
              style: saveButtonStyle(sheet, style),
              onPressed: () => Navigator.of(sheet).pop(true),
              child: InkText(l.stopIgnoring),
            ),
          ],
        ),
      ),
    ),
  );
  if (restore != true) return;
  if (m.senderIgnored) {
    await BankNotifications.setSenderIgnored(m.sender, false);
  } else if (m.format != null) {
    await BankNotifications.deleteFormat(m.format!);
  }
}

enum _Choice { save, ignoreFormat, ignoreSender }

class _DefineFormatSheet extends StatefulWidget {
  const _DefineFormatSheet({required this.message});
  final BankMessage message;

  @override
  State<_DefineFormatSheet> createState() => _DefineFormatSheetState();
}

class _DefineFormatSheetState extends State<_DefineFormatSheet> {
  /// Each number that could be the amount, best guess first.
  late final List<BankGuess> _candidates = [
    for (final g in widget.message.guesses)
      if (_seen.add(g.runIndex)) g,
  ];
  final _seen = <int>{};
  late final List<TapGestureRecognizer> _taps = [
    for (var i = 0; i < _candidates.length; i++)
      TapGestureRecognizer()..onTap = () => _pick(i),
  ];

  int _selected = 0;
  late TransactionKind _kind =
      _candidates.firstOrNull?.kind ?? TransactionKind.expense;
  late String _unit = _candidates.firstOrNull?.unit ?? 'IRR';

  void _pick(int i) => setState(() {
    _selected = i;
    _kind = _candidates[i].kind;
    _unit = _candidates[i].unit;
  });

  BankGuess? get _guess {
    if (_candidates.isEmpty) return null;
    final c = _candidates[_selected];
    return BankGuess(c.amount, _unit, _kind, c.runIndex, c.start, c.end);
  }

  /// A name for the format (optional; the sender stands in).
  final _name = TextEditingController();

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currency = context.watch<SettingsProvider>().currencyCode;
    final fa = isFaUi(context);
    final m = widget.message;
    final text = m.text;
    final g = _guess;

    // The message, each candidate number tinted (the chosen one strongly).
    final order = [
      for (var i = 0; i < _candidates.length; i++)
        if (_candidates[i].start >= 0 &&
            _candidates[i].end <= text.length &&
            _candidates[i].start < _candidates[i].end)
          i,
    ]..sort((a, b) => _candidates[a].start.compareTo(_candidates[b].start));
    final spans = <InlineSpan>[];
    var at = 0;
    for (final i in order) {
      final c = _candidates[i];
      if (c.start < at) continue;
      spans.add(TextSpan(text: text.substring(at, c.start)));
      final on = i == _selected;
      spans.add(
        TextSpan(
          text: text.substring(c.start, c.end),
          recognizer: _taps[i],
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            backgroundColor: scheme.primary.withValues(alpha: on ? .4 : .14),
          ),
        ),
      );
      at = c.end;
    }
    spans.add(TextSpan(text: text.substring(at)));

    final buttonStyle = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(50),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
    );
    Widget button(
      String label,
      VoidCallback? onPressed, {
      ButtonStyle? style,
    }) => Expanded(
      child: OutlinedButton(
        style: style ?? buttonStyle,
        onPressed: onPressed,
        child: GroupFit(child: InkText(label)),
      ),
    );
    final shown = g == null
        ? ''
        : formatMinorWithCommas(g.shownMinor(currency));

    // The buttons' words one size (both rows).
    return FitGroup(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetAmountHeader(
                title: m.sender.isEmpty ? l.bankMessageFallback : m.sender,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: kSheetTitleGap),
              InkText(
                l.pickAmountHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant.withValues(alpha: .7),
                ),
              ),
              const SizedBox(height: kSheetRowGap),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  // The message's own direction (English bank texts too).
                  textDirection: RegExp(r'[؀-ۿ]').hasMatch(text)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  TextSpan(
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.8,
                    ),
                    children: spans,
                  ),
                ),
              ),
              const SizedBox(height: kSheetRowGap),
              InkField(
                controller: _name,
                hint: m.sender.isNotEmpty ? m.sender : l.formatName,
                builder: (shown) => TextField(
                  controller: _name,
                  textAlign: fa ? TextAlign.right : TextAlign.left,
                  decoration: entryFieldDecoration(
                    context,
                    shown: shown,
                    suffixIcon: ClearWhenFilled(
                      controller: _name,
                      onClear: _name.clear,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSheetRowGap),
              // What gets recorded, as the app shows amounts.
              InkText(
                faDigitsFor(fa) ? toFaDigits(shown) : shown,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: kSheetRowGap),
              SegmentedPills<TransactionKind>(
                selected: _kind,
                onChanged: (k) => setState(() => _kind = k),
                options: {
                  TransactionKind.expense: l.expenseShort,
                  TransactionKind.income: l.incomeTitle,
                },
              ),
              const SizedBox(height: kSheetRowGap),
              SegmentedPills<String>(
                selected: _unit,
                onChanged: (u) => setState(() => _unit = u),
                options: {'IRT': l.currencyToman, 'IRR': l.currencyRial},
              ),
              const SizedBox(height: kSheetRowGap),
              Row(
                children: [
                  if (m.sender.isNotEmpty) ...[
                    button(
                      l.ignoreSender,
                      () => Navigator.of(
                        context,
                      ).pop((_Choice.ignoreSender, null, '')),
                    ),
                    const SizedBox(width: 8),
                  ],
                  button(
                    l.ignoreFormat,
                    () => Navigator.of(
                      context,
                    ).pop((_Choice.ignoreFormat, null, '')),
                  ),
                ],
              ),
              const SizedBox(height: kSheetRowGap),
              Row(
                children: [
                  button(
                    l.saveFormat,
                    g == null
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop((_Choice.save, g, _name.text.trim())),
                    style: saveButtonStyle(context, buttonStyle),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

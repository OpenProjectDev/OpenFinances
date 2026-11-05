// lib/shared/ui/done_sheet.dart
// Something already paid (a settled debt's last payment, a paid upcoming
// item): its sheet again, filled with what was set, and buttons for what's
// left to do: Undo (take the payment back), Save (put it in History, or
// keep a change to the entry already there) and Delete (the debt or the
// item itself; the caller asks first). The red square in its header
// closes it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/date_picker.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/group_fit.dart';
import 'package:openfinances/shared/haptics.dart';

/// What the done sheet was left with.
enum DoneAction { undo, record, delete }

class DoneDraft {
  const DoneDraft(this.action, this.amountMinor, this.date);
  final DoneAction action;

  /// The fields (for [DoneAction.record]).
  final int amountMinor;
  final DateTime date;
}

/// Opens the done sheet: [title] and [headerAmount] on top, the payment's
/// [amountMinor] and [date] in the fields. [inHistory]: it's in History
/// already (Save stays grey until something changes). [extra]: a row over
/// the buttons (a debt's repayments).
Future<DoneDraft?> showDoneSheet(
  BuildContext context, {
  required String title,
  required int headerAmount,
  required int amountMinor,
  required DateTime date,
  required bool inHistory,
  Widget? extra,
}) {
  final sheet = DoneSheet(
    title: title,
    headerAmount: headerAmount,
    amountMinor: amountMinor,
    date: date,
    inHistory: inHistory,
    extra: extra,
  );
  return showModalBottomSheet<DoneDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => KeyboardInset(child: sheet),
  );
}

class DoneSheet extends StatefulWidget {
  const DoneSheet({
    super.key,
    required this.title,
    required this.headerAmount,
    required this.amountMinor,
    required this.date,
    required this.inHistory,
    this.extra,
  });

  final String title;
  final int headerAmount;

  /// What [headerAmount] is (e.g. a debt's "Total").
  final int amountMinor;
  final DateTime date;
  final bool inHistory;

  /// A row over the buttons.
  final Widget? extra;

  @override
  State<DoneSheet> createState() => _DoneSheetState();
}

class _DoneSheetState extends State<DoneSheet> {
  static const double _buttonHeight = 50;

  late final _amount = TextEditingController(
    text: formatMinorWithCommas(widget.amountMinor),
  );
  final _amountNode = FocusNode();
  late final DateTime _paidOn = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );
  late DateTime _date = _paidOn;
  bool _amountError = false;

  @override
  void dispose() {
    _amount.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  bool get _changed =>
      parseAmountMinor(_amount.text) != widget.amountMinor || _date != _paidOn;

  void _done(DoneAction action) {
    final amount = parseAmountMinor(_amount.text);
    if (action == DoneAction.record && (amount == null || amount <= 0)) {
      setState(() => _amountError = true);
      Haptics.alert(context);
      _amountNode.requestFocus();
      return;
    }
    Navigator.of(context).pop(DoneDraft(action, amount ?? 0, _date));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final calendar = context.watch<SettingsProvider>().calendar;
    final fa = isFaUi(context);
    final base = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(_buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      foregroundColor: scheme.onSurface,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    );
    Widget button(
      String text,
      VoidCallback? onPressed,
      ButtonStyle style, {
      Widget? icon,
    }) => Expanded(
      child: OutlinedButton(
        style: style,
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 8)],
            Flexible(child: GroupFit(child: InkText(text))),
          ],
        ),
      ),
    );

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetAmountHeader(
                title: widget.title,
                amount: uiDigits(
                  formatMinorWithCommas(widget.headerAmount),
                  fa,
                ),
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: kSheetTitleGap),
              AmountFieldRow(
                controller: _amount,
                focusNode: _amountNode,
                error: _amountError,
                hint: l.amountLabel,
                onChanged: (_) => setState(() => _amountError = false),
                onCalculated: () => setState(() => _amountError = false),
              ),
              const SizedBox(height: kSheetRowGap),
              SheetDateField(
                style: base.copyWith(
                  fixedSize: const WidgetStatePropertyAll(
                    Size.fromHeight(_buttonHeight),
                  ),
                ),
                label: formatDateForCalendar(_date, calendar, fa: fa),
                reset: DateUtils.isSameDay(_date, DateTime.now())
                    ? null
                    : () => setState(
                        () => _date = DateUtils.dateOnly(DateTime.now()),
                      ),
                onTap: () async {
                  final res = await pickSheetDate(
                    context,
                    _date,
                    pastOnly: true,
                  );
                  if (res != null && mounted) setState(() => _date = res);
                },
              ),
              const SizedBox(height: kSheetRowGap),
              if (widget.extra case final extra?) ...[
                extra,
                const SizedBox(height: kSheetRowGap),
              ],
              // Read from the start side: undo, save, delete (where the pay
              // sheet has pay, pay & add, delete); their words one size.
              FitGroup(
                child: Row(
                  children: [
                    button(l.undo, () => _done(DoneAction.undo), base),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        final ready =
                            (parseAmountMinor(_amount.text) ?? 0) > 0 &&
                            (!widget.inHistory || _changed);
                        return button(
                          l.debtRecordPaid,
                          ready ? () => _done(DoneAction.record) : null,
                          saveButtonStyle(context, base, ready),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    button(
                      l.delete,
                      () => Navigator.of(
                        context,
                      ).pop(DoneDraft(DoneAction.delete, 0, _date)),
                      cancelButtonStyle(base),
                      icon: const ImageIcon(AppIcons.trash, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

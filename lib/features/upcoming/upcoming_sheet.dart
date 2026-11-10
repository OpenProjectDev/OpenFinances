// lib/features/upcoming/upcoming_sheet.dart
// "Upcoming payments": the Incoming tab's list of planned payments, laid
// out like History's rows. A tap opens the payment's sheet (Paid / Pay &
// add / Pay & reschedule, and Edit for the editor: the owner, 2026-10-25,
// as debts do); paid ones stay, faded, after the rest: a tap opens the
// done sheet, to undo or put it in History. The add/edit editor has
// title-history suggestions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/shared/ui/split_chip.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/sheet_drafts.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/upcoming_repository.dart';
import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/date_picker.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/check_box.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/done_sheet.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/data/entry_suggestions.dart';
import 'package:openfinances/shared/ui/list_controls.dart';
import 'package:openfinances/shared/ui/swipe_row.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/group_fit.dart';
import 'package:openfinances/shared/ui/tile_pill.dart';
import 'package:openfinances/shared/ui/hold_tip.dart';
import 'package:openfinances/shared/haptics.dart';

const double _kButtonHeight = 50;

bool _isFa(BuildContext context) => isFaUi(context);

String _digits(BuildContext context, String s) =>
    faDigitsFor(_isFa(context)) ? toFaDigits(s) : s;

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

int _daysUntil(DateTime dueUtc) {
  final d = dueUtc.toLocal();
  return DateTime(d.year, d.month, d.day).difference(_today()).inDays;
}

// ============================================================================
// Incoming view (the Expenses page's "Incoming" tab)
// ============================================================================

/// The total of everything scheduled (with the soonest due date, or how
/// many are overdue, under it), sort and today, the categories ranked by
/// their total, and the list (adding is the bottom bar's "+"). Meant to fill the rest of a page: wrap
/// it in an `Expanded`.
class UpcomingView extends StatefulWidget {
  const UpcomingView({super.key, this.gutter = 12});
  final double gutter;

  @override
  State<UpcomingView> createState() => _UpcomingViewState();
}

class _UpcomingViewState extends State<UpcomingView> {
  bool _byAmount = false; // false: soonest due first; true: largest first
  String? _cat; // the category chosen in the chips row
  // Today's date chip: back to the top; kept where it was left, while
  // "keep place" is on.
  late final RememberedScroll _list;

  @override
  void initState() {
    super.initState();
    _list = RememberedScroll('upcoming', context.read<SettingsProvider>());
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  /// Under the total: how many are overdue, else when the next one is due.
  String _totalLabel(AppLocalizations l, List<UpcomingDto> items) {
    if (items.isEmpty) return l.nothingDue;
    final overdue = items.where((e) => _daysUntil(e.dueAtUtc) < 0).length;
    if (overdue > 0) return l.overdueCount(_digits(context, '$overdue'));
    final days = _daysUntil(items.first.dueAtUtc); // soonest first
    return l.nextDue(switch (days) {
      0 => l.dueToday,
      1 => l.dueTomorrow,
      _ => l.dueInDays(_digits(context, '$days')),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final up = context.watch<UpcomingProvider>();
    // The categories' order only (any ledger change rebuilt the list).
    final categories = context.select((ExpenseProvider ep) => ep.categories);
    final overdue = up.hasOverdue;
    final gutter = widget.gutter;
    // The page extends under the bottom bar; this includes the bar's height.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final perCat = <String, int>{};
    for (final e in up.items) {
      final c = e.categoryGid;
      if (c == null || c.isEmpty) continue;
      perCat.update(c, (t) => t + e.amountMinor, ifAbsent: () => e.amountMinor);
    }
    // Only paid ones left: it stays, with nothing on it, greyed (as Debts'
    // people; the owner, 2026-11-02).
    for (final e in up.paid) {
      final c = e.categoryGid;
      if (c != null && c.isNotEmpty) perCat.putIfAbsent(c, () => 0);
    }
    final cat = perCat.containsKey(_cat) ? _cat : null;
    final shown = [
      for (final e in up.items)
        if (cat == null || e.categoryGid == cat) e,
    ];
    // By due date (the list's own order), same day by category order; by
    // amount, equal amounts soonest first.
    final catRank = {for (final (i, c) in categories.indexed) c.gid: i};
    int rank(UpcomingDto e) => catRank[e.categoryGid] ?? 1 << 30;
    DateTime day(UpcomingDto e) {
      final t = e.dueAtUtc.toLocal();
      return DateTime(t.year, t.month, t.day);
    }

    final items = [
      ...shown..sort((a, b) {
        if (_byAmount) {
          final c = b.amountMinor.compareTo(a.amountMinor);
          if (c != 0) return c;
        }
        final d = day(a).compareTo(day(b));
        if (d != 0) return d;
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.dueAtUtc.compareTo(b.dueAtUtc);
      }),
    ];
    // Paid ones in a section of their own (closed at first; most recently
    // paid first), as Debts' and SMS's (the owner, 2026-10-31: they were
    // faded after the rest).
    final paid = [
      for (final e in up.paid)
        if (cat == null || e.categoryGid == cat) e,
    ];

    // A section of payments (or a faint line when it has none): its rows
    // built as they scroll into view.
    Widget section(
      String id,
      String title,
      List<UpcomingDto> list,
      String none, {
      bool open = false,
    }) => FoldSection.sliver(
      id: id,
      title: title,
      initiallyOpen: open,
      itemCount: list.isEmpty ? 1 : list.length,
      itemBuilder: (_, i) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkText(
                none,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: .7),
                ),
              ),
            )
          : _UpcomingTile(item: list[i]),
    );
    Color? colorOf(String gid) {
      for (final c in categories) {
        if (c.gid == gid) return Color(c.color);
      }
      return null;
    }

    final fg = overdue ? Colors.white : context.textOnStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Total (strong red while something is overdue), like History's
        // tiles: the number, and a small line under it.
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: overdue ? kStrongRed : scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkText(
                  _digits(context, formatMinorWithCommas(up.totalMinor)),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 6),
                InkText(
                  _totalLabel(l, up.items),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: fg.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
          child: ListControlsRow(
            byAmount: _byAmount,
            onSort: () => setState(() => _byAmount = !_byAmount),
            list: _list,
          ),
        ),
        // A row of one chip has nothing to choose between.
        if (perCat.length >= 2)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
            child: TotalChipsRow(
              selected: cat,
              onSelect: (c) => setState(() => _cat = c),
              chips: [
                for (final MapEntry(key: gid, value: t) in perCat.entries)
                  TotalChip(
                    id: gid,
                    label: context.read<ExpenseProvider>().categoryName(gid),
                    total: t,
                    color: colorOf(gid) ?? scheme.secondaryContainer,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Expanded(
          child: items.isEmpty && paid.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Center(
                    child: InkText(
                      l.upcomingEmpty,
                      maxLines: 1,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : CustomScrollView(
                  controller: _list,
                  slivers: [
                    SliverPadding(
                      // Clear of the bottom bar (the page extends under it).
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        2,
                        gutter,
                        bottomInset + 16,
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          section(
                            'upcoming.due',
                            l.upcomingDueSection,
                            items,
                            l.upcomingEmpty,
                            open: true,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          section(
                            'upcoming.paid',
                            l.upcomingPaidSection,
                            paid,
                            l.upcomingNothingPaid,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The title | the amount; then the category, and at the end the due date
/// and the days, left or late (a number chip; a touch says which; red once
/// due; the
/// owner, 2026-10-31: the category gets the room the date and days leave,
/// it wrapped beside a date and days in one pill); the note. Paid (in the Paid section): the day it was paid
/// instead of the due date and days.
/// A tap opens its sheet (paid: the done sheet); swiped like History's
/// rows (start→end deletes, end→start edits).
class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.item});
  final UpcomingDto item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Only what the row shows (it was rebuilt on any settings or ledger
    // change).
    final calendar = context.select((SettingsProvider s) => s.calendar);
    final (catColor, catName) = context.select((ExpenseProvider ep) {
      Color? found;
      for (final c in ep.categories) {
        if (c.gid == item.categoryGid) found = Color(c.color);
      }
      return (found, ep.categoryName(item.categoryGid));
    });
    final fa = _isFa(context);
    // In its section: the pills a step above the tile, the days a step
    // above them.
    final pill = context.raisedBy(2);
    final catBg = catColor ?? pill;
    final catFg = catColor == null ? scheme.onSurfaceVariant : onColor(catBg);

    final paid = item.isPaid;
    final days = _daysUntil(item.dueAtUtc);
    final late = !paid && days <= 0;
    // The second row: paid, the day; else the date, and the days left in
    // two parts (today: one red chip).
    final Widget due;
    if (paid) {
      due = TilePill(
        text: l.upcomingPaidOn(
          dayTitle(item.paidAtUtc!.toLocal(), calendar, fa),
        ),
        background: pill,
        foreground: scheme.onSurfaceVariant,
      );
    } else {
      final date = TilePill(
        text: dayTitle(item.dueAtUtc.toLocal(), calendar, fa),
        background: pill,
        foreground: scheme.onSurfaceVariant,
      );
      final Widget left = days == 0
          ? TilePill(
              text: l.dueToday,
              background: kStrongRed,
              foreground: Colors.white,
            )
          // Just the number, one width for up to three digits (more:
          // ∞); a touch says how many days, left or late (the owner,
          // 2026-10-31: the words crowded the row).
          : HoldTip(
              message: switch (days) {
                -1 => l.overdueOneDay(_digits(context, '1')),
                < 0 => l.overdueDays(_digits(context, '${-days}')),
                1 => l.dueInOneDay(_digits(context, '1')),
                _ => l.dueInDays(_digits(context, '$days')),
              },
              child: SizedBox(
                width: TilePill.widthOf(context, _digits(context, '000')),
                child: TilePill(
                  text: days.abs() > 999
                      ? '∞'
                      : _digits(context, '${days.abs()}'),
                  background: late ? kStrongRed : context.raisedBy(3),
                  foreground: late ? Colors.white : scheme.onSurface,
                ),
              ),
            );
      due = Row(
        mainAxisSize: MainAxisSize.min,
        children: [date, const SizedBox(width: 8), left],
      );
    }
    final note = item.note?.trim() ?? '';
    const radius = 14.0;

    return SwipeRow.editDelete(
      context: context,
      dismissKey: ValueKey('up_${item.gid}'),
      radius: radius,
      confirmDelete: () => confirmDeleteSheet(
        context,
        title: l.deleteUpcomingTitle,
        message: l.deleteUpcomingConfirm,
      ),
      onDelete: () => context.read<UpcomingProvider>().delete(item.gid),
      onEdit: () => _editFlow(context, item),
      child: Material(
        color: context.raised,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () =>
              paid ? _doneFlow(context, item) : _openFlow(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // History's sizes: title 15, amount 20.
                Row(
                  children: [
                    Expanded(
                      child: InkText(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkText(
                      _digits(context, formatMinorWithCommas(item.amountMinor)),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // The category at the start, with all the room the date and
                // the days leave it; they at the end.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TilePill(
                        text: catName,
                        background: catBg,
                        foreground: catFg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    due,
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: pill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkText(
                      note,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the payment's sheet was left with.
enum _UpAction { paid, payAndReschedule, edit, delete }

/// The sheet's choice, with its Record box and the amount paid (display
/// unit; null: as the item says).
typedef _UpChoice = ({_UpAction action, bool record, int? amountMinor});

/// A payment's sheet: the red close square, Edit, its title and its amount
/// on a two-tone chip with a pencil (tapped, the chip turns into an amount
/// field with the calculator: paid a different amount this time); then the
/// Record box (paying also records an expense in History; kept as last
/// left) beside Delete (asked first), and Paid / Pay & reschedule (the next
/// one planned). The owner, 2026-10-27: Pay & add went for the box, so
/// either way of paying can record or not.
class _UpcomingActions extends StatefulWidget {
  const _UpcomingActions({required this.item});
  final UpcomingDto item;

  @override
  State<_UpcomingActions> createState() => _UpcomingActionsState();
}

class _UpcomingActionsState extends State<_UpcomingActions> {
  late final _amount = TextEditingController(
    text: formatMinorWithCommas(widget.item.amountMinor),
  );
  final _amountNode = FocusNode();

  /// The amount chip turned into its field.
  bool _editingAmount = false;
  bool _amountError = false;

  @override
  void dispose() {
    _amount.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  void _editAmount() {
    setState(() => _editingAmount = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _amountNode.requestFocus();
      _amount.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amount.text.length,
      );
    });
  }

  void _pay(_UpAction action) {
    int? amount;
    if (_editingAmount) {
      amount = parseAmountMinor(_amount.text);
      if (amount == null || amount <= 0) {
        setState(() => _amountError = true);
        Haptics.alert(context);
        return;
      }
    }
    Navigator.of(context).pop<_UpChoice>((
      action: action,
      record: context.read<SettingsProvider>().recordDuePaid,
      amountMinor: amount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final record = context.select((SettingsProvider s) => s.recordDuePaid);
    final base = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(_kButtonHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    );
    Widget button(
      String text,
      VoidCallback onPressed,
      ButtonStyle style, {
      Widget? icon,
    }) => OutlinedButton(
      style: style,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 8)],
          Flexible(child: GroupFit(child: InkText(text))),
        ],
      ),
    );
    final red = cancelButtonStyle(base);
    final save = saveButtonStyle(context, base);
    void close() => Navigator.of(context).pop();
    void edit() => Navigator.of(context).pop<_UpChoice>((
      action: _UpAction.edit,
      record: false,
      amountMinor: null,
    ));

    // The Record box: a chip like the buttons, its checkbox at the start.
    final recordChip = GestureDetector(
      onTap: () => context.read<SettingsProvider>().setRecordDuePaid(!record),
      child: Container(
        height: _kButtonHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CheckBoxMark(
              on: record,
              color: scheme.primary,
              checkColor: context.textOnStrong,
              outline: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: GroupFit(
                child: InkText(
                  l.recordPaid,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetAmountHeader(
              title: widget.item.title,
              onEdit: edit,
              onClose: close,
            ),
            const SizedBox(height: kSheetTitleGap),
            // The amount, a row of its own (the title had little room beside
            // it: the owner, 2026-11-01); a tap turns it into a field (and
            // its calculator).
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _editingAmount
                  ? AmountFieldRow(
                      controller: _amount,
                      focusNode: _amountNode,
                      error: _amountError,
                      hint: l.amountLabel,
                      onChanged: (_) {
                        if (_amountError) {
                          setState(() => _amountError = false);
                        }
                      },
                      onCalculated: () {
                        if (_amountError) {
                          setState(() => _amountError = false);
                        }
                      },
                    )
                  : _AmountEditChip(
                      amount: _digits(
                        context,
                        formatMinorWithCommas(widget.item.amountMinor),
                      ),
                      onTap: _editAmount,
                    ),
            ),
            const SizedBox(height: kSheetTitleGap),
            FitGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: recordChip),
                      const SizedBox(width: 8),
                      Expanded(
                        child: button(
                          l.delete,
                          () => Navigator.of(context).pop<_UpChoice>((
                            action: _UpAction.delete,
                            record: false,
                            amountMinor: null,
                          )),
                          red,
                          icon: const ImageIcon(AppIcons.trash, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSheetRowGap),
                  Row(
                    children: [
                      Expanded(
                        child: button(
                          l.markPaid,
                          () => _pay(_UpAction.paid),
                          save,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: button(
                          l.payAndReschedule,
                          () => _pay(_UpAction.payAndReschedule),
                          save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A due payment's amount on a two-tone chip, a pencil on its first part:
/// tapped, it turns into an amount field (the owner, 2026-10-27: paid a
/// little different, just before marking it paid). As tall as the header's
/// squares.
class _AmountEditChip extends StatelessWidget {
  const _AmountEditChip({required this.amount, required this.onTap});
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.edit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SplitChip(
          height: 50,
          parts: [
            Container(
              width: 50,
              alignment: Alignment.center,
              color: scheme.surfaceContainerHighest,
              child: ImageIcon(
                AppIcons.edit,
                size: 18,
                color: context.primaryInk,
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                color: scheme.surfaceContainerHigh,
                child: InkText(
                  amount,
                  style: const TextStyle(
                    fontSize: kSheetTitleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Flows
// ============================================================================

/// A payment's sheet, then what was picked there.
Future<void> _openFlow(BuildContext context, UpcomingDto item) async {
  final up = context.read<UpcomingProvider>();
  final ep = context.read<ExpenseProvider>();
  final choice = await showModalBottomSheet<_UpChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Its amount can turn into a field: lifted above the keyboard.
    builder: (_) => KeyboardInset(child: _UpcomingActions(item: item)),
  );
  if (choice == null || !context.mounted) return;
  // Recorded in History only with the sheet's Record box ticked.
  final ledger = choice.record ? ep : null;
  switch (choice.action) {
    case _UpAction.paid:
      await up.markPaid(item, ledger, amountMinor: choice.amountMinor);
    case _UpAction.payAndReschedule:
      await _payAndRescheduleFlow(
        context,
        item,
        record: choice.record,
        amountMinor: choice.amountMinor,
      );
    case _UpAction.edit:
      await _editFlow(context, item);
    case _UpAction.delete:
      final l = AppLocalizations.of(context)!;
      final ok = await confirmDeleteSheet(
        context,
        title: l.deleteUpcomingTitle,
        message: l.deleteUpcomingConfirm,
      );
      if (ok) await up.delete(item.gid);
  }
}

/// Opens the editor for a new upcoming payment (the bottom bar's "+" on
/// the Incoming tab).
Future<void> addUpcoming(BuildContext context) async {
  final up = context.read<UpcomingProvider>();
  final currency = context.read<SettingsProvider>().currencyCode;
  final res = await _showEditor(context, mode: _EditorMode.add);
  if (res?.draft == null) return;
  final d = res!.draft!;
  await up.add(
    title: d.title,
    amountMinor: d.amountMinor,
    dueLocal: d.dueLocal,
    note: d.note,
    categoryGid: d.categoryGid,
    currency: currency,
  );
}

Future<void> _editFlow(BuildContext context, UpcomingDto item) async {
  final up = context.read<UpcomingProvider>();
  final res = await _showEditor(
    context,
    mode: _EditorMode.edit,
    initial: _Draft.fromItem(item),
  );
  if (res == null) return;
  if (res.delete) {
    await up.delete(item.gid);
    return;
  }
  final d = res.draft;
  if (d == null) return;
  await up.update(
    item.gid,
    title: d.title,
    amountMinor: d.amountMinor,
    dueLocal: d.dueLocal,
    note: d.note,
    categoryGid: d.categoryGid,
  );
}

/// Opens the editor prefilled for the next occurrence (due + 1 month in the
/// user's calendar; the amount just paid, [amountMinor] if it was changed).
/// Only on save is the current one marked paid ([record]: and recorded in
/// History) and the next one scheduled — cancelling changes nothing.
Future<void> _payAndRescheduleFlow(
  BuildContext context,
  UpcomingDto item, {
  required bool record,
  int? amountMinor,
}) async {
  final up = context.read<UpcomingProvider>();
  final ep = context.read<ExpenseProvider>();
  final calendar = context.read<SettingsProvider>().calendar;

  final base = _Draft.fromItem(item);
  final res = await _showEditor(
    context,
    mode: _EditorMode.reschedule,
    initial: base.copyWith(
      dueLocal: addOneMonthForCalendar(base.dueLocal, calendar),
      amountMinor: amountMinor,
    ),
  );
  final d = res?.draft;
  if (d == null) return;

  final next = await up.add(
    title: d.title,
    amountMinor: d.amountMinor,
    dueLocal: d.dueLocal,
    note: d.note,
    categoryGid: d.categoryGid,
    currency: item.currency,
  );
  // Undoing this payment takes the next one back too.
  await up.markPaid(
    item,
    record ? ep : null,
    nextGid: next,
    amountMinor: amountMinor,
  );
}

/// A paid item: the done sheet, filled with what was paid and when. Undo:
/// due again (its expense, and the next one "Pay & reschedule" added, go);
/// Save: into History, or a change kept in the expense already there;
/// Delete: the item (asked first).
Future<void> _doneFlow(BuildContext context, UpcomingDto item) async {
  final up = context.read<UpcomingProvider>();
  final ep = context.read<ExpenseProvider>();
  final inHistory = await up.ledgerEntryOf(item) != null;
  if (!context.mounted) return;
  final res = await showDoneSheet(
    context,
    title: item.title,
    headerAmount: item.amountMinor,
    amountMinor: item.amountMinor,
    date: item.paidAtUtc!.toLocal(),
    inHistory: inHistory,
  );
  if (res == null) return;
  if (res.action == DoneAction.undo) {
    await up.undoPaid(item, ep);
    return;
  }
  if (res.action == DoneAction.delete) {
    if (!context.mounted) return;
    final l = AppLocalizations.of(context)!;
    final ok = await confirmDeleteSheet(
      context,
      title: l.deleteUpcomingTitle,
      message: l.deleteUpcomingConfirm,
    );
    if (ok) await up.delete(item.gid);
    return;
  }
  await up.recordPaid(
    item,
    amountMinor: res.amountMinor,
    paidLocal: res.date,
    expenses: ep,
  );
}

// ============================================================================
// Editor
// ============================================================================

enum _EditorMode { add, edit, reschedule }

class _Draft {
  final String title;
  final int amountMinor;
  final DateTime dueLocal;
  final String? categoryGid;
  final String? note;

  const _Draft({
    required this.title,
    required this.amountMinor,
    required this.dueLocal,
    this.categoryGid,
    this.note,
  });

  factory _Draft.fromItem(UpcomingDto e) {
    final d = e.dueAtUtc.toLocal();
    return _Draft(
      title: e.title,
      amountMinor: e.amountMinor,
      dueLocal: DateTime(d.year, d.month, d.day),
      categoryGid: e.categoryGid,
      note: e.note,
    );
  }

  _Draft copyWith({DateTime? dueLocal, int? amountMinor}) => _Draft(
    title: title,
    amountMinor: amountMinor ?? this.amountMinor,
    dueLocal: dueLocal ?? this.dueLocal,
    categoryGid: categoryGid,
    note: note,
  );
}

class _EditorResult {
  final _Draft? draft;
  final bool delete;
  const _EditorResult.save(this.draft) : delete = false;
  const _EditorResult.delete() : draft = null, delete = true;
}

Future<_EditorResult?> _showEditor(
  BuildContext context, {
  required _EditorMode mode,
  _Draft? initial,
}) {
  final editor = _UpcomingEditor(mode: mode, initial: initial);
  return showModalBottomSheet<_EditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // One editor instance, reused on every builder call (the route re-runs
    // it each keyboard frame); only KeyboardInset rebuilds.
    builder: (_) => KeyboardInset(child: editor),
  );
}

/// Laid out like the add sheet: no title or labels (centered faint
/// placeholders), title suggestion chips (the expense titles, History's
/// and Due's), the calculator, due date and category side by
/// side, the note.
class _UpcomingEditor extends StatefulWidget {
  const _UpcomingEditor({required this.mode, this.initial});
  final _EditorMode mode;
  final _Draft? initial;

  @override
  State<_UpcomingEditor> createState() => _UpcomingEditorState();
}

class _UpcomingEditorState extends State<_UpcomingEditor> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  final _titleNode = FocusNode();
  final _amountNode = FocusNode();

  // What the user typed (picking a chip resets it, so the row goes back to
  // its unfiltered list).
  final _titleQuery = ValueNotifier<String>('');
  late final _noteFold = NoteFold(_note);

  late DateTime _due;
  late String _categoryGid;
  bool _titleError = false;
  bool _amountError = false;

  bool get _adding => widget.mode == _EditorMode.add;

  // A new one keeps what a cancelled one left ("keep entries").
  late final bool _drafts = _adding && widget.initial == null;
  late final SettingsProvider _settings;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    final i = widget.initial;
    _title = TextEditingController(text: i?.title ?? '');
    _amount = TextEditingController(
      text: i == null ? '' : formatMinorWithCommas(i.amountMinor),
    );
    _note = TextEditingController(text: i?.note ?? '');
    _due = i?.dueLocal ?? _today();
    _categoryGid =
        i?.categoryGid ?? context.read<ExpenseProvider>().fallbackCategoryGid;
    // Read the starting values now (they're late).
    _startTitle;
    _startAmount;
    _startNote;
    _startDue;
    _startCategory;
    final draft = _drafts ? SheetDrafts.of(_settings, 'upcoming') : null;
    if (draft != null) {
      _title.text = draft['title'] as String;
      _amount.text = draft['amount'] as String;
      _note.text = draft['note'] as String;
      _due = draft['date'] as DateTime;
      _categoryGid = draft['category'] as String;
    }
    // Keyboard after the sheet has slid up, not during.
    if (_adding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusAfterRouteOpens(context, _titleNode);
      });
    }
  }

  @override
  void dispose() {
    if (_drafts) {
      _saved
          ? SheetDrafts.saved('upcoming')
          : SheetDrafts.closed(
              _settings,
              'upcoming',
              changed: _anyChange,
              values: {
                'title': _title.text,
                'amount': _amount.text,
                'note': _note.text,
                'date': _due,
                'category': _categoryGid,
              },
            );
    }
    _title.dispose();
    _amount.dispose();
    _noteFold.dispose();
    _note.dispose();
    _titleNode.dispose();
    _amountNode.dispose();
    _titleQuery.dispose();
    super.dispose();
  }

  void _setText(TextEditingController c, String t) =>
      c.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );

  /// A title chip: the title, and the category it had last time (if it's
  /// still there), then on to the amount. Never the amount's value (the
  /// owner, 2026-10-25: suggested amounts only had to be erased).
  void _pickTitle(String title, EntrySuggestions sugg) {
    _setText(_title, title);
    _titleQuery.value = '';
    _amountNode.requestFocus();
    final cat = sugg.categoryFor(title);
    final known =
        cat != null &&
        context.read<ExpenseProvider>().categories.any((c) => c.gid == cat);
    setState(() {
      if (known) _categoryGid = cat;
      _titleError = false;
    });
  }

  Future<void> _pickDue() async {
    final res = await pickSheetDate(context, _due, futureOnly: true);
    if (res != null && mounted) setState(() => _due = res);
  }

  // How the form started (Save waits for a change when editing).
  late final String _startTitle = _title.text;
  late final String _startAmount = _amount.text;
  late final String _startNote = _note.text;
  late final DateTime _startDue = _due;
  late final String _startCategory = _categoryGid;

  bool get _anyChange =>
      _title.text != _startTitle ||
      _amount.text != _startAmount ||
      _note.text != _startNote ||
      _due != _startDue ||
      _categoryGid != _startCategory;

  /// An edit that changed nothing has nothing to save (paying and
  /// rescheduling always has).
  bool get _unchangedEdit => widget.mode == _EditorMode.edit && !_anyChange;

  /// Save is grey until it can save: a title and an amount, and (editing)
  /// something changed.
  bool get _ready {
    final amount = parseAmountMinor(_amount.text);
    return _title.text.trim().isNotEmpty &&
        amount != null &&
        amount > 0 &&
        !_unchangedEdit;
  }

  void _save() {
    final title = _title.text.trim();
    final amountMinor = parseAmountMinor(_amount.text);
    final titleOk = title.isNotEmpty;
    final amountOk = amountMinor != null && amountMinor > 0;
    if (!titleOk || !amountOk) {
      setState(() {
        _titleError = !titleOk;
        _amountError = !amountOk;
      });
      Haptics.alert(context);
      (!titleOk ? _titleNode : _amountNode).requestFocus();
      return;
    }

    final note = _note.text.trim();
    _saved = true;
    Navigator.of(context).pop(
      _EditorResult.save(
        _Draft(
          title: title,
          amountMinor: amountMinor,
          dueLocal: _due,
          categoryGid: _categoryGid,
          note: note.isEmpty ? null : note,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmDeleteSheet(
      context,
      title: l.deleteUpcomingTitle,
      message: l.deleteUpcomingConfirm,
    );
    if (ok && mounted) {
      Navigator.of(context).pop(const _EditorResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final up = context.watch<UpcomingProvider>();
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final saveLabel = switch (widget.mode) {
      _EditorMode.add => l.save,
      _EditorMode.edit => l.saveChanges,
      _EditorMode.reschedule => l.payAndReschedule,
    };

    // Suggestions: the expense titles, History's and Due's (one list with
    // the add sheet's; the owner, 2026-10-27), most used first.
    final sugg = EntrySuggestions.ofExpenses(
      context.watch<ExpenseProvider>().raw,
      up.history,
    );
    bool hide(String t, String? c) =>
        hiddenTitleSuggestion(settings, SuggestSource.expense, t, c);
    // Suggestion rows only with suggestions on and something to offer;
    // without one, the field is just a row of the form.
    final showTitles =
        settings.suggestionsOn && sugg.titles(hide: hide).isNotEmpty;
    final fieldStyle = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      fixedSize: const Size.fromHeight(_kButtonHeight),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      backgroundColor: scheme.surfaceContainerHigh,
      foregroundColor: scheme.onSurface,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final actionStyle = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(_kButtonHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
    );

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Title + titles used before
              InkField(
                controller: _title,
                hint: l.upcomingTitleHint,
                builder: (shown) => TextField(
                  controller: _title,
                  focusNode: _titleNode,
                  autofocus: false, // see focusAfterRouteOpens in initState
                  textInputAction: TextInputAction.next,
                  textAlign: rtl ? TextAlign.right : TextAlign.left,
                  onChanged: (t) {
                    _titleQuery.value = t;
                    if (_titleError) setState(() => _titleError = false);
                  },
                  onSubmitted: (_) => _amountNode.requestFocus(),
                  decoration: entryFieldDecoration(
                    context,
                    shown: shown,
                    error: _titleError,
                    suffixIcon: ClearWhenFilled(
                      controller: _title,
                      onClear: () {
                        _title.clear();
                        _titleQuery.value = '';
                        _titleNode.requestFocus();
                      },
                    ),
                  ),
                ),
              ),
              showTitles
                  ? SuggestionsSlot(
                      controller: _title,
                      focusNode: _titleNode,
                      row: ValueListenableBuilder<String>(
                        valueListenable: _titleQuery,
                        builder: (_, q, _) {
                          final titles = sugg.titles(query: q, hide: hide);
                          return SuggestionChipsRow(
                            key: ValueKey('t$q'),
                            labels: titles,
                            emptyText: l.noMatch,
                            onTap: (i) => _pickTitle(titles[i], sugg),
                            onLongPress: (i) => ignoreTitleSuggestion(
                              context,
                              SuggestSource.expense,
                              titles[i],
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox(height: kSheetRowGap),

              // ---- Amount (+ calculator) and the note's chip, its field under them
              NoteRow(
                fold: _noteFold,
                field: AmountFieldRow(
                  controller: _amount,
                  focusNode: _amountNode,
                  error: _amountError,
                  hint: l.amountLabel,
                  onChanged: (_) {
                    if (_amountError) setState(() => _amountError = false);
                  },
                  onCalculated: () {
                    if (_amountError) setState(() => _amountError = false);
                  },
                ),
              ),
              const SizedBox(height: kSheetRowGap),
              NoteSection(fold: _noteFold),

              // ---- Due date (as wide as it needs) / category (the rest:
              // a long name has room)
              Row(
                children: [
                  IntrinsicWidth(
                    child: SheetDateField(
                      style: fieldStyle,
                      label: formatDateForCalendar(
                        _due,
                        settings.calendar,
                        fa: _isFa(context),
                      ),
                      onTap: _pickDue,
                      reset: DateUtils.isSameDay(_due, DateTime.now())
                          ? null
                          : () => setState(
                              () => _due = DateUtils.dateOnly(DateTime.now()),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CategoryPickerButton(
                      kind: TransactionKind.expense,
                      initialCategoryGid: _categoryGid,
                      onChanged: (gid) => setState(() => _categoryGid = gid),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSheetRowGap),

              // ---- Actions
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(
                      child: CancelButton(
                        height: _kButtonHeight,
                        onCancel: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_title, _amount, _note]),
                        builder: (context, _) => OutlinedButton(
                          style: saveButtonStyle(context, actionStyle, _ready),
                          onPressed: _unchangedEdit ? null : _save,
                          child: InkText(saveLabel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.mode == _EditorMode.edit) ...[
                const SizedBox(height: kSheetRowGap),
                OutlinedButton.icon(
                  icon: const ImageIcon(AppIcons.trash, size: 18),
                  style: actionStyle.copyWith(
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    backgroundColor: const WidgetStatePropertyAll(kStrongRed),
                  ),
                  onPressed: _confirmDelete,
                  label: InkText(l.delete),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

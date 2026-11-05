// lib/features/debts/debts_view.dart
// The Expenses page's "Debts" tab: what I owe and what I'm owed, each debt
// paid off in parts. Tap a debt to record a payment (and, with the second
// button, add it to the ledger too); a settled one shows its last payment,
// to undo it or put it in History. Swipe a debt to edit or delete, like the
// History rows. Under the totals: All / sort / today, then people chips,
// then two folding sections: Ongoing and Paid (like Bank's New and Seen).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/keep_in_view.dart';
import 'package:openfinances/shared/sheet_drafts.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/dual_chip.dart';
import 'package:openfinances/shared/ui/percent_text.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/debt_repository.dart';
import 'package:openfinances/data/entry_suggestions.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/date_picker.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/done_sheet.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/list_controls.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/ui/swipe_row.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/group_fit.dart';
import 'package:openfinances/shared/ui/hold_tip.dart';
import 'package:openfinances/shared/ui/tile_pill.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/haptics.dart';

const double _kRowRadius = 14;
const double _kButtonHeight = 50;
const double _kRowGap = kSheetRowGap;

/// "Owed to me" green (white text on it in both themes), like the Income
/// total tile.
const Color _owedGreen = Color(0xFF2E7D32);

bool _isFa(BuildContext context) => isFaUi(context);

String _digits(BuildContext context, String s) =>
    faDigitsFor(_isFa(context)) ? toFaDigits(s) : s;

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ============================================================================
// Debts view
// ============================================================================

/// Two totals (what I owe / what I'm owed; tap one to show only that side)
/// and the debts (open ones in Ongoing, settled ones in Paid); adding
/// is the bottom bar's "+". Meant to fill the rest of a page: wrap it in an `Expanded`.
class DebtsView extends StatefulWidget {
  const DebtsView({super.key, this.gutter = 12});
  final double gutter;

  @override
  State<DebtsView> createState() => _DebtsViewState();
}

class _DebtsViewState extends State<DebtsView> {
  /// The side picked (a tile tapped; null: both, All tapped); only when
  /// [_picked], else the default ([_shown]).
  static DebtDirection? _only;
  static bool _picked = false;

  /// The side shown (null: both); a new debt starts on it.
  static DebtDirection? _shown;

  /// The person chosen in the chips row (null: everyone).
  String? _person;
  // Today's date chip: back to the top; kept where it was left, while
  // "keep place" is on.
  late final RememberedScroll _list;

  @override
  void initState() {
    super.initState();
    _list = RememberedScroll('debts', context.read<SettingsProvider>());
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  bool _byAmount = false; // false: as listed (due first); true: largest first

  void _toggle(DebtDirection d) => _show(_shown == null ? d : null);

  void _show(DebtDirection? d) => setState(() {
    _picked = true;
    _only = d;
    _person = null; // the other side has other people
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final dp = context.watch<DebtProvider>();
    final gutter = widget.gutter;
    // The page extends under the bottom bar; this includes the bar's height.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Both side tiles, tap one to see only that side (All back to both).
    // By default both show; when one side has nothing open (a total of 0:
    // paid debts or none), the view starts as if the other side's tile had
    // been tapped. With nothing open on either side, any debts decide.
    final anyOpen = dp.open.isNotEmpty;
    bool has(DebtDirection d) =>
        (anyOpen ? dp.open : dp.settled).any((v) => v.debt.direction == d);
    final defaultSide = !has(DebtDirection.owed) && has(DebtDirection.owe)
        ? DebtDirection.owe
        : !has(DebtDirection.owe) && has(DebtDirection.owed)
        ? DebtDirection.owed
        : null;
    final only = _picked ? _only : defaultSide;
    _shown = only;
    final VoidCallback? backToAll = only == null ? null : () => _show(null);

    bool onSide(DebtView v) => only == null || v.debt.direction == only;
    bool shown(DebtView v) =>
        onSide(v) && (_person == null || v.debt.person == _person);
    int left(DebtView v) => v.isSettled ? v.debt.amountMinor : v.remainingMinor;
    // Equal amounts keep the listed order (due date first).
    List<DebtView> sorted(Iterable<DebtView> l) {
      final list = l.toList();
      if (!_byAmount) return list;
      final at = {for (final (i, v) in list.indexed) v: i};
      return list..sort((a, b) {
        final c = left(b).compareTo(left(a));
        return c != 0 ? c : at[a]!.compareTo(at[b]!);
      });
    }

    // Open ones in Ongoing, settled ones in Paid.
    final ongoing = sorted(dp.open.where(shown));
    final paid = sorted(dp.settled.where(shown));

    // A section of debts (or a faint line when it has none), as Bank's.
    Widget section(
      String id,
      String title,
      List<DebtView> list,
      String none, {
      bool open = false,
    }) => FoldSection(
      id: id,
      title: title,
      initiallyOpen: open,
      children: list.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkText(
                  none,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: .7),
                  ),
                ),
              ),
            ]
          : [for (final v in list) _DebtTile(view: v, showSide: only == null)],
    );

    // People on the shown side, ranked by what's still open with them.
    final perPerson = <String, int>{};
    for (final v in [...dp.open, ...dp.settled].where(onSide)) {
      perPerson.update(
        v.debt.person,
        (t) => t + v.remainingMinor,
        ifAbsent: () => v.remainingMinor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
          child: Row(
            children: [
              if (only != DebtDirection.owed)
                Expanded(
                  child: _TotalTile(
                    amount: dp.totalFor(DebtDirection.owe),
                    label: l.debtIOwe,
                    background: scheme.primary,
                    foreground: context.textOnStrong,
                    onTap: () => _toggle(DebtDirection.owe),
                  ),
                ),
              if (only == null) const SizedBox(width: 8),
              if (only != DebtDirection.owe)
                Expanded(
                  child: _TotalTile(
                    amount: dp.totalFor(DebtDirection.owed),
                    label: l.debtOwedToMe,
                    background: _owedGreen,
                    foreground: Colors.white,
                    onTap: () => _toggle(DebtDirection.owed),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
          child: ListControlsRow(
            onAll: backToAll,
            byAmount: _byAmount,
            onSort: () => setState(() => _byAmount = !_byAmount),
            list: _list,
          ),
        ),
        // A row of one chip has nothing to choose between.
        if (perPerson.length >= 2)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
            child: TotalChipsRow(
              selected: _person,
              onSelect: (p) => setState(() => _person = p),
              // Owing and being owed don't add up: a total only per side.
              showTotal: only != null,
              chips: [
                for (final MapEntry(key: p, value: t) in perPerson.entries)
                  TotalChip(id: p, label: p, total: t),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Expanded(
          child: ongoing.isEmpty && paid.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Center(
                    child: InkText(
                      l.debtsEmpty,
                      maxLines: 1,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView(
                  controller: _list,
                  // Clear of the bottom bar (the page extends under it).
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    2,
                    gutter,
                    bottomInset + 16,
                  ),
                  children: [
                    section(
                      'debts.ongoing',
                      l.debtsOngoingSection,
                      ongoing,
                      l.debtsNothingOngoing,
                      open: true,
                    ),
                    const SizedBox(height: 12),
                    section(
                      'debts.paid',
                      l.debtsPaidSection,
                      paid,
                      l.debtsNothingPaid,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.amount,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
  final int amount;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkText(
                _digits(context, formatMinorWithCommas(amount)),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              InkText(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: foreground.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Like a History row: its title (or the person, when untitled) | what's
/// left on one line; the side (only while both sides are listed, like
/// History's Income chip) and person pills | the due date and the days
/// left (red once due; as Upcoming's), else the start date, or "Settled",
/// on the next; then progress and note if any.
class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.view, this.showSide = true});
  final DebtView view;

  /// Both sides are listed: which one it is.
  final bool showSide;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final calendar = context.select((SettingsProvider s) => s.calendar);
    final fa = _isFa(context);
    final d = view.debt;
    final owed = d.direction == DebtDirection.owed;
    final settled = view.isSettled;

    // The end of the second row: settled; else the due date and the days
    // left, when there's one (the owner, 2026-11-01: in the start date's
    // place); else the day it started. Inside
    // its section the tile is a step up from it, the grey pills a step up
    // from the tile.
    final grey = context.raisedBy(2);
    final greyText = scheme.onSurfaceVariant;
    // Short of room (the side, the person and the date on a narrow phone),
    // the date leaves out its weekday: the person's pill keeps its name.
    // [fill]: a row of its own, its whole width.
    final due = settled || d.dueAtUtc == null
        ? null
        : _dateOnly(d.dueAtUtc!.toLocal());
    (Widget, double) datePill(bool short, {bool fill = false}) {
      if (due != null) {
        return (
          _DueRow(due: due, short: short, fill: fill),
          _DueRow.widthOf(context, due, short),
        );
      }
      final t = settled
          ? l.debtSettled
          : short
          ? dayShort(d.startedAtUtc.toLocal(), calendar, fa)
          : dayTitle(d.startedAtUtc.toLocal(), calendar, fa);
      final pill = TilePill(text: t, background: grey, foreground: greyText);
      return (
        fill ? SizedBox(width: double.infinity, child: pill) : pill,
        TilePill.widthOf(context, t),
      );
    }

    final sideText = owed ? l.debtOwedToMe : l.debtIOwe;

    // Direction is the pill's job; amounts are all one color.
    final amountColor = scheme.onSurface;
    final note = d.note?.trim() ?? '';
    // The title leads; untitled, the person does (and has no pill then).
    final title = d.title?.trim() ?? '';
    final titled = title.isNotEmpty;

    return SwipeRow.editDelete(
      context: context,
      dismissKey: ValueKey('debt_${d.gid}'),
      radius: _kRowRadius,
      confirmDelete: () => confirmDeleteSheet(
        context,
        title: l.deleteDebtTitle,
        message: l.deleteDebtConfirm,
      ),
      onDelete: () => context.read<DebtProvider>().delete(d.gid),
      onEdit: () => _editFlow(context, view),
      child: Material(
        color: context.raised,
        borderRadius: BorderRadius.circular(_kRowRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRowRadius),
          onTap: () =>
              settled ? _doneFlow(context, view) : _payFlow(context, view),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkText(
                        titled ? title : d.person,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkText(
                      _digits(
                        context,
                        formatMinorWithCommas(
                          settled ? d.amountMinor : view.remainingMinor,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, c) {
                    final start =
                        (showSide ? TilePill.widthOf(context, sideText) : 0) +
                        (titled
                            ? (showSide ? 6 : 0) +
                                  TilePill.widthOf(context, d.person)
                            : 0);
                    final short = start + 12 + datePill(false).$2 > c.maxWidth;
                    // Not even the short date fits by the side and the
                    // person (a narrow phone, large text): it takes a row
                    // of its own, its whole width (no empty room beside
                    // it); the person's pill is never squeezed (it stood
                    // one letter a line).
                    final below = start + 12 + datePill(true).$2 > c.maxWidth;
                    final startPills = Row(
                      children: [
                        if (showSide)
                          TilePill(
                            text: sideText,
                            background: owed ? _owedGreen : scheme.primary,
                            foreground: owed
                                ? Colors.white
                                : context.textOnStrong,
                          ),
                        if (titled) ...[
                          if (showSide) const SizedBox(width: 6),
                          Flexible(
                            child: TilePill(
                              text: d.person,
                              background: grey,
                              foreground: greyText,
                            ),
                          ),
                        ],
                      ],
                    );
                    if (below) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          startPills,
                          const SizedBox(height: 8),
                          datePill(true, fill: true).$1,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: startPills),
                        const SizedBox(width: 12),
                        datePill(short).$1,
                      ],
                    );
                  },
                ),
                // Paid in part: how far, a bar in the side's color (the
                // pill's), then the words.
                if (!settled && view.paidMinor > 0) ...[
                  const SizedBox(height: 12),
                  // Flat ends, the corners rounded, the fill's too (the
                  // owner, 2026-10-27).
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: grey,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (view.paidMinor / d.amountMinor).clamp(
                        0.0,
                        1.0,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: owed ? _owedGreen : scheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // As Budget's: what's paid of the whole, and what's left
                  // with its share (the owner, 2026-10-26).
                  _PaidChips(view: view, firstTone: context.raisedBy(3)),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: grey,
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

/// A debt paid in part (the owner, 2026-10-31): what's been paid of the
/// whole (a fraction, a "/" between, left to right in both languages) and
/// how much of it that is, a chip one width for the widest share (100%), as
/// Budget's total row.
class _PaidChips extends StatelessWidget {
  const _PaidChips({required this.view, required this.firstTone});
  final DebtView view;
  final Color firstTone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final total = view.debt.amountMinor;
    final value = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
    );
    String fmt(int n) => _digits(context, formatMinorWithCommas(n));
    final paidTenths = total <= 0
        ? 0
        : (view.paidMinor * 1000 / total).round().clamp(0, 1000);
    final second = context.raisedBy(2);
    // As wide as the widest share can be: "100", or two digits and a
    // decimal (one width on every tile).
    final pctWidth =
        20 +
        [
          for (final t in const [1000, 999, 888, 777, 666, 555, 444, 333, 222])
            PercentText.widthOf(context, t, value),
        ].reduce(math.max).ceilToDouble();
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(
          child: DualValueChip(
            firstTone: firstTone,
            secondTone: second,
            data: DualChipData(
              label: l.debtPaidLabel,
              direction: TextDirection.ltr,
              slant: true,
              first: InkText(fmt(view.paidMinor), style: value),
              firstWidth: 0,
              second: InkText(fmt(total), style: value),
              secondWidth: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: DualChipRow.height,
          width: pctWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: second,
            borderRadius: BorderRadius.circular(8),
          ),
          child: PercentText(paidTenths, style: value),
        ),
      ],
    );
  }
}

/// A debt's due date, as Upcoming's (the owner, 2026-11-01): "By" the
/// date in a pill, then the days left as a number alone in a chip one width
/// for three digits (more: ∞), red once late; a touch says left or late.
/// Today: one red chip. In the tile's second row, where the start date
/// would be ([short]: the date without its weekday; [fill]: a row of its
/// own, the whole width).
class _DueRow extends StatelessWidget {
  const _DueRow({required this.due, this.short = false, this.fill = false});
  final DateTime due;
  final bool short, fill;

  static String _text(BuildContext context, DateTime due, bool short) {
    // Read, not heard: the tile hears the calendar (this is measured
    // during its layout too).
    final calendar = context.read<SettingsProvider>().calendar;
    final fa = _isFa(context);
    return AppLocalizations.of(context)!.debtDueBy(
      short ? dayShort(due, calendar, fa) : dayTitle(due, calendar, fa),
    );
  }

  /// How wide it stands.
  static double widthOf(BuildContext context, DateTime due, bool short) {
    final days = due.difference(_today()).inDays;
    final l = AppLocalizations.of(context)!;
    return TilePill.widthOf(context, _text(context, due, short)) +
        8 +
        (days == 0
            ? TilePill.widthOf(context, l.dueToday)
            : TilePill.widthOf(context, _digits(context, '000')));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final days = due.difference(_today()).inDays;
    final late = days < 0;
    final Widget left = days == 0
        ? TilePill(
            text: l.dueToday,
            background: kStrongRed,
            foreground: Colors.white,
          )
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
    final pill = TilePill(
      text: _text(context, due, short),
      background: context.raisedBy(2),
      foreground: scheme.onSurfaceVariant,
    );
    return Row(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        fill ? Expanded(child: pill) : Flexible(child: pill),
        const SizedBox(width: 8),
        left,
      ],
    );
  }
}

// ============================================================================
// Flows
// ============================================================================

/// Opens the editor for a new debt (the bottom bar's "+" on the Debts
/// tab), on the side the list shows.
Future<void> addDebt(BuildContext context) =>
    _addFlow(context, _DebtsViewState._shown ?? DebtDirection.owe);

Future<void> _addFlow(BuildContext context, DebtDirection direction) async {
  final dp = context.read<DebtProvider>();
  final d = await _showSheet<_DebtDraft>(
    context,
    _DebtEditor(initialDirection: direction),
  );
  if (d == null) return;
  await dp.add(
    direction: d.direction,
    person: d.person,
    title: d.title,
    amountMinor: d.amountMinor,
    startedLocal: d.startedLocal,
    dueLocal: d.dueLocal,
    note: d.note,
  );
}

Future<void> _editFlow(BuildContext context, DebtView view) async {
  final dp = context.read<DebtProvider>();
  final d = await _showSheet<_DebtDraft>(
    context,
    _DebtEditor(
      initialDirection: view.debt.direction,
      existingGid: view.debt.gid,
    ),
  );
  if (d == null) return;
  await dp.update(
    view.debt.gid,
    direction: d.direction,
    person: d.person,
    title: d.title,
    amountMinor: d.amountMinor,
    startedLocal: d.startedLocal,
    dueLocal: d.dueLocal,
    note: d.note,
  );
}

Future<void> _payFlow(BuildContext context, DebtView view) async {
  final l = AppLocalizations.of(context)!;
  final dp = context.read<DebtProvider>();
  final ep = context.read<ExpenseProvider>();
  final ip = context.read<IncomeProvider>();
  final res = await _showSheet<_PayDraft>(context, _PaySheet(view: view));
  if (res == null || !context.mounted) return;
  // Its Edit chip: the editor instead.
  if (res.action == _PayAction.edit) return _editFlow(context, view);
  if (res.action == _PayAction.delete) return _deleteFlow(context, view);
  final owe = view.debt.direction == DebtDirection.owe;
  await dp.pay(
    view,
    amountMinor: res.amountMinor,
    paidLocal: res.paidLocal,
    ledgerTitle: res.action == _PayAction.payAndRecord
        ? _ledgerTitle(l, view)
        : null,
    ledgerCategoryGid: owe ? ep.fallbackCategoryGid : ip.fallbackCategoryGid,
    expenses: ep,
    incomes: ip,
  );
}

/// The pay and done sheets' Delete: asked, as a swipe's.
Future<void> _deleteFlow(BuildContext context, DebtView view) async {
  final l = AppLocalizations.of(context)!;
  final dp = context.read<DebtProvider>();
  final ok = await confirmDeleteSheet(
    context,
    title: l.deleteDebtTitle,
    message: l.deleteDebtConfirm,
  );
  if (ok) await dp.delete(view.debt.gid);
}

String _ledgerTitle(AppLocalizations l, DebtView view) =>
    view.debt.direction == DebtDirection.owe
    ? l.debtLedgerTitleOwe(view.debt.person)
    : l.debtLedgerTitleOwed(view.debt.person);

/// A settled debt: the done sheet, filled with its last payment. Undo
/// takes the payment back (and the History entry it added); Save keeps the
/// fields and puts it in History (or changes the entry already there).
Future<void> _doneFlow(BuildContext context, DebtView view) async {
  final l = AppLocalizations.of(context)!;
  final dp = context.read<DebtProvider>();
  final ep = context.read<ExpenseProvider>();
  final ip = context.read<IncomeProvider>();
  final last = view.payments.lastOrNull;
  // Nothing to take back (a debt of nothing): its editor.
  if (last == null) return _editFlow(context, view);
  final title = _ledgerTitle(l, view);
  final inHistory = await dp.ledgerEntryOf(view, last, title: title) != null;
  if (!context.mounted) return;
  final res = await showDoneSheet(
    context,
    title: view.debt.person,
    headerAmount: view.debt.amountMinor,
    amountMinor: last.amountMinor,
    date: last.paidAtUtc.toLocal(),
    inHistory: inHistory,
    extra: _RepaymentsLog(debtGid: view.debt.gid, closeOnDelete: true),
  );
  if (res == null || !context.mounted) return;
  if (res.action == DoneAction.delete) return _deleteFlow(context, view);
  if (res.action == DoneAction.undo) {
    await dp.undoPayment(
      view,
      last,
      ledgerTitle: title,
      expenses: ep,
      incomes: ip,
    );
    return;
  }
  final owe = view.debt.direction == DebtDirection.owe;
  await dp.recordPayment(
    view,
    last,
    amountMinor: res.amountMinor,
    paidLocal: res.date,
    ledgerTitle: title,
    ledgerCategoryGid: owe ? ep.fallbackCategoryGid : ip.fallbackCategoryGid,
    expenses: ep,
    incomes: ip,
  );
}

/// Sheets with text fields are built once and only lifted by
/// [KeyboardInset] while the keyboard moves (see the add sheet).
Future<T?> _showSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => KeyboardInset(child: sheet),
  );
}

// ============================================================================
// Shared sheet pieces
// ============================================================================

ButtonStyle _fieldButtonStyle(ColorScheme scheme) => OutlinedButton.styleFrom(
  overlayColor: Colors.transparent,
  fixedSize: const Size.fromHeight(_kButtonHeight),
  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
  backgroundColor: scheme.surfaceContainerHigh,
  foregroundColor: scheme.onSurface,
  side: BorderSide.none,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

ButtonStyle _actionStyle(ColorScheme scheme) => OutlinedButton.styleFrom(
  overlayColor: Colors.transparent,
  minimumSize: const Size.fromHeight(_kButtonHeight),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  side: BorderSide.none,
  backgroundColor: scheme.surfaceContainerHigh,
  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
);

/// The sheet's surface: rounded top, app background.
Widget _sheetFrame(BuildContext context, Widget child) {
  return Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: child,
      ),
    ),
  );
}

/// Calendar icon + text, centered (e.g. a date picker button).
// ============================================================================
// Add / edit sheet
// ============================================================================

class _DebtDraft {
  final DebtDirection direction;
  final String person;
  final String? title;
  final int amountMinor;
  final DateTime startedLocal;
  final DateTime? dueLocal;
  final String? note;
  const _DebtDraft({
    required this.direction,
    required this.person,
    this.title,
    required this.amountMinor,
    required this.startedLocal,
    this.dueLocal,
    this.note,
  });
}

/// Same layout as the add sheet: no title or labels, sections with
/// centered faint placeholders. Editing also lists the payments (each
/// removable).
class _DebtEditor extends StatefulWidget {
  const _DebtEditor({required this.initialDirection, this.existingGid});
  final DebtDirection initialDirection;
  final String? existingGid;

  @override
  State<_DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<_DebtEditor> {
  final _title = TextEditingController();
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _titleNode = FocusNode();
  final _personNode = FocusNode();
  final _amountNode = FocusNode();
  // What the user typed (picking a chip resets it).
  final _titleQuery = ValueNotifier<String>('');
  late final _noteFold = NoteFold(_note);
  final _personQuery = ValueNotifier<String>('');

  late DebtDirection _direction = widget.initialDirection;
  DateTime _started = _today();
  DateTime? _due;
  bool _personError = false;
  bool _amountError = false;

  bool get _editing => widget.existingGid != null;

  // A new one keeps what a cancelled one left ("keep entries").
  late final SettingsProvider _settings;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    final v = _editing
        ? context.read<DebtProvider>().viewOf(widget.existingGid!)
        : null;
    if (v != null) {
      final d = v.debt;
      _title.text = d.title ?? '';
      _person.text = d.person;
      _amount.text = formatMinorWithCommas(d.amountMinor);
      _note.text = d.note ?? '';
      _started = _dateOnly(d.startedAtUtc.toLocal());
      _due = d.dueAtUtc == null ? null : _dateOnly(d.dueAtUtc!.toLocal());
    } else {
      // Keyboard after the sheet has slid up, not during.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusAfterRouteOpens(context, _titleNode);
      });
    }
    _startTitle = _title.text;
    _startPerson = _person.text;
    _startAmount = _amount.text;
    _startNote = _note.text;
    _startStarted = _started;
    _startDue = _due;
    _startDirection = _direction;
    final draft = _editing ? null : SheetDrafts.of(_settings, 'debt');
    if (draft != null) {
      _direction = DebtDirection.values[draft['direction'] as int];
      _title.text = draft['title'] as String;
      _person.text = draft['person'] as String;
      _amount.text = draft['amount'] as String;
      _note.text = draft['note'] as String;
      _started = draft['started'] as DateTime;
      _due = draft['due'] as DateTime?;
    }
  }

  @override
  void dispose() {
    if (!_editing) {
      _saved
          ? SheetDrafts.saved('debt')
          : SheetDrafts.closed(
              _settings,
              'debt',
              changed: _anyChange,
              values: {
                'direction': _direction.index,
                'title': _title.text,
                'person': _person.text,
                'amount': _amount.text,
                'note': _note.text,
                'started': _started,
                'due': _due,
              },
            );
    }
    _title.dispose();
    _person.dispose();
    _amount.dispose();
    _noteFold.dispose();
    _note.dispose();
    _titleNode.dispose();
    _personNode.dispose();
    _amountNode.dispose();
    _titleQuery.dispose();
    _personQuery.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(
    DateTime initial, {
    bool pastOnly = false,
    bool futureOnly = false,
  }) => pickSheetDate(
    context,
    initial,
    pastOnly: pastOnly,
    futureOnly: futureOnly,
  );

  // How the form started (Save waits for a change when editing).
  late String _startTitle, _startPerson, _startAmount, _startNote;
  late DateTime _startStarted;
  late DateTime? _startDue;
  late DebtDirection _startDirection;

  bool get _anyChange =>
      _title.text != _startTitle ||
      _person.text != _startPerson ||
      _amount.text != _startAmount ||
      _note.text != _startNote ||
      _started != _startStarted ||
      _due != _startDue ||
      _direction != _startDirection;

  /// Save is grey until it can save: a person and an amount, and (editing)
  /// something changed.
  bool get _ready {
    final amount = parseAmountMinor(_amount.text);
    return _person.text.trim().isNotEmpty &&
        amount != null &&
        amount > 0 &&
        (!_editing || _anyChange);
  }

  /// The repayments made so far (editing).
  List<DebtPaymentDto> get _payments => _editing
      ? (context.read<DebtProvider>().viewOf(widget.existingGid!)?.payments ??
            const [])
      : const [];

  void _save() {
    final l = AppLocalizations.of(context)!;
    final person = _person.text.trim();
    final amount = parseAmountMinor(_amount.text);
    final personOk = person.isNotEmpty;
    final amountOk = amount != null && amount > 0;
    if (!personOk || !amountOk) {
      setState(() {
        _personError = !personOk;
        _amountError = !amountOk;
      });
      Haptics.alert(context);
      (!personOk ? _personNode : _amountNode).requestFocus();
      return;
    }
    // What's been repaid stays true: the debt can't be less than it, nor
    // start after a repayment (the owner, 2026-10-25: edited from the pay
    // sheet).
    final payments = _payments;
    final paid = payments.fold<int>(0, (s, p) => s + p.amountMinor);
    if (amount < paid) {
      setState(() => _amountError = true);
      showAppNotice(
        context,
        l.debtBelowPaid(_digits(context, formatMinorWithCommas(paid))),
        kind: NoticeKind.failure,
      );
      return;
    }
    for (final p in payments) {
      final day = _dateOnly(p.paidAtUtc.toLocal());
      if (day.isBefore(_started)) {
        showAppNotice(
          context,
          l.debtStartAfterRepayment(
            formatDateForCalendar(
              day,
              context.read<SettingsProvider>().calendar,
              fa: _isFa(context),
            ),
          ),
          kind: NoticeKind.failure,
        );
        return;
      }
    }
    final note = _note.text.trim();
    _saved = true;
    Navigator.of(context).pop(
      _DebtDraft(
        direction: _direction,
        person: person,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        amountMinor: amount,
        startedLocal: _started,
        dueLocal: _due,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context)!;
    final dp = context.read<DebtProvider>();
    final ok = await confirmDeleteSheet(
      context,
      title: l.deleteDebtTitle,
      message: l.deleteDebtConfirm,
    );
    if (!ok || !mounted) return;
    await dp.delete(widget.existingGid!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final calendar = context.select((SettingsProvider s) => s.calendar);
    final dp = context.watch<DebtProvider>();
    final fa = _isFa(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final payments = _editing
        ? (dp.viewOf(widget.existingGid!)?.payments ?? const [])
        : const <DebtPaymentDto>[];
    String date(DateTime d) => formatDateForCalendar(d, calendar, fa: fa);
    final settings = context.watch<SettingsProvider>();
    // This side's suggestions, minus what the user ignored.
    final titles = [
      for (final t in dp.titles(_direction))
        if (!settings.isTitleIgnored(_direction.titleSource, t)) t,
    ];
    final people = [
      for (final p in dp.people(_direction))
        if (!settings.isTitleIgnored(_direction.personSource, p)) p,
    ];
    // Suggestion rows only with suggestions on and something to offer;
    // without one, the field is just a row of the form.
    final on = settings.suggestionsOn;
    final showTitles = on && titles.isNotEmpty;
    final showPeople = on && people.isNotEmpty;
    List<String> matching(List<String> items, String q) {
      final query = EntrySuggestions.normalize(q);
      return [
        for (final t in items)
          if (query.isEmpty || EntrySuggestions.normalize(t).contains(query)) t,
      ];
    }

    void setText(TextEditingController c, String t) =>
        c.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );

    return _sheetFrame(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedPills<DebtDirection>(
            selected: _direction,
            // Repaid already: its repayments' History entries are on
            // this side (expenses or income), so it stays.
            onChanged: (d) {
              if (d == _direction) return;
              if (payments.isNotEmpty) {
                showAppNotice(context, l.debtSideLocked);
                return;
              }
              setState(() => _direction = d);
            },
            options: {
              DebtDirection.owe: l.debtIOwe,
              DebtDirection.owed: l.debtOwedToMe,
            },
          ),
          const SizedBox(height: _kRowGap),

          // ---- Title, person and amount, each with what this side used
          // before (borrowing and lending rarely share people or purposes);
          // the note's chip by the amount, its field under them
          InkField(
            controller: _title,
            hint: l.titleLabel,
            builder: (shown) => TextField(
              controller: _title,
              focusNode: _titleNode,
              textInputAction: TextInputAction.next,
              textAlign: rtl ? TextAlign.right : TextAlign.left,
              onChanged: (t) => _titleQuery.value = t,
              onSubmitted: (_) => _personNode.requestFocus(),
              decoration: entryFieldDecoration(
                context,
                shown: shown,
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
                      final shown = matching(titles, q);
                      return SuggestionChipsRow(
                        key: ValueKey('t$q$_direction'),
                        labels: shown,
                        emptyText: l.noMatch,
                        onTap: (i) {
                          setText(_title, shown[i]);
                          _titleQuery.value = '';
                          _personNode.requestFocus();
                        },
                        onLongPress: (i) => ignoreTitleSuggestion(
                          context,
                          _direction.titleSource,
                          shown[i],
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox(height: kSheetRowGap),
          InkField(
            controller: _person,
            hint: l.debtPersonHint,
            builder: (shown) => TextField(
              controller: _person,
              focusNode: _personNode,
              textInputAction: TextInputAction.next,
              textAlign: rtl ? TextAlign.right : TextAlign.left,
              onChanged: (t) {
                _personQuery.value = t;
                if (_personError) setState(() => _personError = false);
              },
              onSubmitted: (_) => _amountNode.requestFocus(),
              decoration: entryFieldDecoration(
                context,
                shown: shown,
                error: _personError,
                suffixIcon: ClearWhenFilled(
                  controller: _person,
                  onClear: () {
                    _person.clear();
                    _personQuery.value = '';
                    _personNode.requestFocus();
                  },
                ),
              ),
            ),
          ),
          showPeople
              ? SuggestionsSlot(
                  controller: _person,
                  focusNode: _personNode,
                  row: ValueListenableBuilder<String>(
                    valueListenable: _personQuery,
                    builder: (_, q, _) {
                      final shown = matching(people, q);
                      return SuggestionChipsRow(
                        key: ValueKey('p$q$_direction'),
                        labels: shown,
                        emptyText: l.noMatch,
                        onTap: (i) {
                          setText(_person, shown[i]);
                          _personQuery.value = '';
                          if (_personError) {
                            setState(() => _personError = false);
                          }
                          _amountNode.requestFocus();
                        },
                        onLongPress: (i) => ignoreTitleSuggestion(
                          context,
                          _direction.personSource,
                          shown[i],
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox(height: kSheetRowGap),

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
          const SizedBox(height: _kRowGap),
          NoteSection(fold: _noteFold),

          // ---- Started and due, one row (the owner, 2026-11-04: the sheet
          // ran too tall). Each with a calendar, or what undoes its date:
          // never empty, the reset back to today; can be empty, the eraser.
          Row(
            children: [
              Expanded(
                child: SheetDateField(
                  style: _fieldButtonStyle(scheme),
                  label: date(_started),
                  reset: DateUtils.isSameDay(_started, _today())
                      ? null
                      : () => setState(() => _started = _today()),
                  onTap: () async {
                    final res = await _pick(_started, pastOnly: true);
                    if (res != null && mounted) setState(() => _started = res);
                  },
                ),
              ),
              const SizedBox(width: _kRowGap),
              Expanded(
                child: SheetDateField(
                  style: _fieldButtonStyle(scheme),
                  label: _due == null ? l.dueDateLabel : l.dueOn(date(_due!)),
                  clear: _due == null
                      ? null
                      : () => setState(() => _due = null),
                  onTap: () async {
                    final res = await _pick(_due ?? _today(), futureOnly: true);
                    if (res != null && mounted) setState(() => _due = res);
                  },
                ),
              ),
            ],
          ),
          // ---- The repayments (the pay sheet's log, the same)
          const SizedBox(height: _kRowGap),
          if (payments.isNotEmpty) ...[
            _RepaymentsLog(debtGid: widget.existingGid!),
            const SizedBox(height: _kRowGap),
          ],

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
                    listenable: Listenable.merge([
                      _title,
                      _person,
                      _amount,
                      _note,
                    ]),
                    builder: (context, _) => OutlinedButton(
                      style: saveButtonStyle(
                        context,
                        _actionStyle(scheme),
                        _ready,
                      ),
                      onPressed: _editing && !_anyChange ? null : _save,
                      child: InkText(_editing ? l.saveChanges : l.save),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_editing) ...[
            const SizedBox(height: _kRowGap),
            OutlinedButton.icon(
              icon: const ImageIcon(AppIcons.trash, size: 18),
              style: _actionStyle(scheme).copyWith(
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                backgroundColor: const WidgetStatePropertyAll(kStrongRed),
              ),
              onPressed: _delete,
              label: InkText(l.delete),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Pay sheet
// ============================================================================

/// What the pay sheet was left with: pay, pay and add to History, or
/// edit the debt (its Edit chip).
enum _PayAction { pay, payAndRecord, edit, delete }

class _PayDraft {
  final int amountMinor;
  final DateTime paidLocal;
  final _PayAction action;
  const _PayDraft(this.amountMinor, this.paidLocal, this.action);
  _PayDraft.edit() : this(0, DateTime(0), _PayAction.edit);
  _PayDraft.delete() : this(0, DateTime(0), _PayAction.delete);
}

/// Records a part paid back: the repayment (empty to start; any part, the
/// calculator too; Remaining fills what's left) and its date. Two buttons:
/// just record it, or also add it to History as an expense / income; and
/// Delete (the debt, asked first). Its header starts with the red close
/// square, and its Edit chip opens the debt's editor; the repayments so
/// far are in a fold over the buttons (closed). A settled debt opens the
/// done sheet instead (done_sheet.dart).
class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.view});
  final DebtView view;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  // Empty: a number in it read as the total or as what's paid (the owner,
  // 2026-10-25); the chip under it fills what's left.
  final _amount = TextEditingController();
  final _amountNode = FocusNode();
  DateTime _date = _today();
  bool _amountError = false;

  @override
  void dispose() {
    _amount.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  void _save(_PayAction action) {
    final amount = parseAmountMinor(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = true);
      Haptics.alert(context);
      _amountNode.requestFocus();
      return;
    }
    Navigator.of(context).pop(_PayDraft(amount, _date, action));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final calendar = context.select((SettingsProvider s) => s.calendar);
    // Live: a repayment deleted from the log here changes what's left.
    final view =
        context.watch<DebtProvider>().viewOf(widget.view.debt.gid) ??
        widget.view;
    final owe = view.debt.direction == DebtDirection.owe;
    // The split rows' words take one width: their values line up.
    final labelWidth = SheetSplitRow.widthFor(context, [
      l.debtStartLabel,
      l.dueDateLabel,
      l.payRemainingLabel,
      l.dateLabel,
    ]);
    final fa = _isFa(context);
    final due = view.debt.dueAtUtc?.toLocal();
    // The debt's own dates: read only.
    Widget dateRow(String label, DateTime date) => SheetSplitRow(
      label: label,
      labelWidth: labelWidth,
      child: InkText(
        dayTitle(date, calendar, fa),
        style: const TextStyle(height: 1.2),
      ),
    );
    // [save]: a paying button, grey until there's an amount.
    Widget button(
      String text,
      VoidCallback onPressed, {
      ButtonStyle? style,
      bool save = false,
      Widget? icon,
    }) => Expanded(
      child: ListenableBuilder(
        listenable: _amount,
        builder: (context, _) {
          final hasAmount = (parseAmountMinor(_amount.text) ?? 0) > 0;
          return OutlinedButton(
            style:
                (save
                        ? saveButtonStyle(
                            context,
                            _actionStyle(scheme),
                            hasAmount,
                          )
                        : style ?? _actionStyle(scheme))
                    .copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      ),
                    ),
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon, const SizedBox(width: 8)],
                Flexible(child: GroupFit(child: InkText(text))),
              ],
            ),
          );
        },
      ),
    );

    return _sheetFrame(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Who (and Edit), and the debt's total.
          SheetAmountHeader(
            title: view.debt.person,
            amount: _digits(
              context,
              formatMinorWithCommas(view.debt.amountMinor),
            ),
            onEdit: () => Navigator.of(context).pop(_PayDraft.edit()),
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: kSheetTitleGap),
          // When it started and when it's due (the owner, 2026-11-01: the
          // repayment's date below read as one of these).
          dateRow(l.debtStartLabel, view.debt.startedAtUtc.toLocal()),
          if (due != null) ...[
            const SizedBox(height: _kRowGap),
            dateRow(l.dueDateLabel, due),
          ],
          const SizedBox(height: _kRowGap),
          // A repayment: its own section, closed at first (as the log).
          _SheetFold(
            title: l.repaymentLabel,
            onClose: () => FocusScope.of(context).unfocus(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AmountFieldRow(
                  controller: _amount,
                  focusNode: _amountNode,
                  error: _amountError,
                  hint: l.payHint,
                  onChanged: (_) {
                    if (_amountError) setState(() => _amountError = false);
                  },
                  onCalculated: () {
                    if (_amountError) setState(() => _amountError = false);
                  },
                ),
                // What's left, to pay it all: a tap fills the field. Its
                // word at the start, the number (as big as the total's) in
                // the rest.
                const SizedBox(height: _kRowGap),
                SheetSplitRow(
                  label: l.payRemainingLabel,
                  labelWidth: labelWidth,
                  onTap: () {
                    _amount.text = formatMinorWithCommas(view.remainingMinor);
                    if (_amountError) setState(() => _amountError = false);
                  },
                  child: InkText(
                    _digits(
                      context,
                      formatMinorWithCommas(view.remainingMinor),
                    ),
                    style: const TextStyle(
                      fontSize: kSheetTitleSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // When it was paid back.
                const SizedBox(height: _kRowGap),
                SheetSplitRow(
                  label: l.dateLabel,
                  labelWidth: labelWidth,
                  onTap: () async {
                    final res = await pickSheetDate(
                      context,
                      _date,
                      pastOnly: true,
                    );
                    if (res != null && mounted) setState(() => _date = res);
                  },
                  child: DateFieldLabel(
                    label: formatDateForCalendar(_date, calendar, fa: fa),
                    reset: DateUtils.isSameDay(_date, DateTime.now())
                        ? null
                        : () => setState(
                            () => _date = DateUtils.dateOnly(DateTime.now()),
                          ),
                  ),
                ),
                const SizedBox(height: _kRowGap),
                // Pay (receive), pay & add to History: their words one size.
                FitGroup(
                  child: Row(
                    children: [
                      button(
                        owe ? l.payOnly : l.receiveOnly,
                        () => _save(_PayAction.pay),
                        save: true,
                      ),
                      const SizedBox(width: 8),
                      button(
                        owe ? l.payAndRecord : l.receiveAndRecord,
                        () => _save(_PayAction.payAndRecord),
                        save: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _kRowGap),
          // The repayments so far (closed).
          if (view.payments.isNotEmpty) ...[
            _RepaymentsLog(debtGid: view.debt.gid),
            const SizedBox(height: _kRowGap),
          ],
          Row(
            children: [
              button(
                l.delete,
                () => Navigator.of(context).pop(_PayDraft.delete()),
                style: cancelButtonStyle(_actionStyle(scheme)),
                icon: const ImageIcon(AppIcons.trash, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A part of a sheet under a title band (as the repayments log's: the
/// band's tone and words, no chevron, as tall as the sheet's rows) that
/// folds and unfolds on a tap of it; closed at first (the owner,
/// 2026-11-01). Its rows sit on a box
/// a little above the sheet, so theirs stand out from it. [onClose]: as it
/// folds (a field in it lets go of the keyboard).
class _SheetFold extends StatefulWidget {
  const _SheetFold({required this.title, required this.child, this.onClose});
  final String title;
  final Widget child;
  final VoidCallback? onClose;

  @override
  State<_SheetFold> createState() => _SheetFoldState();
}

class _SheetFoldState extends State<_SheetFold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: surfaceTone(scheme, .5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_open) widget.onClose?.call();
                setState(() => _open = !_open);
              },
              child: Container(
                height: _kButtonHeight,
                color: context.raisedBy(2),
                alignment: Alignment.center,
                child: InkText(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: widget.child,
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Repayments log
// ============================================================================

/// A debt's repayments, oldest first, in a row as tall as the sheet's
/// others that opens (closed to start); each with its date, amount and a
/// delete mark: asked first, then a notice with Undo (the repayment and the
/// History entry it added come back). The pay, done and edit sheets show
/// it alike; live, from the provider. [closeOnDelete]: the done sheet's
/// (a settled debt isn't one after a deletion).
class _RepaymentsLog extends StatefulWidget {
  const _RepaymentsLog({required this.debtGid, this.closeOnDelete = false});
  final String debtGid;
  final bool closeOnDelete;

  @override
  State<_RepaymentsLog> createState() => _RepaymentsLogState();
}

class _RepaymentsLogState extends State<_RepaymentsLog> {
  bool _open = false;

  Future<void> _delete(DebtView view, DebtPaymentDto p) async {
    final l = AppLocalizations.of(context)!;
    final dp = context.read<DebtProvider>();
    final ep = context.read<ExpenseProvider>();
    final ip = context.read<IncomeProvider>();
    final notice = AppNotice.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirmDeleteSheet(
      context,
      title: l.deleteRepaymentTitle,
      message: l.deleteRepaymentConfirm,
    );
    if (!ok || !mounted) return;
    final entry = await dp.deletePayment(
      view,
      p,
      ledgerTitle: _ledgerTitle(l, view),
      expenses: ep,
      incomes: ip,
    );
    notice.show(
      l.repaymentDeleted,
      kind: NoticeKind.success,
      actionLabel: l.undo,
      onAction: () =>
          dp.restorePayment(view, p.gid, entry, expenses: ep, incomes: ip),
    );
    if (widget.closeOnDelete) navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final calendar = context.select((SettingsProvider s) => s.calendar);
    final view = context.watch<DebtProvider>().viewOf(widget.debtGid);
    if (view == null || view.payments.isEmpty) return const SizedBox.shrink();
    final payments = [...view.payments]
      ..sort((a, b) => a.paidAtUtc.compareTo(b.paidAtUtc));
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Its title like a section's (the band's tone and words, no
          // chevron; the owner, 2026-10-26), as tall as the sheet's rows.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Container(
              height: _kButtonHeight,
              color: context.raisedBy(2),
              alignment: Alignment.center,
              child: InkText(
                l.repayments,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // Unfolding, it stays in view frame by frame: its title, then as
          // much of the list as fits (the owner, 2026-10-31).
          NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              if (_open) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => keepInView(context),
                );
              }
              return true;
            },
            child: SizeChangedLayoutNotifier(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, p) in payments.indexed) ...[
                              if (i > 0) const SizedBox(height: 6),
                              Container(
                                height: 44,
                                padding: const EdgeInsetsDirectional.only(
                                  start: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkText(
                                        formatDateForCalendar(
                                          p.paidAtUtc.toLocal(),
                                          calendar,
                                          fa: _isFa(context),
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    InkText(
                                      _digits(
                                        context,
                                        formatMinorWithCommas(p.amountMinor),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Semantics(
                                      button: true,
                                      label: l.delete,
                                      child: IconButton(
                                        style: IconButton.styleFrom(
                                          overlayColor: Colors.transparent,
                                        ),
                                        onPressed: () => _delete(view, p),
                                        icon: const ImageIcon(
                                          AppIcons.trash,
                                          size: 18,
                                          color: kStrongRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

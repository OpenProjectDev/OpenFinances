// lib/shared/ui/list_controls.dart
// The rows under a list page's totals (History, Upcoming, Debts): back to
// both sides when filtered to one, the sort chip and today's date; then a
// row of chips (categories or people) ranked by their total.

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/split_chip.dart';

/// "All" (only with [onAll]: the list is filtered to one side), the sort
/// chip (date / amount) and today's date filling the rest.
class ListControlsRow extends StatelessWidget {
  const ListControlsRow({
    super.key,
    this.onAll,
    required this.byAmount,
    required this.onSort,
    this.list,
    this.onToday,
    this.todayAway = false,
    this.onCalendar,
    this.calendarOpen = false,
  });

  /// History only (the owner, 2026-10-31): a square at the today chip's
  /// end (the row's end), joined to it, that opens the period's calendar;
  /// open, it's the red close square in its place.
  final VoidCallback? onCalendar;
  final bool calendarOpen;

  final VoidCallback? onAll;
  final bool byAmount;
  final VoidCallback onSort;

  /// Set while the page shows a period without today in it: tapped, the
  /// today chip calls this (back to today's period) as well as scrolling
  /// to the top.
  final VoidCallback? onToday;

  /// Today isn't in view (another period, or scrolled past it): the today
  /// chip wears the theme color, saying a tap brings it back.
  final bool todayAway;

  /// The list under it: tapping today's date scrolls it back to the top.
  final ScrollController? list;

  void _toTop() {
    final c = list;
    if (c == null || !c.hasClients || c.offset <= 0) return;
    c.animateTo(
      0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// The today chip; with [onCalendar], the calendar's square joined to its
  /// end (one chip in two parts).
  Widget _today(
    BuildContext context,
    Widget Function({
      required String id,
      required Widget child,
      Color? color,
      double? width,
      VoidCallback? onTap,
    })
    box,
    Color textMain,
  ) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final calendar = context.select((SettingsProvider s) => s.calendar);
    final fa = isFaUi(context);
    void onTap() {
      onToday?.call();
      _toTop();
    }

    final words = InkText(
      l.todayWithDate(dayTitle(DateTime.now(), calendar, fa)),
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: todayAway ? context.textOnStrong : textMain,
      ),
    );
    final cal = onCalendar;
    if (cal == null) {
      return box(
        id: 'today',
        onTap: onTap,
        color: todayAway ? scheme.primary : null,
        child: words,
      );
    }
    const anim = Duration(milliseconds: 260);
    return SplitChip(
      key: const ValueKey('todayChip'),
      height: 40,
      parts: [
        // The today part itself: keyed as the plain chip is.
        Expanded(
          child: GestureDetector(
            key: const ValueKey('today'),
            onTap: onTap,
            child: AnimatedContainer(
              duration: anim,
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: todayAway ? scheme.primary : scheme.surfaceContainerHigh,
              ),
              child: words,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: calendarOpen ? l.close : l.calendarJump,
          child: GestureDetector(
            onTap: cal,
            child: AnimatedContainer(
              duration: anim,
              curve: Curves.easeOut,
              width: 40,
              alignment: Alignment.center,
              color: calendarOpen ? kStrongRed : scheme.surfaceContainerHigh,
              // The calendar's drawing is heavier on its right (its ink's
              // middle 5% right of the box's): moved back to look centered.
              child: Transform.translate(
                offset: Offset(calendarOpen ? 0 : -1.5, 0),
                child: ImageIcon(
                  calendarOpen ? AppIcons.close : AppIcons.calendar,
                  size: calendarOpen ? 14 : 17,
                  color: calendarOpen ? Colors.white : textMain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fa = isFaUi(context);
    final textMain = scheme.onSurface;

    // Keyed: "All" comes and goes before the others, and an unkeyed box
    // would take over its neighbour's animation (its fixed width to none:
    // the row failed every frame and the app hung).
    Widget box({
      required String id,
      required Widget child,
      Color? color,
      double? width,
      VoidCallback? onTap,
    }) => GestureDetector(
      key: ValueKey(id),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        height: 40,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color ?? scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );

    return Directionality(
      textDirection: uiTextDirection(fa),
      child: Row(
        children: [
          // Back to the default (both sides) view
          if (onAll != null) ...[
            box(
              id: 'all',
              onTap: onAll,
              color: scheme.primary.withValues(alpha: .18),
              child: InkText(
                l.allShort,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: context.primaryInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          box(
            id: 'sort',
            onTap: onSort,
            width: 100,
            // The mark stays put at the start (12 px: the size the old one
            // drew at, this glyph fills its box); the word is centered in
            // the rest, so "date" ⇄ "amount" doesn't move it.
            child: Row(
              children: [
                Transform.flip(
                  flipX: fa,
                  child: Icon(UIcons.sort, size: 12, color: textMain),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: InkText(
                      byAmount ? l.amountLabel : l.dateLabel,
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: textMain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Today: scrolls the list up; away from today's period, it wears
          // the theme color and brings that period back too.
          Expanded(child: _today(context, box, textMain)),
        ],
      ),
    );
  }
}

/// One chip of a [TotalChipsRow].
class TotalChip {
  const TotalChip({
    required this.id,
    required this.label,
    required this.total,
    this.color,
    this.showTotal = true,
  });
  final String id;
  final String label;
  final int total;

  /// Whether it shows [total] when chosen (e.g. not for a count-less group).
  final bool showTotal;

  /// Background (a category's color); null: a neutral tone.
  final Color? color;
}

/// Chips ranked by total, largest first; tapping one filters the list to
/// it (the others fade back and the chosen one shows its total), tapping it
/// again clears the filter. The chosen chip is always scrolled whole into
/// view (with its total; also when chosen from elsewhere, e.g. a Budget
/// category).
class TotalChipsRow extends StatefulWidget {
  const TotalChipsRow({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelect,
    this.showTotal = true,
    this.trailing = const [],
    this.firstChipKey,
  });

  /// On the first chip (a tip about them points at it).
  final GlobalKey? firstChipKey;

  final List<TotalChip> chips;

  /// After the ranked chips, in this order (e.g. "unknown", "ignored").
  final List<TotalChip> trailing;
  final String? selected;
  final ValueChanged<String?> onSelect;

  /// Whether the chosen chip shows its total.
  final bool showTotal;

  @override
  State<TotalChipsRow> createState() => _TotalChipsRowState();
}

class _TotalChipsRowState extends State<TotalChipsRow> {
  /// The chosen chip (it's the only one keyed).
  final _chosen = GlobalKey();

  static Color _onColor(Color bg) => onColor(bg);

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) _reveal();
  }

  @override
  void didUpdateWidget(covariant TotalChipsRow old) {
    super.didUpdateWidget(old);
    if (widget.selected != null && widget.selected != old.selected) _reveal();
  }

  /// After this frame (the chip has its new width, total and all): scroll
  /// the row just enough to show the whole chip, end first, then start.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chip = _chosen.currentContext;
      if (chip == null || !chip.mounted) return;
      const d = Duration(milliseconds: 280);
      await Scrollable.ensureVisible(
        chip,
        duration: d,
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      if (!chip.mounted) return;
      await Scrollable.ensureVisible(
        chip,
        duration: d,
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fa = isFaUi(context);
    final selected = widget.selected;
    final showTotal = widget.showTotal;
    final onSelect = widget.onSelect;
    final ranked = [
      ...([...widget.chips]..sort((a, b) => b.total.compareTo(a.total))),
      ...widget.trailing,
    ];

    // All built (a short row), so a chip chosen from elsewhere far along it
    // exists to be scrolled to.
    Widget chipAt(int i) {
      final c = ranked[i];
      // A chip with nothing on it (a person all settled with, a category
      // with only paid items) barely rises from the page, in no color of
      // its own, and its text is faint; the others stand two steps up.
      final zero = c.total == 0;
      final bg = zero ? context.raisedBy(.35) : c.color ?? context.raisedBy(2);
      final fg = zero
          ? scheme.onSurfaceVariant.withValues(alpha: .5)
          : c.color != null
          ? _onColor(bg)
          : scheme.onSurface;
      final isSelected = selected == c.id;
      // Selection = the others fade back (no outline).
      final dimmed = selected != null && !isSelected;
      final total = formatMinorWithCommas(c.total);
      return GestureDetector(
        key: isSelected ? _chosen : null,
        onTap: () => onSelect(isSelected ? null : c.id),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: dimmed ? 0.4 : 1,
          child: Container(
            // Even above and below: the text centers itself (InkText).
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6.5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkText(
                  c.label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (isSelected && showTotal && c.showTotal) ...[
                  const SizedBox(width: 8),
                  InkText(
                    faDigitsFor(fa) ? toFaDigits(total) : total,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Full width: a short row starts at the line's start (in a centering
    // Column it shrank to its chips and sat in the middle).
    return SizedBox(
      width: double.infinity,
      height: 38,
      // More than fit: it shows that it scrolls ([ScrollHint]).
      child: HintedScroll(
        id: ScrollHint.chipsRow,
        builder: (context, scroll) => SingleChildScrollView(
          controller: scroll,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < ranked.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                i == 0 && widget.firstChipKey != null
                    ? KeyedSubtree(key: widget.firstChipKey, child: chipAt(i))
                    : chipAt(i),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

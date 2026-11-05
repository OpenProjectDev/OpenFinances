// lib/shared/ui/date_picker_dialog.dart
// The app's own date picker, in both calendars (the owner, 2026-11-02; the
// stock ones couldn't take any of this): its title centered, then three
// chips: the year and the month (each opens a grid to pick from) and Today.
// The month swipes (a nudge shows it does, [ScrollHint]); the day picked in a
// square with rounded corners, today with the heatmap's glow. Below, Cancel
// and a button that shows the date picked: a tap confirms. Where a date isn't
// expected in the future ([pastOnly]) or in the past ([futureOnly]), such days
// are faint and picking one turns it orange, with a chip of its own saying so
// and, nested in it, a button never to again; it can still be confirmed.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// Picks a day in [calendar], from [initial]; a local date at midnight, or
/// null if dismissed.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initial,
  required AppCalendar calendar,
  bool pastOnly = false,
  bool futureOnly = false,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _DatePickerDialog(
    initial: DateTime(initial.year, initial.month, initial.day),
    calendar: calendar,
    pastOnly: pastOnly,
    futureOnly: futureOnly,
  ),
);

/// A row of days' height, and the years' grid's.
const double _kCellH = 42;
const double _kYearH = 46;

/// The rows a month can take: one height for all, nothing jumps.
const int _kRows = 6;

/// The days, or a grid to pick the year or the month from.
enum _Showing { days, years, months }

class _DatePickerDialog extends StatefulWidget {
  const _DatePickerDialog({
    required this.initial,
    required this.calendar,
    required this.pastOnly,
    required this.futureOnly,
  });

  final DateTime initial;
  final AppCalendar calendar;
  final bool pastOnly, futureOnly;

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _picked = widget.initial;
  late final PageController _pages;
  late int _month; // the month shown: year * 12 + its index
  _Showing _showing = _Showing.days;

  bool get _jalali => widget.calendar == AppCalendar.jalali;

  int get _firstYear => _jalali ? 1380 : 2000;
  int get _lastYear => _jalali ? 1450 : 2100;
  int get _firstMonth => _firstYear * 12;
  int get _lastMonth => _lastYear * 12 + 11;

  int _monthOf(DateTime d) {
    if (_jalali) {
      final j = s.Jalali.fromDateTime(d);
      return j.year * 12 + j.month - 1;
    }
    return d.year * 12 + d.month - 1;
  }

  /// The month's first day and its length.
  (DateTime, int) _spanOf(int month) {
    final y = month ~/ 12, m = month % 12 + 1;
    if (_jalali) {
      final first = s.Jalali(y, m, 1);
      return (first.toDateTime(), first.monthLength);
    }
    return (DateTime(y, m, 1), DateTime(y, m + 1, 0).day);
  }

  /// 0: the calendar's first weekday (Saturday in Jalali, else Monday).
  int _column(DateTime d) => _jalali ? (d.weekday + 1) % 7 : d.weekday - 1;

  @override
  void initState() {
    super.initState();
    _month = _monthOf(widget.initial).clamp(_firstMonth, _lastMonth);
    _pages = PageController(initialPage: _month - _firstMonth);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Whether [day] is on the side not expected.
  bool _unexpected(DateTime day) =>
      (widget.pastOnly && day.isAfter(_today)) ||
      (widget.futureOnly && day.isBefore(_today));

  /// The warning's id ([SettingsProvider.neverShown]), one for each way.
  String get _warnId => widget.pastOnly ? 'date.future' : 'date.past';

  bool get _warn =>
      _unexpected(_picked) &&
      Provider.of<SettingsProvider?>(context)?.neverShown(_warnId) != true;

  /// Back to the days, on [month] (the months' pages are built again next
  /// frame when they weren't showing).
  void _showMonth(int month) {
    final to = month.clamp(_firstMonth, _lastMonth);
    final wasDays = _showing == _Showing.days;
    setState(() {
      _showing = _Showing.days;
      if (!wasDays) _month = to;
    });
    if (wasDays) {
      if (_pages.hasClients) {
        _pages.animateToPage(
          to - _firstMonth,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(to - _firstMonth);
    });
  }

  void _toToday() {
    setState(() => _picked = _today);
    _showMonth(_monthOf(_today));
  }

  void _toggle(_Showing what) =>
      setState(() => _showing = _showing == what ? _Showing.days : what);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fa = isFaUi(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    final letters = weekdayLetters(widget.calendar, fa);
    final names = monthNames(widget.calendar, fa);

    Widget chip(String text, VoidCallback onTap, {bool on = false}) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: on ? scheme.primary.withValues(alpha: .22) : context.raised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkText(
            text,
            textAlign: TextAlign.center,
            style: style?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );

    final Widget body = switch (_showing) {
      _Showing.years => _yearGrid(context, fa),
      _Showing.months => _monthPicker(context, names),
      _Showing.days => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final t in letters)
                Expanded(
                  child: InkText(
                    t,
                    textAlign: TextAlign.center,
                    style: style?.copyWith(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: _kCellH * _kRows,
            child: ScrollHint(
              id: ScrollHint.datePicker,
              controller: _pages,
              child: PageView.builder(
                controller: _pages,
                itemCount: _lastMonth - _firstMonth + 1,
                onPageChanged: (i) => setState(() => _month = _firstMonth + i),
                itemBuilder: (context, i) =>
                    _monthGrid(context, _firstMonth + i, fa),
              ),
            ),
          ),
        ],
      ),
    };

    const r = Radius.circular(12);
    return Dialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkText(
                l.pickDate,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: kSheetTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    chip(
                      uiDigits('${_month ~/ 12}', fa),
                      () => _toggle(_Showing.years),
                      on: _showing == _Showing.years,
                    ),
                    const SizedBox(width: 8),
                    chip(
                      names[_month % 12],
                      () => _toggle(_Showing.months),
                      on: _showing == _Showing.months,
                    ),
                    const SizedBox(width: 8),
                    chip(l.today, _toToday),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              body,
              const SizedBox(height: 8),
              // A date not expected there: one chip over the buttons, as tall
              // as they are, with the button to stop it for good nested in it
              // (the owner, 2026-11-04).
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                child: !_warn
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _WarnChip(
                          text: widget.pastOnly
                              ? l.futureDateWarning
                              : l.pastDateWarning,
                          never: l.neverWarn,
                          onNever: () => context
                              .read<SettingsProvider>()
                              .markNeverShown(_warnId),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: CancelButton(
                      onCancel: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('datePicker.confirm'),
                      style: saveButtonStyle(
                        context,
                        OutlinedButton.styleFrom(
                          overlayColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide.none,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(r),
                          ),
                        ),
                        true,
                        _warn ? kWarnOrange : null,
                      ),
                      onPressed: () => Navigator.of(context).pop(_picked),
                      child: InkText(
                        dayWithYear(_picked, widget.calendar, fa),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthGrid(BuildContext context, int month, bool fa) {
    final (first, length) = _spanOf(month);
    final lead = _column(first);
    final today = _today;
    return Column(
      children: [
        for (var r = 0; r < _kRows; r++)
          SizedBox(
            height: _kCellH,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: () {
                      final n = r * 7 + c - lead + 1;
                      if (n < 1 || n > length) return const SizedBox.shrink();
                      final day = DateTime(
                        first.year,
                        first.month,
                        first.day + n - 1,
                      );
                      return _Day(
                        text: uiDigits('$n', fa),
                        picked: day == _picked,
                        today: day == today,
                        warn: _warn && day == _picked,
                        unexpected: _unexpected(day),
                        onTap: () => setState(() => _picked = day),
                      );
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// The days' height, so nothing jumps.
  static const double _gridH = _kCellH * _kRows + 24;

  Widget _monthPicker(BuildContext context, List<String> names) {
    final shown = _month % 12;
    return SizedBox(
      height: _gridH,
      child: Column(
        children: [
          for (var r = 0; r < 4; r++)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: _GridChip(
                        text: names[r * 3 + c],
                        on: r * 3 + c == shown,
                        onTap: () => _showMonth(_month - shown + r * 3 + c),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _yearGrid(BuildContext context, bool fa) {
    final shown = _month ~/ 12;
    final count = _lastYear - _firstYear + 1;
    const perRow = 4;
    // This year about in the middle.
    final at = ((shown - _firstYear) ~/ perRow) * _kYearH;
    return SizedBox(
      height: _gridH,
      child: _YearsScroll(
        start: at - _gridH / 2 + _kYearH / 2,
        builder: (controller) => GridView.builder(
          controller: controller,
          itemCount: count,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: perRow,
            mainAxisExtent: _kYearH,
          ),
          itemBuilder: (context, i) {
            final year = _firstYear + i;
            return _GridChip(
              text: uiDigits('$year', fa),
              on: year == shown,
              onTap: () => _showMonth(year * 12 + _month % 12),
            );
          },
        ),
      ),
    );
  }
}

/// The warning: its words, and nested at its end the button to stop it.
class _WarnChip extends StatelessWidget {
  const _WarnChip({
    required this.text,
    required this.never,
    required this.onNever,
  });
  final String text, never;
  final VoidCallback onNever;

  @override
  Widget build(BuildContext context) {
    final ink = onColor(kWarnOrange);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    return Container(
      key: const ValueKey('datePicker.warning'),
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kWarnOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: InkText(text, textAlign: TextAlign.center, style: style),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNever,
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    ink.withValues(alpha: .2),
                    kWarnOrange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkText(never, maxLines: 1, style: style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A year or a month to pick.
class _GridChip extends StatelessWidget {
  const _GridChip({required this.text, required this.on, required this.onTap});
  final String text;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? scheme.primary : context.raised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkText(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? onColor(scheme.primary) : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The years' grid's scrolling, opened at [start], with its hint.
class _YearsScroll extends StatefulWidget {
  const _YearsScroll({required this.start, required this.builder});
  final double start;
  final Widget Function(ScrollController) builder;

  @override
  State<_YearsScroll> createState() => _YearsScrollState();
}

class _YearsScrollState extends State<_YearsScroll> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.start < 0 ? 0 : widget.start,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollHint(
    id: ScrollHint.datePickerYears,
    controller: _scroll,
    child: widget.builder(_scroll),
  );
}

/// A day: the one picked in a square with rounded corners (orange when it
/// warns), today glowing as in the heatmap, one not expected (a day on the side
/// where none is) faint but there to pick. A true square whatever the cell's
/// shape (the cell is wider than it is tall: filling it read as a rectangle).
class _Day extends StatelessWidget {
  const _Day({
    required this.text,
    required this.picked,
    required this.today,
    required this.warn,
    required this.unexpected,
    required this.onTap,
  });

  final String text;
  final bool picked, today, warn, unexpected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = warn ? kWarnOrange : scheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: picked
                    ? fill
                    : today
                    ? context.raised
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                // Kept within the gap to the days beside it.
                boxShadow: today
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: .6),
                          blurRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: InkText(
                text,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: picked || today
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: picked
                      ? onColor(fill)
                      : unexpected
                      ? scheme.onSurface.withValues(alpha: .45)
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

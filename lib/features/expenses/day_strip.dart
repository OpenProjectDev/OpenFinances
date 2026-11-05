// lib/features/expenses/day_strip.dart
// History's calendar (the owner, 2026-10-31): the period's weeks in the
// heatmap's tones (as Statistics' heatmap: the same cells, Monday to Sunday,
// Saturday to Friday in the Jalali calendar, the letters over them), whole
// or folded to one week. Folding is a movement, not a cut: the weeks slide
// up together until the chosen one stands where a folded week does, the
// others fading as they go; opening plays it back. Folded, a swipe snaps to
// the next week (a gap between weeks, as between days). The day gone to has
// a thin frame round it that slides to the next one picked (the owner,
// 2026-10-31; the list's rows aren't lit: one place says where you are); a
// tap on another day goes there. A handle under it switches whole / week.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/stats/statistics_page.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    super.key,
    required this.from,
    required this.to,
    required this.values,
    required this.pickable,
    required this.selected,
    required this.onPick,
    required this.whole,
    required this.onToggle,
    required this.calendar,
    required this.faDigits,
    this.backdrop,
  });

  /// The period's first and last days (local dates).
  final DateTime from, to;

  /// Each day's amount (its tone).
  final Map<DateTime, int> values;

  /// The days with something listed: only they can be gone to.
  final Set<DateTime> pickable;
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;

  /// The whole period (else one week); the handle asks to switch.
  final bool whole;
  final VoidCallback onToggle;
  final AppCalendar calendar;
  final bool faDigits;

  /// What it sits on (a day with nothing listed is faded toward it);
  /// default: the surface here.
  final Color? backdrop;

  /// As Statistics' heatmap: the gap between days (and weeks), the
  /// letters' size, the gap under them, a day number's share of its cell.
  static const double gap = 6, labelSize = 12, labelsGap = 14;
  static const double numberScale = .38;

  /// Room above and below the weeks for today's glow (its blur reaches ~9;
  /// taken from the gap under the letters, the rest from the handle's).
  static const double glow = 10;

  /// How far the frame stands out from its day: half the gap, all round.
  static const double frameOut = gap / 2;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar>
    with TickerProviderStateMixin {
  /// The frame's slide from [_frameFrom] (a week and a day, as numbers: it
  /// may be part way) to the day gone to. It only repaints the frame (the
  /// days aren't built again for it).
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  (double, double)? _frameFrom;

  /// The period's weeks, and each day's week and place in it (worked out
  /// when the period changes, not on every frame).
  late List<List<DateTime?>> _weeks;
  late Map<DateTime, (int, int)> _cells;

  void _layWeeks() {
    _weeks = _weeksOf();
    _cells = {
      for (var r = 0; r < _weeks.length; r++)
        for (var i = 0; i < 7; i++)
          if (_weeks[r][i] != null) _weeks[r][i]!: (r, i),
    };
  }

  /// [day]'s week and place in it (null: not in the period).
  (int, int)? _cellOf(DateTime? day) => day == null ? null : _cells[day];

  /// Where the frame is now, for [selected] as the day it's going to.
  (double, double)? _frameAt(DateTime? selected) {
    final to = _cellOf(selected);
    if (to == null) return null;
    final from = _frameFrom;
    if (from == null) return (to.$1.toDouble(), to.$2.toDouble());
    final v = Curves.easeInOutCubic.transform(_slide.value);
    return (
      lerpDouble(from.$1, to.$1.toDouble(), v)!,
      lerpDouble(from.$2, to.$2.toDouble(), v)!,
    );
  }

  /// 0: whole, 1: folded to [_week]. Its frames move the weeks already
  /// built, they don't build them again.
  late final _fold =
      AnimationController(
        vsync: this,
        duration: kSectionAnim,
        value: widget.whole ? 0 : 1,
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _swipeable();
      });
  late final _foldCurve = CurvedAnimation(
    parent: _fold,
    curve: Curves.easeInOutCubic,
  );

  /// The week shown folded.
  late int _week;

  /// The folded weeks' pages (only once folded: the fold itself is drawn).
  PageController? _pages;

  @override
  void initState() {
    super.initState();
    _layWeeks();
    _week = _weekOf();
    if (!widget.whole) _pages = PageController(initialPage: _week);
  }

  /// 1 = the calendar's first weekday (Saturday in Jalali, else Monday).
  int _weekday(DateTime d) => widget.calendar == AppCalendar.jalali
      ? (d.weekday + 1) % 7 + 1
      : d.weekday;

  /// The period's weeks, each seven days or empty places (before its first
  /// day, after its last), as the heatmap's rows.
  List<List<DateTime?>> _weeksOf() {
    final days = <DateTime>[];
    for (
      var d = DateTime(widget.from.year, widget.from.month, widget.from.day);
      !d.isAfter(widget.to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      days.add(d);
    }
    if (days.isEmpty) return const [];
    final cells = <DateTime?>[
      for (var i = 1; i < _weekday(days.first); i++) null,
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  /// The week with the day gone to (else today's, else the first).
  int _weekOf() {
    final now = DateTime.now();
    for (final d in [
      ?widget.selected,
      DateTime(now.year, now.month, now.day),
    ]) {
      final at = _cells[d];
      if (at != null) return at.$1;
    }
    return 0;
  }

  /// Folded and still: the weeks become pages to swipe.
  void _swipeable() {
    final old = _pages;
    setState(() => _pages = PageController(initialPage: _week));
    _later(old);
  }

  /// A page controller let go of once the frame no longer uses it.
  void _later(PageController? c) {
    if (c != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
    }
  }

  @override
  void didUpdateWidget(HistoryCalendar old) {
    super.didUpdateWidget(old);
    final period =
        old.from != widget.from ||
        old.to != widget.to ||
        old.calendar != widget.calendar;
    if (period) _layWeeks();
    if (old.selected != widget.selected) {
      // The frame slides from where it is (part way, maybe) to the new day;
      // there's none to slide from at first, or in another period. Folded,
      // to a day in another week: it comes in from that week's side as the
      // page turns (the owner, 2026-10-31: it showed, flickered, came back).
      final from = period ? null : _frameAt(old.selected);
      final to = _cellOf(widget.selected);
      if (!widget.whole &&
          _fold.isCompleted &&
          from != null &&
          to != null &&
          from.$1.round() != to.$1) {
        _frameFrom = (to.$1.toDouble(), from.$1 < to.$1 ? -1.0 : 7.0);
      } else {
        _frameFrom = from;
      }
      _slide.forward(from: 0);
    }
    if (old.whole != widget.whole) {
      if (widget.whole) {
        // Opening from the week shown (swiped to, maybe).
        final p = _pages;
        if (p != null && p.hasClients) _week = p.page!.round();
        _pages = null;
        _later(p);
        _fold.reverse();
      } else {
        _week = _weekOf();
        _fold.forward();
      }
    } else if (!widget.whole && (period || old.selected != widget.selected)) {
      final i = _weekOf();
      _week = i;
      final p = _pages;
      if (period) {
        _swipeable();
      } else if (p != null && p.hasClients && p.page?.round() != i) {
        p.animateToPage(
          i,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pages?.dispose();
    _slide.dispose();
    _foldCurve.dispose();
    _fold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weeks = _weeks;
    if (weeks.isEmpty) return const SizedBox.shrink();
    final letters = weekdayLetters(widget.calendar, isFaUi(context));
    var maxV = 0;
    for (final v in widget.values.values) {
      if (v > maxV) maxV = v;
    }
    final tones = heatBuckets(scheme.primary, Theme.of(context).brightness);
    final empty = scheme.surfaceContainerHighest;
    final backdrop = widget.backdrop ?? context.surfaceHere;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const g = HistoryCalendar.gap;
    const glow = HistoryCalendar.glow;
    const headerH = HistoryCalendar.labelSize * 1.6;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: HistoryCalendar.labelSize,
      fontWeight: FontWeight.w700,
    );
    final week = _week.clamp(0, weeks.length - 1);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(
      builder: (context, box) {
        // As the heatmap: seven across, the cells as wide as fit.
        final w = box.maxWidth;
        final c = (w - 6 * g) / 7;
        final pitch = c + g;

        Widget cell(DateTime? d) {
          if (d == null) {
            return Container(
              width: c,
              height: c,
              decoration: BoxDecoration(
                color: empty,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          }
          final v = widget.values[d] ?? 0;
          final b = heatBucket(v, maxV);
          final picked = d == widget.selected;
          var bg = b == 0 ? empty : tones[b - 1];
          var fg = b == 0
              ? scheme.onSurfaceVariant.withValues(alpha: .55)
              : (bg.computeLuminance() < .45
                    ? Colors.white
                    : Colors.black.withValues(alpha: .85));
          // Nothing listed that day: faded, nothing to go to. Its colors
          // are faded (as if seen through), not the cell: an opacity layer
          // per day is drawn apart on every frame (the list's scroll too).
          final pickable = widget.pickable.contains(d);
          var glowAlpha = .6;
          if (!pickable) {
            fg = Color.lerp(backdrop, Color.alphaBlend(fg, bg), .35)!;
            bg = Color.lerp(backdrop, bg, .35)!;
            glowAlpha *= .35;
          }
          final n = widget.calendar == AppCalendar.jalali
              ? s.Jalali.fromDateTime(d).day
              : d.day;
          final square = Container(
            width: c,
            height: c,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(5),
              // Today glows, as in the heatmap.
              boxShadow: d == today
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: glowAlpha),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: InkText(
              widget.faDigits ? toFaDigits('$n') : '$n',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: c * HistoryCalendar.numberScale,
                fontWeight: picked ? FontWeight.w800 : FontWeight.w600,
                color: fg,
              ),
            ),
          );
          if (!pickable) return square;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onPick(d),
            child: square,
          );
        }

        // Each week built once here; the fold and the frame move and paint
        // over them (their own layers), they don't build them again.
        final rows = [
          for (final days in weeks)
            RepaintBoundary(
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: g),
                    cell(days[i]),
                  ],
                ],
              ),
            ),
        ];

        // The frame round the day gone to: thin, standing half a gap out.
        Widget frame(Offset? Function() at) => IgnorePointer(
          child: CustomPaint(
            painter: DayFramePainter(
              at: at,
              cell: c,
              pitchX: pitch,
              pitchY: pitch,
              out: HistoryCalendar.frameOut,
              color: scheme.onSurface,
              rtl: rtl,
              repaint: _slide,
            ),
          ),
        );

        Widget grid(double t) {
          if (t >= 1 && _pages != null) {
            // Folded and still: a week a page, a gap between pages (as
            // between days), a swipe snapping to the next.
            return OverflowBox(
              minWidth: w + g,
              maxWidth: w + g,
              // Other weeks to swipe to: it shows that it swipes, until a
              // week has been swiped by hand ([ScrollHint]).
              child: ScrollHint(
                key: ObjectKey(_pages),
                id: ScrollHint.calendarWeeks,
                controller: _pages!,
                child: PageView.builder(
                  controller: _pages,
                  // Not clipped to the week's own height (the frame stands
                  // out above and below it): the weeks' clip round it does
                  // that.
                  clipBehavior: Clip.none,
                  itemCount: weeks.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: g / 2),
                    // The frame in its week (a day in another week: the page
                    // turning there carries it).
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        rows[i],
                        Positioned.fill(
                          child: frame(() {
                            final to = _cellOf(widget.selected);
                            if (to == null || to.$1 != i) return null;
                            final at = _frameAt(widget.selected)!;
                            return Offset(
                              at.$1.round() == i ? at.$2 : to.$2.toDouble(),
                              0,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          // Whole, or folding: the weeks slide up together until [week]
          // stands on top; the others fade as they go (together: one
          // layer, not one each).
          final fade = math.max(0.0, 1 - 1.6 * t);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (fade > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: t > 0,
                    child: Opacity(
                      opacity: fade,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var r = 0; r < weeks.length; r++)
                            if (r != week)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: (r - t * week) * pitch,
                                height: c,
                                child: rows[r],
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: (week - t * week) * pitch,
                height: c,
                child: rows[week],
              ),
              // Over the weeks, moving with them as they fold.
              Positioned.fill(
                child: frame(() {
                  final at = _frameAt(widget.selected);
                  if (at == null) return null;
                  return Offset(at.$2, at.$1 - _foldCurve.value * week);
                }),
              ),
            ],
          );
        }

        final wholeH = weeks.length * pitch - g;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: headerH,
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: g),
                    SizedBox(
                      width: c,
                      child: Center(
                        child: InkText(letters[i], style: labelStyle),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: HistoryCalendar.labelsGap - glow),
            // The weeks, clipped (a week sliding off goes under the
            // letters), with room for today's glow.
            AnimatedBuilder(
              animation: _foldCurve,
              builder: (context, _) {
                final t = _foldCurve.value;
                return SizedBox(
                  height: lerpDouble(wholeH, c, t)! + 2 * glow,
                  child: ClipRect(
                    clipper: const _SidesOut(HistoryCalendar.frameOut),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: glow),
                      child: grid(t),
                    ),
                  ),
                );
              },
            ),
            CalendarHandle(open: !widget.whole, onTap: widget.onToggle),
          ],
        );
      },
    );
  }
}

/// The thin frame round a picked day (History's calendar, Statistics'
/// heatmap): painted on its own, so its slide repaints only itself. [at]:
/// where it is now, in days across (from the start side) and weeks down;
/// null: none.
class DayFramePainter extends CustomPainter {
  DayFramePainter({
    required this.at,
    required this.cell,
    required this.pitchX,
    required this.pitchY,
    required this.out,
    required this.color,
    required this.rtl,
    this.top = 0,
    super.repaint,
  });

  final Offset? Function() at;
  final double cell, pitchX, pitchY, out, top;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final p = at();
    if (p == null) return;
    final x = p.dx * pitchX;
    final left = rtl ? size.width - x - cell : x;
    final box = Rect.fromLTWH(
      left - out,
      top + p.dy * pitchY - out,
      cell + 2 * out,
      cell + 2 * out,
    ).deflate(.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(5 + out - .5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(DayFramePainter old) => true;
}

/// The bar under History's calendar (the owner, 2026-10-31): [open], a
/// chevron down that opens the whole period; else up, folding it to one
/// week. Tall enough to stand clear of the last week.
class CalendarHandle extends StatelessWidget {
  const CalendarHandle({super.key, required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: open ? l.calendarFull : l.calendarWeek,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 34,
          child: Center(
            child: ImageIcon(
              open ? AppIcons.chevronDown : AppIcons.chevronUp,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The weeks' clip: their own box, and [out] more at each side (the frame
/// round a day at a side stands that far out; the next week's first day is
/// a whole gap away, so it stays hidden).
class _SidesOut extends CustomClipper<Rect> {
  const _SidesOut(this.out);
  final double out;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-out, 0, size.width + out, size.height);

  @override
  bool shouldReclip(_SidesOut old) => old.out != out;
}

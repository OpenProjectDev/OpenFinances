// lib/features/stats/statistics_page.dart
// ignore_for_file: unnecessary_brace_in_string_interps, prefer_const_constructors, unused_element_parameter

import 'package:openfinances/features/stats/category_charts.dart';
import 'package:openfinances/features/stats/period_bar_chart.dart';
import 'package:openfinances/features/stats/daily_area_chart.dart';
import 'package:openfinances/features/stats/pace_chart.dart';
import 'package:openfinances/shared/ui/period_place.dart';
import 'package:openfinances/shared/money_input.dart' show toFaDigits;
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/period_range.dart';
import 'package:openfinances/features/stats/stats_insights.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/hold_tip.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/percent_text.dart';
import 'package:openfinances/shared/ui/split_chip.dart';
import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/ui/period_picker.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/features/widgets/bare_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;

import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart'; // ← i18n
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/tips.dart';
import 'package:openfinances/shared/ui/category_legend.dart';
import 'package:openfinances/features/expenses/day_strip.dart'
    show DayFramePainter;
import 'package:openfinances/shared/ui/scroll_chain.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/keep_in_view.dart';
import 'package:openfinances/shared/ui/tile_pill.dart';

// Keep your AppCalendar enum in scope.

/// Padding used inside the pie and heatmap cards: sides, bottom, and the gap
/// between a card's title/chart and what comes after it.

/// One gap between every stacked section of the page (and the cards
/// carry no margin of their own), so all sections sit equally apart.
const double _kSectionGap = 16;

/// The heatmap's five tones of [base], lightest (least) to darkest (most);
/// History's day strip uses them too.
List<Color> heatBuckets(Color base, Brightness brightness) {
  final hsl = HSLColor.fromColor(base);
  final l = hsl.lightness;
  final steps = brightness == Brightness.dark
      ? <double>[l * 1.22, l * 1.04, l * 0.88, l * 0.74, l * 0.60]
      : <double>[l * 1.30, l * 1.12, l * 0.95, l * 0.80, l * 0.66];
  return steps
      .map((nl) => hsl.withLightness(nl.clamp(0.05, 0.92)).toColor())
      .toList();
}

/// Which of the five tones [v] takes against the biggest day [maxV] (0: no
/// tone, nothing that day).
int heatBucket(int v, int maxV) {
  if (v <= 0 || maxV == 0) return 0;
  return ((v / maxV) * 5).clamp(1, 5).toInt();
}

class JalaliAwareHeatmap extends StatefulWidget {
  final DateTime from; // inclusive
  final DateTime to; // inclusive
  final Map<DateTime, int> values; // local dates (00:00) -> amount
  final AppCalendar calendar;
  final bool faDigits;

  /// The day picked (framed), and a day picked: only days with something
  /// spent can be (the owner, 2026-10-31: an empty day doesn't take the
  /// frame or the preview).
  final DateTime? selected;
  final ValueChanged<DateTime>? onPick;

  /// The app's first day: days before it are faded (not "nothing spent":
  /// the app wasn't in use) and can't be tapped.
  final DateTime? activeFrom;

  // Base sizing (max); widget will shrink to fit width (no scroll)
  final double cell; // square size
  final double gap; // horizontal gap between week columns
  final double rowGap; // vertical gap between weekday rows
  final double labelsGap; // gap between grid and labels (right)
  final double labelFontSize; // weekday label size
  final double numberScale; // number size = cell * numberScale

  const JalaliAwareHeatmap({
    super.key,
    required this.from,
    required this.to,
    required this.values,
    required this.calendar,
    required this.faDigits,
    this.selected,
    this.onPick,
    this.activeFrom,
    this.cell = 28.0,
    this.gap = 10.0,
    this.rowGap = 10.0,
    this.labelsGap = 6.0,
    this.labelFontSize = 12.0,
    this.numberScale = 0.46,
  });

  @override
  State<JalaliAwareHeatmap> createState() => _JalaliAwareHeatmapState();
}

class _JalaliAwareHeatmapState extends State<JalaliAwareHeatmap>
    with SingleTickerProviderStateMixin {
  // Active tooltip state (shown only while finger is down)
  bool _tipVisible = false;
  String _tipText = '';

  /// Where the touch came down, when the tip came, and its going (a quick
  /// tap's tip comes all the way before it goes).
  Offset? _tipDown;
  DateTime _tipShownAt = DateTime(0);
  Timer? _tipHide;

  void _hideTip() {
    _tipDown = null;
    _tipHide?.cancel();
    final left = kTipFadeIn - DateTime.now().difference(_tipShownAt);
    void hide() {
      if (mounted) setState(() => _tipVisible = false);
    }

    if (left > Duration.zero) {
      _tipHide = Timer(left, hide);
    } else {
      hide();
    }
  }

  double _tipLeft = 0.0; // within grid (not including labels)
  double _tipTop = 0.0;

  /// The frame's slide to the day picked, from where it was (a column and
  /// a row, as seen left to right; part way, maybe): it repaints only the
  /// frame, as History's.
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  Offset? _frameFrom;

  /// Where the frame is now (null: none), with the day picked at [to].
  Offset? _frameAt(Offset? to) {
    if (to == null) return null;
    final from = _frameFrom;
    if (from == null) return to;
    return Offset.lerp(from, to, Curves.easeInOutCubic.transform(_slide.value));
  }

  /// Where [d] sits (column as seen, row), for [rtl] reading.
  Offset? _cellOf(DateTime? d, bool rtl) {
    if (d == null) return null;
    final first = DateTime(
      widget.from.year,
      widget.from.month,
      widget.from.day,
    );
    final end = DateTime(widget.to.year, widget.to.month, widget.to.day);
    if (d.isBefore(first) || d.isAfter(end)) return null;
    final at =
        _weekdayForCalendar(first) -
        1 +
        DateTime.utc(
          d.year,
          d.month,
          d.day,
        ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    final col = at % 7;
    return Offset((rtl ? 6 - col : col).toDouble(), (at ~/ 7).toDouble());
  }

  @override
  void didUpdateWidget(JalaliAwareHeatmap old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      final rtl = isFaUi(context);
      // From where it is to the new day (none in another period).
      _frameFrom = old.from == widget.from && old.to == widget.to
          ? _frameAt(_cellOf(old.selected, rtl))
          : null;
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tipHide?.cancel();
    _slide.dispose();
    super.dispose();
  }

  String _faDigits(String s) {
    if (!widget.faDigits) return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], fa[i]);
    }
    return s;
  }

  int _weekdayForCalendar(DateTime d) {
    if (widget.calendar == AppCalendar.jalali) {
      const map = {
        6: 1,
        7: 2,
        1: 3,
        2: 4,
        3: 5,
        4: 6,
        5: 7,
      }; // Sat..Fri => 1..7
      return map[d.weekday]!;
    }
    return d.weekday; // Mon..Sun
  }

  /// One-letter weekday headers in calendar order, in the UI language.
  List<String> _weekdayNames() =>
      weekdayLetters(widget.calendar, isFaUi(context));

  List<DateTime> _daysInclusive(DateTime a, DateTime b) {
    final start = DateTime(a.year, a.month, a.day);
    final end = DateTime(b.year, b.month, b.day);
    final out = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  List<Color> _primaryBuckets(Color base, Brightness brightness) =>
      heatBuckets(base, brightness);

  // Measure a one-line tip text width for positioning
  double _measureTipWidth(BuildContext ctx, String text, double fontSize) {
    final style = Theme.of(ctx).textTheme.bodySmall?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  String _amountText(int v) {
    final major = v / 100;
    final intPart = major.floor();
    final decPart = ((major - intPart) * 100).round();
    final s0 = intPart.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s0.length; i++) {
      final idxFromRight = s0.length - i;
      buf.write(s0[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) buf.write(',');
    }
    if (decPart > 0) {
      buf.write('.');
      buf.write(decPart.toString().padLeft(2, '0'));
    }
    return _faDigits(buf.toString());
  }

  // Laid out like a month calendar: 7 weekday columns (header on top) and
  // one row per week. That's 5-6 rows instead of 7 tall weekday rows with
  // wide side labels, so the card is shorter while cells stay square.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    // Faded days are their colors seen through onto the card (an opacity
    // layer per day is drawn apart on every frame).
    final backdrop = context.surfaceHere;

    final allDays = _daysInclusive(widget.from, widget.to);
    if (allDays.isEmpty) return const SizedBox.shrink();

    final leadingPads = _weekdayForCalendar(allDays.first) - 1;
    final totalCells = leadingPads + allDays.length;
    final rows = (totalCells / 7).ceil();
    final cells = <DateTime?>[
      for (int i = 0; i < leadingPads; i++) null,
      ...allDays,
      for (int i = totalCells; i < rows * 7; i++) null,
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int maxV = 0;
    for (final v in widget.values.values) {
      if (v > maxV) maxV = v;
    }
    int bucketOf(int v) {
      if (v <= 0 || maxV == 0) return 0;
      return ((v / maxV) * 5).clamp(1, 5).toInt();
    }

    final bucketColors = _primaryBuckets(scheme.primary, brightness);
    final Color defaultColor = scheme.surfaceContainerHighest;
    final names = _weekdayNames();
    // Weeks read in the UI direction (Persian: first weekday on the right),
    // whatever the digits (it went by them: Persian with English digits
    // read left to right).
    final rtl = isFaUi(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final g = widget.gap;
        final rg = widget.rowGap;
        // Square cells: as wide as fits, capped at the base size.
        final c = math.min(widget.cell, (constraints.maxWidth - 6 * g) / 7);
        final gridW = 7 * c + 6 * g;
        final headerH = widget.labelFontSize * 1.6;
        final top = headerH + widget.labelsGap;
        final totalH = top + rows * c + (rows - 1) * rg;
        final numberFontSize = c * widget.numberScale;

        // Visual (left-to-right) x of a weekday column.
        double colX(int weekday) => (rtl ? 6 - weekday : weekday) * (c + g);

        Widget tileFor(DateTime? d, int row, int col) {
          if (d == null) {
            return Container(
              width: c,
              height: c,
              decoration: BoxDecoration(
                color: defaultColor,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          }
          final before = widget.activeFrom;
          if (before != null && d.isBefore(before)) {
            // Before the app was used: a faded cell, its day number faint.
            return Container(
              width: c,
              height: c,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(backdrop, defaultColor, .35),
                borderRadius: BorderRadius.circular(5),
              ),
              child: InkText(
                _faDigits(
                  (widget.calendar == AppCalendar.jalali
                          ? s.Jalali.fromDateTime(d).day
                          : d.day)
                      .toString(),
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: numberFontSize,
                  fontWeight: FontWeight.w600,
                  color: Color.lerp(
                    backdrop,
                    Color.alphaBlend(scheme.onSurfaceVariant, defaultColor),
                    .35,
                  ),
                ),
              ),
            );
          }
          final v = widget.values[DateTime(d.year, d.month, d.day)] ?? 0;
          final b = bucketOf(v);
          final bg = b == 0 ? defaultColor : bucketColors[b - 1];
          final fg = (bg.computeLuminance() < 0.45)
              ? Colors.white
              : Colors.black.withValues(alpha: 0.85);
          final dayNum = widget.calendar == AppCalendar.jalali
              ? s.Jalali.fromDateTime(d).day
              : d.day;
          final isToday = d == today;
          final pick = widget.onPick;
          final pickable = pick != null && v > 0;

          void showTip() {
            final tip = _amountText(v);
            final tipW = _measureTipWidth(context, tip, 12.0) + 16.0;
            setState(() {
              _tipText = tip;
              _tipLeft = (colX(col) + (c - tipW) / 2).clamp(
                0.0,
                math.max(0.0, gridW - tipW),
              );
              _tipTop = math.max(-8.0, top + row * (c + rg) - 28.0 - 6.0);
              _tipVisible = true;
            });
          }

          final cell = Container(
            width: c,
            height: c,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(5),
              // Today's glow kept within half the gap (the owner,
              // 2026-10-31: wider, it went under the days beside it).
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: math.min(g, rg) / 2,
                      ),
                    ]
                  : null,
            ),
            child: InkText(
              _faDigits(dayNum.toString()),
              maxLines: 1,
              overflow: TextOverflow.clip,
              // No forced strut: InkText centers the digits' ink in the
              // font's own line box (a 1.0 strut squeezed that box and
              // the digits sat low).
              style: TextStyle(
                fontSize: numberFontSize,
                fontWeight: d == widget.selected
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: b == 0
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                    : fg,
              ),
            ),
          );
          // The amount from the touch (as every tip: a tap too, the owner,
          // 2026-10-31: the tap picking the day had taken it); a tap also
          // picks the day.
          return Listener(
            onPointerDown: (e) {
              _tipDown = e.position;
              _tipShownAt = DateTime.now();
              _tipHide?.cancel();
              showTip();
            },
            onPointerMove: (e) {
              final at = _tipDown;
              if (at != null && (e.position - at).distance > kTouchSlop) {
                _hideTip(); // a scroll
              }
            },
            onPointerUp: (_) => _hideTip(),
            onPointerCancel: (_) => _hideTip(),
            child: GestureDetector(
              onTap: pickable ? () => pick(d) : null,
              child: cell,
            ),
          );
        }

        final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: widget.labelFontSize,
          fontWeight: FontWeight.w700,
        );

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: gridW,
            height: totalH,
            // Children are positioned in left-to-right coordinates.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int col = 0; col < 7; col++)
                    Positioned(
                      left: colX(col),
                      top: 0,
                      width: c,
                      height: headerH,
                      child: Center(
                        child: InkText(names[col], style: labelStyle),
                      ),
                    ),
                  // The days drawn once: the frame and the tip move over
                  // them.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int row = 0; row < rows; row++)
                            for (int col = 0; col < 7; col++)
                              Positioned(
                                left: colX(col),
                                top: top + row * (c + rg),
                                child: tileFor(cells[row * 7 + col], row, col),
                              ),
                        ],
                      ),
                    ),
                  ),
                  // The day picked: History's thin frame, sliding from the
                  // one before.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: DayFramePainter(
                          at: () => _frameAt(_cellOf(widget.selected, rtl)),
                          cell: c,
                          pitchX: c + g,
                          pitchY: c + rg,
                          top: top,
                          out: g / 2,
                          color: scheme.onSurface,
                          rtl: false,
                          repaint: _slide,
                        ),
                      ),
                    ),
                  ),
                  // Fading out slowly once the finger lifts (as every tip).
                  if (_tipText.isNotEmpty)
                    Positioned(
                      left: _tipLeft,
                      top: _tipTop,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _tipVisible ? 1 : 0,
                          duration: _tipVisible ? kTipFadeIn : kTipFadeOut,
                          onEnd: () {
                            if (!_tipVisible && mounted) {
                              setState(() => _tipText = '');
                            }
                          },
                          child: _CostPill(text: _tipText),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Simple pill widget for the popup amount
class _CostPill extends StatelessWidget {
  final String text;
  const _CostPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: cs.surface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: InkText(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Tip> _tips() => [
    Tip('stats.sections', [_tipSection], (l) => l.tipSections),
  ];

  // ==== Config (mirrors ExpensesPage) ====
  static const int kMinOffset = -240;

  /// The earliest entry's day in [rows] (null: none).
  static DateTime? _firstDate(List<Map<String, dynamic>> rows) {
    DateTime? first;
    for (final e in rows) {
      final t = (e['occurredAtUtc'] as DateTime).toLocal();
      if (first == null || t.isBefore(first)) first = t;
    }
    return first == null ? null : DateTime(first.year, first.month, first.day);
  }

  /// The first entry's day, expenses or income, whichever came first (null:
  /// none yet): nothing before it counts anywhere here (the owner, 2026-11-03).
  DateTime? _firstEntry;
  List<Object>? _firstEntryFor;

  DateTime? _firstEntryOf(
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> incomes,
  ) {
    final had = _firstEntryFor;
    if (had != null &&
        identical(had[0], expenses) &&
        identical(had[1], incomes)) {
      return _firstEntry;
    }
    final a = _firstDate(expenses), b = _firstDate(incomes);
    _firstEntryFor = [expenses, incomes];
    return _firstEntry = a == null || (b != null && b.isBefore(a)) ? b : a;
  }

  /// The oldest period to go to here: the first entry's.
  int _oldestPeriod(AppCalendar cal, int startDay) {
    final first = _firstEntry;
    if (first == null) return kMaxOffset;
    for (var k = kMaxOffset; k > kMinOffset; k--) {
      if (!first.isBefore(_currentRangeByCalendar(cal, startDay, k).$1)) {
        return k;
      }
    }
    return kMinOffset;
  }

  /// "At a glance": what it worked out (the shown period) and from what.
  StatsGlance? _glance;
  List<Object>? _glanceFor;
  String? _glanceKey;
  static const int kMaxOffset = 0;
  static const double kGutter = 12;

  double _bottomScrollInset(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final navGuess = Theme.of(context).useMaterial3
        ? 80.0
        : kBottomNavigationBarHeight;
    return bottomPad + navGuess + 16;
  }

  // ==== State for charts ====
  /// The lit slice, heard only by the ring and its chips: a touch doesn't
  /// rebuild the page (the owner, 2026-10-30: lights lagged scrolling).
  final _touchedIndex = ValueNotifier<int>(-1);

  /// The heatmap's day picked (its preview under it), heard by that card
  /// alone.
  final _previewDay = ValueNotifier<DateTime?>(null);

  @override
  void dispose() {
    _touchedIndex.dispose();
    _previewDay.dispose();
    super.dispose();
  }

  /// The period's expenses, by category and by day: worked out again only
  /// when the data or the period changes (the page builds again on every
  /// chip or pie toggle).
  (List<Map<String, dynamic>>, Map<String, int>, Map<DateTime, int>)? _period;
  (List<Map<String, dynamic>>, DateTime, DateTime)? _periodFor;

  /// A preview row tapped: History, on that entry.
  void _openInHistory(Map<String, dynamic> e) {
    final t = (e['occurredAtUtc'] as DateTime).toLocal();
    // History is the first tab; Back comes back here.
    mainTab.value = 0;
    historyFocusRequest.value = HistoryFocus(
      gid: (e['gid'] ?? e['_id']).toString(),
      day: DateTime(t.year, t.month, t.day),
    );
  }

  /// Categories taken off the pie (their legend box unticked); kept while
  /// the page is open, across periods.
  final Set<String> _offPie = {};

  // selected category for per-range bar chart
  String? _selectedCategoryGid;

  // ==== Persian helpers ====
  String _toFaDigits(String s) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], fa[i]);
    }
    return s;
  }

  String _digitsForLocale(BuildContext context, String s) {
    final isFa = isFaUi(context);
    if (!faDigitsFor(isFa)) return s;
    return _toFaDigits(s);
  }

  String _formatMoneyInt(int n) {
    // Convert minor units to major units with decimals
    final major = n / 100;
    final intPart = major.floor();
    final decPart = (major - intPart) * 100;

    // Format integer part with commas
    final s0 = intPart.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s0.length; i++) {
      final idxFromRight = s0.length - i;
      buf.write(s0[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) buf.write(',');
    }

    // Add decimal part if not zero
    if (decPart > 0) {
      buf.write('.');
      buf.write(decPart.round().toString().padLeft(2, '0'));
    }

    return buf.toString();
  }

  // ---------- Helpers for Jalali <-> Gregorian ranges ----------
  // label generators depending on calendar
  // label generators depending on calendar
  String _rangeLabelOf(int offset, int startDay, SettingsProvider sp) {
    final fa = isFaUi(context);
    if (sp.calendar == AppCalendar.jalali) {
      final (js, je) = jalaliPeriod(offset, startDay);
      return rangeText(js.toDateTime(), je.toDateTime(), sp.calendar, fa);
    }
    final (gs, ge) = gregorianPeriod(offset, startDay);
    return rangeText(gs, ge, sp.calendar, fa);
  }

  (DateTime start, DateTime end) _currentRangeByCalendar(
    AppCalendar cal,
    int startDay,
    int periodOffset,
  ) {
    if (cal == AppCalendar.jalali) {
      final (js, je) = jalaliPeriod(periodOffset, startDay);
      final start = js.toDateTime();
      final end = je.toDateTime().add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      return (start, end);
    } else {
      // To the last day's last second (its start alone left that day's
      // entries out).
      final (start, end) = gregorianPeriod(periodOffset, startDay);
      return (
        start,
        end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
    }
  }

  // ==== Range list sheet — supports both calendars ====
  Future<void> _openRangeList() async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        final settings = sheetCtx.watch<SettingsProvider>();
        final textMain = cs.onSurface;

        final offsets = List<int>.generate(
          kMaxOffset - _oldestPeriod(settings.calendar, settings.startDay) + 1,
          (i) => kMaxOffset - i,
        );

        return SheetPull(
          // A long list: pulled down at its top, the sheet closes.
          child: Directionality(
            textDirection: uiTextDirection(isFaUi(context)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkText(
                      l.selectRange,
                      style: TextStyle(
                        fontSize: kSheetTitleSize,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: kSheetTitleGap),
                    SizedBox(
                      height: MediaQuery.sizeOf(sheetCtx).height * 0.415,
                      child: ListView.separated(
                        itemCount: offsets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final off = offsets[i];
                          final selected = off == settings.periodOffset;
                          final label = _rangeLabelOf(
                            off,
                            settings.startDay,
                            settings,
                          );
                          return OutlinedButton(
                            onPressed: () {
                              settings.setPeriodOffset(off);
                              _touchedIndex.value = -1;
                              Navigator.pop(sheetCtx);
                            },
                            style: OutlinedButton.styleFrom(
                              overlayColor: Colors.transparent,
                              minimumSize: const Size.fromHeight(40),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
                              ),
                              backgroundColor: selected
                                  ? cs.primary.withValues(alpha: .15)
                                  : cs.surfaceContainerHigh,
                              foregroundColor: textMain,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: InkText(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? context.primaryInk
                                      : textMain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: InkText(l.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==== Range control button ====
  Widget _rangeControl(BuildContext context, int startDay, AppCalendar cal) {
    final l = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final periodOffset = settings.periodOffset;
    final canPrev = periodOffset > _oldestPeriod(cal, startDay);
    final canNext = periodOffset < kMaxOffset;

    return PeriodPicker(
      label: _rangeLabelOf(periodOffset, startDay, settings),
      labelDirection: uiTextDirection(isFaUi(context)),
      canPrev: canPrev,
      canNext: canNext,
      onPrev: () {
        settings.setPeriodOffset(periodOffset - 1);
        _touchedIndex.value = -1;
      },
      onNext: () {
        settings.setPeriodOffset(periodOffset + 1);
        _touchedIndex.value = -1;
      },
      onOpenList: _openRangeList,
      prevTooltip: l.prevPeriod,
      nextTooltip: l.nextPeriod,
    );
  }

  // ==== Aggregation helpers ====
  DateTime _normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The daily chart's days ([dailyDaysOf]), kept while the data, the periods
  /// and the day are the same.
  ({
    List<DateTime> days,
    List<int?> current,
    List<DateTime> beforeDays,
    List<int?> previous,
    int skipped,
  })?
  _daily;
  List<Object?>? _dailyFor;

  ({
    List<DateTime> days,
    List<int?> current,
    List<DateTime> beforeDays,
    List<int?> previous,
    int skipped,
  })
  _dailySeries(
    List<Map<String, dynamic>> all,
    (DateTime, DateTime) shown,
    (DateTime, DateTime) before,
    DateTime? firstEntry,
  ) {
    final today = _normalizeDay(DateTime.now());
    final key = [all, shown.$1, shown.$2, before.$1, today, firstEntry];
    final had = _dailyFor;
    if (_daily != null &&
        had != null &&
        identical(had[0], all) &&
        had[1] == key[1] &&
        had[2] == key[2] &&
        had[3] == key[3] &&
        had[4] == key[4] &&
        had[5] == key[5]) {
      return _daily!;
    }
    _dailyFor = key;
    return _daily = dailyDaysOf(
      expenses: all,
      shown: shown,
      before: before,
      firstEntry: firstEntry,
      now: today,
    );
  }

  /// The same-day averages for period [offset] (kept while the data, the
  /// periods and the day are the same).
  List<int?>? _sameDay;
  List<Object?>? _sameDayFor;

  List<int?> _sameDayOf(
    List<Map<String, dynamic>> all,
    int offset,
    PeriodRangeOf rangeOf,
    DateTime? firstUse,
    (AppCalendar, int) periods,
  ) {
    final today = _normalizeDay(DateTime.now());
    final had = _sameDayFor;
    if (_sameDay != null &&
        had != null &&
        identical(had[0], all) &&
        had[1] == offset &&
        had[2] == firstUse &&
        had[3] == periods &&
        had[4] == today) {
      return _sameDay!;
    }
    _sameDayFor = [all, offset, firstUse, periods, today];
    return _sameDay = sameDayAverages(
      expenses: all,
      offset: offset,
      rangeOf: rangeOf,
      now: DateTime.now(),
      firstUse: firstUse,
    );
  }

  // ==== Per-period aggregation (cached) ====
  // Every period (a month from startDay) between the first expense and the
  // current one that has data, with totals and per-category series. One pass
  // over the expenses (binary search per row), cached until the data or the
  // period settings change, so pie taps etc. don't recompute it.
  _RangeStats? _stats;
  List<Map<String, dynamic>>? _statsFor;
  (int, AppCalendar, int)? _statsKey;

  _RangeStats _rangeStats(SettingsProvider sp, List<Map<String, dynamic>> all) {
    final key = (sp.startDay, sp.calendar, sp.periodOffset);
    final cached = _stats;
    if (cached != null && identical(_statsFor, all) && _statsKey == key) {
      return cached;
    }
    final result = _computeRangeStats(sp, all);
    _stats = result;
    _statsFor = all;
    _statsKey = key;
    return result;
  }

  _RangeStats _computeRangeStats(
    SettingsProvider sp,
    List<Map<String, dynamic>> all,
  ) {
    if (all.isEmpty) return _paddedStats(sp, const [], const {});
    DateTime minDate = (all.first['occurredAtUtc'] as DateTime).toLocal();
    for (final e in all) {
      final dt = (e['occurredAtUtc'] as DateTime).toLocal();
      if (dt.isBefore(minDate)) minDate = dt;
    }

    // Month distance to today, minus one: with a start day after the 1st
    // the oldest expense can sit in the previous month's period.
    final int minOffset;
    if (sp.calendar == AppCalendar.jalali) {
      final today = s.Jalali.now();
      final m = s.Jalali.fromDateTime(minDate);
      minOffset = (m.year - today.year) * 12 + (m.month - today.month) - 1;
    } else {
      final today = DateTime.now();
      minOffset =
          (minDate.year - today.year) * 12 + (minDate.month - today.month) - 1;
    }

    final starts = <DateTime>[];
    final ends = <DateTime>[];
    final offsets = <int>[];
    for (var off = minOffset; off <= 0; off++) {
      final (st, en) = _currentRangeByCalendar(sp.calendar, sp.startDay, off);
      starts.add(st);
      ends.add(en);
      offsets.add(off);
    }
    final n = starts.length;
    final totals = List<int>.filled(n, 0);
    final counts = List<int>.filled(n, 0);
    final perCat = <String, List<int>>{};
    for (final e in all) {
      final dt = (e['occurredAtUtc'] as DateTime).toLocal();
      // Last period starting at or before dt.
      var lo = 0, hi = n - 1, idx = -1;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        if (!starts[mid].isAfter(dt)) {
          idx = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      if (idx < 0 || dt.isAfter(ends[idx])) continue;
      final amt = (e['amountMinor'] as int?) ?? 0;
      totals[idx] += amt;
      counts[idx]++;
      final gid = (e['categoryGid'] as String?) ?? 'unknown';
      (perCat[gid] ??= List<int>.filled(n, 0))[idx] += amt;
    }

    final kept = [
      for (var i = 0; i < n; i++)
        if (counts[i] > 0) i,
    ];
    final perKept = {
      for (final e in perCat.entries) e.key: [for (final i in kept) e.value[i]],
    };
    return _paddedStats(sp, [
      for (final i in kept) (offsets[i], starts[i], ends[i], totals[i]),
    ], perKept);
  }

  /// [kept] (periods with data: offset, start, end, total; oldest first)
  /// as buckets, with empty periods before them up to [kMinPeriods] (the
  /// owner: a chart always shows at least that many, an empty one being just
  /// its line and its date: an absence of data, so no data before the first
  /// entry, 2026-11-03).
  _RangeStats _paddedStats(
    SettingsProvider sp,
    List<(int, DateTime, DateTime, int)> kept,
    Map<String, List<int>> perKept,
  ) {
    String keyOf(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final missing = math.max(0, kMinPeriods - kept.length);
    final firstOffset = kept.isEmpty ? 1 : kept.first.$1;
    final all = <(int, DateTime, DateTime, int)>[
      for (var off = firstOffset - missing; off < firstOffset; off++)
        () {
          final (st, en) = _currentRangeByCalendar(
            sp.calendar,
            sp.startDay,
            off,
          );
          return (off, st, en, 0);
        }(),
      ...kept,
    ];
    return _RangeStats(
      [
        for (final (_, st, en, total) in all)
          _RangeBucket(key: keyOf(st), start: st, end: en, total: total),
      ],
      all.indexWhere((e) => e.$1 == sp.periodOffset),
      {
        for (final e in perKept.entries)
          e.key: [...List.filled(missing, 0), ...e.value],
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      TipsTrigger(tips: _tips, child: _body(context));

  Widget _body(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ep = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final startDay = settings.startDay;
    final cal = settings.calendar;

    final all = ep.raw;

    // compute current from/to by calendar
    final (from, to) = _currentRangeByCalendar(
      cal,
      startDay,
      settings.periodOffset,
    );

    final had = _periodFor;
    if (_period == null ||
        had == null ||
        !identical(had.$1, all) ||
        had.$2 != from ||
        had.$3 != to) {
      // inRange for current selected period
      final inRange = all.where((e) {
        final dtLocal = (e['occurredAtUtc'] as DateTime).toLocal();
        return !dtLocal.isBefore(from) && !dtLocal.isAfter(to);
      }).toList();

      // by category totals for current range (for pie)
      final Map<String, int> byCat = {};
      // per-day heatmap
      final Map<DateTime, int> byDay = {};
      for (final e in inRange) {
        final gid = (e['categoryGid'] as String?) ?? 'unknown';
        final amt = (e['amountMinor'] as int?) ?? 0;
        byCat.update(gid, (v) => v + amt, ifAbsent: () => amt);
        final d = _normalizeDay((e['occurredAtUtc'] as DateTime).toLocal());
        byDay.update(d, (v) => v + amt, ifAbsent: () => amt);
      }
      _period = (inRange, byCat, byDay);
      _periodFor = (all, from, to);
    }
    final (inRange, byCat, byDay) = _period!;
    // Only categories that take room in the pie (none at 0).
    final sortedCat = byCat.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalThisRange = byCat.values.fold<int>(0, (s, v) => s + v);

    // All periods with data (one cached pass, see _rangeStats).
    final stats = _rangeStats(settings, all);
    final buckets = stats.buckets;
    final selectedBucketIndex = stats.selectedIndex;
    final perCategorySeries = stats.perCategory;

    // "At a glance": the picked days (from the period's first day to today
    // in a new period, none after today), worked out again only when the
    // data, the days or the day changes (this page rebuilds on every touch
    // of the pie).
    final today = DateTime.now();
    final incomes = context.watch<IncomeProvider>().raw;
    final firstEntry = _firstEntryOf(all, incomes);
    (DateTime, DateTime) rangeOf(int k) =>
        _currentRangeByCalendar(cal, startDay, k);
    final offset = settings.periodOffset;
    final glanceKey =
        '$offset|$startDay|${cal.name}|'
        '${today.year}-${today.month}-${today.day}';
    if (_glance == null ||
        _glanceKey != glanceKey ||
        !identical(_glanceFor?[0], all) ||
        !identical(_glanceFor?[1], incomes)) {
      _glance = computeGlance(
        expenses: all,
        offset: offset,
        rangeOf: rangeOf,
        now: today,
        firstUse: firstEntry,
      );
      _glanceFor = [all, incomes];
      _glanceKey = glanceKey;
    }
    final glance = _glance!;

    // Filter to categories that have any data (non-zero sum across buckets)
    final categoryTotalsAcrossBuckets = perCategorySeries.map(
      (k, v) => MapEntry(k, v.fold<int>(0, (a, b) => a + b)),
    );
    final categoriesWithData =
        categoryTotalsAcrossBuckets.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // descending total

    // ensure selected category is valid
    if (_selectedCategoryGid == null && categoriesWithData.isNotEmpty) {
      _selectedCategoryGid = categoriesWithData.first.key;
    } else if (_selectedCategoryGid != null &&
        !categoryTotalsAcrossBuckets.containsKey(_selectedCategoryGid)) {
      _selectedCategoryGid = categoriesWithData.isNotEmpty
          ? categoriesWithData.first.key
          : null;
    }

    // For the pie legend compute percent for each displayed category (pie uses current range)
    final pieTotal = byCat.values.fold<int>(0, (a, b) => a + b);
    final pieEntries = sortedCat;

    // Layout follows the UI language (it used to be forced RTL).
    return Directionality(
      textDirection: uiTextDirection(isFaUi(context)),
      child: Scaffold(
        appBar: bareAppBar(),
        // No inline text fields here; don't relayout under add-sheet keyboards.
        resizeToAvoidBottomInset: false,
        // The period bar stays in view while the page scrolls under it, as
        // on Home (the owner, 2026-10-31).
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, kGutter, kGutter, 8),
              child: _rangeControl(context, startDay, cal),
            ),
            Expanded(
              child: TabScrollTop(
                tab: 2,
                // Tapping this tab again scrolls back up.
                builder: (list) => PeriodPlace(
                  controller: list,
                  child: CustomScrollView(
                    controller: list,
                    slivers: [
                      // Under the period bar (it stays), as far as it was.
                      const SliverToBoxAdapter(
                        child: SizedBox(height: _kSectionGap - 8),
                      ),

                      // --- At a glance: the total, the days, then figures ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            kGutter,
                            0,
                            kGutter,
                            _kSectionGap,
                          ),
                          child: _GlanceSection(
                            total: _TotalCard(
                              value: _digitsForLocale(
                                context,
                                _formatMoneyInt(totalThisRange),
                              ),
                              label: l.totalThisPeriod,
                            ),
                            glance: glance,
                            money: (n) =>
                                _digitsForLocale(context, _formatMoneyInt(n)),
                          ),
                        ),
                      ),

                      // --- Pie + Heatmap ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            kGutter,
                            0,
                            kGutter,
                            0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final isWide = c.maxWidth >= 700;
                              final pie = _CategoryPieCardCompact(
                                entries: pieEntries,
                                total: pieTotal,
                                // Heard only when the slice changes (it's called
                                // for every finger movement).
                                onTouch: (i) => _touchedIndex.value = i,
                                colorOf: (gid, idx) =>
                                    _categoryColor(ep, gid, idx),
                                nameOf: (gid) => ep.categoryName(gid),
                                touchedIndex: _touchedIndex,
                                off: _offPie,
                                onToggle: (gid) {
                                  _touchedIndex.value = -1;
                                  setState(() {
                                    if (!_offPie.remove(gid)) _offPie.add(gid);
                                  });
                                },
                              );

                              final heat = _HeatmapCard(
                                from: from,
                                to: to,
                                values: byDay,
                                activeFrom: firstEntry,
                                calendar: cal,
                                // Digits as chosen (the UI language's by default).
                                faDigits: faDigitsFor(isFaUi(context)),
                                entries: inRange,
                                picked: _previewDay,
                                nameOf: ep.categoryName,
                                colorOf: (gid) => _categoryColor(
                                  ep,
                                  gid == null || gid.isEmpty
                                      ? ep.fallbackCategoryGid
                                      : gid,
                                  0,
                                ),
                                money: (n) => _digitsForLocale(
                                  context,
                                  _formatMoneyInt(n),
                                ),
                                onOpen: _openInHistory,
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: pie),
                                    const SizedBox(width: 12),
                                    Expanded(child: heat),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    pie,
                                    const SizedBox(height: _kSectionGap),
                                    heat,
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),

                      // --- Daily spending: this period, the one before, the
                      // same day's average, the daily average (the owner,
                      // 2026-11-01) ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            kGutter,
                            _kSectionGap,
                            kGutter,
                            0,
                          ),
                          child: Builder(
                            builder: (context) {
                              final (
                                :days,
                                :current,
                                :beforeDays,
                                :previous,
                                :skipped,
                              ) = _dailySeries(
                                all,
                                (from, to),
                                _currentRangeByCalendar(
                                  cal,
                                  startDay,
                                  settings.periodOffset - 1,
                                ),
                                firstEntry,
                              );
                              // All of it before the first entry: nothing to
                              // chart.
                              if (days.isEmpty) return const SizedBox.shrink();
                              final fa = isFaUi(context);
                              DateTime dayAt(int i) =>
                                  i < days.length ? days[i] : beforeDays[i];
                              final todayAt = () {
                                final now = DateTime.now();
                                return days.indexOf(
                                  DateTime(now.year, now.month, now.day),
                                );
                              }();
                              String dayLabel(int i) {
                                final d = dayAt(i);
                                final n = cal == AppCalendar.jalali
                                    ? s.Jalali.fromDateTime(d).day
                                    : d.day;
                                return _digitsFor(context, '$n');
                              }

                              // Running totals (the pace chart).
                              List<int?> running(List<int?> v) {
                                var sum = 0;
                                return [
                                  for (final x in v)
                                    if (x == null) null else sum += x,
                                ];
                              }

                              final sameDay = _sameDayOf(
                                all,
                                settings.periodOffset,
                                rangeOf,
                                firstEntry,
                                (cal, startDay),
                              ).sublist(skipped);
                              final daily = FoldSection(
                                id: 'stats.daily',
                                title: l.dailySpending,
                                initiallyOpen: true,
                                child: DailyAreaChart(
                                  current: current,
                                  previous: previous,
                                  sameDay: sameDay,
                                  average: glance.overallPerDay,
                                  today: todayAt,
                                  dayLabel: dayLabel,
                                  dateOf: (i) => dayTitle(dayAt(i), cal, fa),
                                  number: (m) =>
                                      _digitsFor(context, shortMoney(m)),
                                  amount: (m) =>
                                      _digitsFor(context, _moneyFull(m)),
                                  labels: {
                                    DailySeries.current: l.thisPeriodLine,
                                    DailySeries.previous: l.lastPeriodLine,
                                    DailySeries.sameDay: l.sameDayAverage,
                                    DailySeries.average: l.statsDailyAverage,
                                  },
                                ),
                              );
                              // --- Spending pace: running totals, this
                              // period against the one before (the owner,
                              // 2026-11-01) ---
                              final pace = FoldSection(
                                id: 'stats.pace',
                                title: l.spendingPace,
                                initiallyOpen: true,
                                child: PaceChart(
                                  current: running(current),
                                  previous: running(previous),
                                  sameDay: running(sameDay),
                                  average: glance.overallPerDay,
                                  dateOf: (i) => dayTitle(dayAt(i), cal, fa),
                                  number: (m) =>
                                      _digitsFor(context, shortMoney(m)),
                                  amount: (m) =>
                                      _digitsFor(context, _moneyFull(m)),
                                  labels: {
                                    PaceSeries.current: l.thisPeriodLine,
                                    PaceSeries.previous: l.lastPeriodLine,
                                    PaceSeries.sameDay: l.sameDayAverage,
                                    PaceSeries.average: l.statsDailyAverage,
                                  },
                                ),
                              );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  daily,
                                  const SizedBox(height: _kSectionGap),
                                  pace,
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // --- All ranges chart ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            kGutter,
                            _kSectionGap,
                            kGutter,
                            _kSectionGap,
                          ),
                          child: _AllRangesCard(
                            buckets: buckets,
                            calendar: cal,
                            selectedIndex: selectedBucketIndex,
                          ),
                        ),
                      ),

                      // --- Per-category per-range bar chart ---
                      if (categoriesWithData.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              kGutter,
                              0,
                              kGutter,
                              _kSectionGap,
                            ),
                            child: _PerCategoryRangesCard(
                              buckets: buckets,
                              categoryIds: categoriesWithData
                                  .map((e) => e.key)
                                  .toList(),
                              perCategorySeries: perCategorySeries,
                              colorOf: (gid, idx) =>
                                  _categoryColor(ep, gid, idx),
                              selectedCategoryGid: _selectedCategoryGid,
                              onSelectedChanged: (g) =>
                                  setState(() => _selectedCategoryGid = g),
                              calendar: cal,
                              selectedIndex: selectedBucketIndex,
                            ),
                          ),
                        ),

                      SliverToBoxAdapter(
                        child: SizedBox(height: _bottomScrollInset(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(ExpenseProvider ep, String gid, int index) {
    try {
      final cat = ep.categories.firstWhere((c) => c.gid == gid);
      final int hex = cat.color;
      if (hex != 0) {
        return Color(hex);
      }
    } catch (_) {}
    const palette = [
      Color(0xFF7C4DFF),
      Color(0xFF26C6DA),
      Color(0xFFFF7043),
      Color(0xFF66BB6A),
      Color(0xFFFFC107),
      Color(0xFF29B6F6),
      Color(0xFFE57373),
      Color(0xFF8D6E63),
      Color(0xFFAB47BC),
      Color(0xFF9CCC65),
    ];
    return palette[index % palette.length];
  }
}

/// ======================= UI Pieces =========================

/// The period's total, full width: the number first, what it is under it
/// (like Home's total tiles).
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = context.textOnStrong;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkText(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          InkText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: fg.withValues(alpha: .75)),
          ),
        ],
      ),
    );
  }
}

/// "At a glance" (the owner, 2026-10-27, expenses only, whole periods: no
/// ranges): the period's total; two chips, against all of last month and
/// against the monthly average (the months before, all of each, on
/// average), each its percentage over what it means; then the daily
/// average, one chip in two parts, its percentage (against every day's
/// since the app's first) in the second.
class _GlanceSection extends StatelessWidget {
  const _GlanceSection({
    required this.total,
    required this.glance,
    required this.money,
  });

  /// The period's total (the card that was above the section).
  final Widget total;
  final StatsGlance glance;
  final String Function(int minor) money;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final g = glance;
    int? against(int? reference) =>
        reference == null ? null : percentAgainst(g.spent, reference);
    final perDay = g.overallPerDay == null
        ? null
        : percentAgainst(g.perDay, g.overallPerDay!);

    return FoldSection(
      id: 'stats.glance',
      title: l.statsAtAGlance,
      titleKey: _tipSection,
      initiallyOpen: true,
      children: [
        total,
        // One fixed height (the owner, 2026-10-28: cards don't grow with their
        // text): room for the change and the longest meaning either can
        // show, measured at their width.
        LayoutBuilder(
          builder: (context, box) =>
              SizedBox(
                height: _compareHeight(
                  context,
                  (box.maxWidth - kSectionRowGap) / 2 - 2 * _CompareChip.hPad,
                  [
                    l.statsMoreThanLastMonth,
                    l.statsLessThanLastMonth,
                    l.statsSameAsLastMonth,
                    l.statsVsLastMonth,
                    l.statsMoreThanAverage,
                    l.statsLessThanAverage,
                    l.statsSameAsAverage,
                    l.statsVsAverage,
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _CompareChip(
                        percent: against(g.lastTotal),
                        more: l.statsMoreThanLastMonth,
                        less: l.statsLessThanLastMonth,
                        same: l.statsSameAsLastMonth,
                        none: l.statsVsLastMonth,
                      ),
                    ),
                    const SizedBox(width: kSectionRowGap),
                    Expanded(
                      child: _CompareChip(
                        percent: against(g.average),
                        more: l.statsMoreThanAverage,
                        less: l.statsLessThanAverage,
                        same: l.statsSameAsAverage,
                        none: l.statsVsAverage,
                      ),
                    ),
                  ],
                ),
              ),
        ),
        _DailyChip(perDay: money(g.perDay), percent: perDay),
      ],
    );
  }
}

/// How tall [text] is in [style] at [width] (the reader's text size).
double _textHeight(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) => (TextPainter(
  text: TextSpan(
    text: text,
    style: DefaultTextStyle.of(context).style.merge(style),
  ),
  textDirection: Directionality.of(context),
  textScaler: MediaQuery.textScalerOf(context),
)..layout(maxWidth: math.max(1, width))).height;

/// The glance chips' fixed heights: their padding, the change's line and
/// the tallest of what can be under it ([meanings]), measured at the room
/// inside ([width]), so no wording, language or text size spills out (the
/// guess of two lines at 1.4 did, by a pixel or two).
double _compareHeight(
  BuildContext context,
  double width,
  List<String> meanings,
) {
  final change = math.max(
    _textHeight(context, '100', _Change.style, width),
    _textHeight(
      context,
      AppLocalizations.of(context)!.statsNotEnoughData,
      _Change.noneStyle,
      width,
    ),
  );
  final words = [
    for (final m in meanings)
      _textHeight(context, m, _CompareChip.wordStyle, width),
  ].reduce(math.max);
  return (2 * _CompareChip.vPad + change + 6 + words).ceilToDouble();
}

/// The daily average and its change (against every day's), one chip in
/// two parts.
class _DailyChip extends StatelessWidget {
  const _DailyChip({required this.perDay, required this.percent});
  final String perDay;
  final int? percent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // The second part's room: its padding and the change (or "not enough
      // data"), as wide as it shows.
      final p = percent;
      final room =
          box.maxWidth -
          kPartGap -
          36 -
          (p == null
              ? (TextPainter(
                  text: TextSpan(
                    text: AppLocalizations.of(context)!.statsNotEnoughData,
                    style: DefaultTextStyle.of(
                      context,
                    ).style.merge(_Change.noneStyle),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout()).width
              : _Change.size * .8 +
                    5 +
                    PercentText.widthOf(context, p.abs() * 10, _Change.style)) -
          28;
      final height =
          (24 +
                  _textHeight(context, perDay, _perDayStyle, room) +
                  4 +
                  _textHeight(
                    context,
                    AppLocalizations.of(context)!.statsDailyAverage,
                    _CompareChip.wordStyle,
                    room,
                  ))
              .ceilToDouble();
      return _parts(context, height);
    },
  );

  static const _perDayStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  Widget _parts(BuildContext context, double height) => SplitChip(
    height: height,
    parts: [
      Expanded(
        child: Container(
          color: context.raised,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkText(perDay, textAlign: TextAlign.center, style: _perDayStyle),
              const SizedBox(height: 4),
              InkText(
                AppLocalizations.of(context)!.statsDailyAverage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      Container(
        color: context.raisedBy(2),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        child: _Change(percent),
      ),
    ],
  );
}

/// Spent against something: its percentage (more, red; less, green; about
/// the same, ≈), and under it what it means ([more], [less], [same]); with
/// nothing to measure by, "Not enough data yet" over what it's against
/// ([none]) (the owner: no placeholders).
class _CompareChip extends StatelessWidget {
  const _CompareChip({
    required this.percent,
    required this.more,
    required this.less,
    required this.same,
    required this.none,
  });

  final int? percent;
  final String more, less, same, none;

  /// Its padding and the meaning's style (its height is measured by them).
  static const double hPad = 10, vPad = 12;
  static const wordStyle = TextStyle(fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final p = percent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: context.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Change(p),
          const SizedBox(height: 6),
          InkText(
            p == null
                ? none
                : p > 0
                ? more
                : p < 0
                ? less
                : same,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A change in percent: the owner's double arrow (up, red: more; down,
/// green: less) and the number with the percent icon; ≈ when it's about
/// the same; with nothing to measure by (null), says so.
class _Change extends StatelessWidget {
  const _Change(this.percent);
  final int? percent;

  static const double size = 17;

  /// The number's style, and the words' with nothing to measure by (the
  /// glance chips are sized by them).
  static const style = TextStyle(fontSize: size, fontWeight: FontWeight.w800);
  static const noneStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final p = percent;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final good = dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
    if (p == null) {
      return InkText(
        AppLocalizations.of(context)!.statsNotEnoughData,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    if (p == 0) {
      return InkText(
        '≈',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    final color = p > 0 ? kStrongRed : good;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        ImageIcon(
          p > 0 ? AppIcons.moreArrows : AppIcons.lessArrows,
          size: size * .8,
          color: color,
        ),
        const SizedBox(width: 5),
        PercentText(
          p.abs() * 10,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CategoryPieCardCompact extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int total;
  final void Function(int index) onTouch;
  final Color Function(String gid, int idx) colorOf;
  final String Function(String gid) nameOf;
  final ValueListenable<int> touchedIndex;

  /// Categories taken off the pie: their chips stay, greyed, their boxes
  /// empty; the rest share the pie (and the percentages) among themselves.
  final Set<String> off;

  /// A chip's box tapped: takes its category off the pie, or back on.
  final ValueChanged<String> onToggle;

  /// The lit part is a bubble held (its chip lights; the bubble doesn't
  /// glow), and a bubble held (its index) or let go (-1).

  const _CategoryPieCardCompact({
    required this.entries,
    required this.total,
    required this.onTouch,
    required this.colorOf,
    required this.nameOf,
    required this.touchedIndex,
    required this.off,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasData = total > 0 && entries.isNotEmpty;
    bool isOn(int i) => !off.contains(entries[i].key);
    // The slices: the categories still on the pie (a slice's index → its
    // entry's).
    final onPie = [
      for (var i = 0; i < entries.length; i++)
        if (isOn(i)) i,
    ];

    final parts = <CategoryPart>[
      for (var i = 0; i < entries.length; i++)
        (
          gid: entries[i].key,
          amount: entries[i].value,
          color: colorOf(entries[i].key, i),
        ),
    ];

    // Inside the card: every section's inset; the pie stands clear of the
    // legend below it.
    const pad = kSectionInset;

    // One decimal (0.6, 20.9), adding up to exactly 100: among the
    // categories on the pie. The layout goes by the shares as if all were
    // on (a box tapped doesn't shuffle the legend).
    final allTenths = shareTenths([for (final e in entries) e.value]);
    final onTenths = shareTenths([for (final i in onPie) entries[i].value]);
    final tenths = List<int?>.filled(entries.length, null);
    for (var k = 0; k < onPie.length; k++) {
      tenths[onPie[k]] = onTenths[k];
    }
    Widget legend() => CategoryLegend(
      gids: [for (final e in entries) e.key],
      tenths: tenths,
      layoutTenths: allTenths,
      colorOf: colorOf,
      nameOf: nameOf,
      off: off,
      onToggle: onToggle,
      touched: touchedIndex.value,
      onTouch: onTouch,
    );

    return FoldSection(
      id: 'stats.pie',
      title: AppLocalizations.of(context)!.statsByCategory,
      initiallyOpen: true,
      padding: const EdgeInsets.all(pad),
      child: Builder(
        builder: (context) => hasData
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The ring: each slice out as far as it's big.
                  RepaintBoundary(
                    child: ValueListenableBuilder<int>(
                      valueListenable: touchedIndex,
                      builder: (context, touched, _) => CategoryPie(
                        parts: [for (final i in onPie) parts[i]],
                        touched: onPie.indexOf(touched),
                        onTouch: (k) => onTouch(k >= 0 ? onPie[k] : -1),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSectionInset),
                  ValueListenableBuilder<int>(
                    valueListenable: touchedIndex,
                    builder: (context, _, _) => legend(),
                  ),
                ],
              )
            // Nothing in the period: the pie's empty round, "No data" in
            // it (so it still reads as a pie chart; the owner, 2026-10-25).
            : SizedBox(
                height: 2 * 128,
                child: Center(
                  child: Container(
                    width: 2 * 118,
                    height: 2 * 118,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: InkText(
                      AppLocalizations.of(context)!.noData,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final Map<DateTime, int> values;
  final AppCalendar calendar;
  final bool faDigits;

  /// The app's first day (days before it are faded).
  final DateTime? activeFrom;

  /// The period's expenses (the day preview's rows come from them), the
  /// day picked (heard by this card alone: a pick doesn't build the page
  /// again), and how a row shows and opens.
  final List<Map<String, dynamic>> entries;
  final ValueNotifier<DateTime?> picked;
  final String Function(String? gid) nameOf;
  final Color Function(String? gid) colorOf;
  final String Function(int amount) money;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _HeatmapCard({
    required this.from,
    required this.to,
    required this.values,
    required this.calendar,
    required this.faDigits,
    required this.entries,
    required this.picked,
    required this.nameOf,
    required this.colorOf,
    required this.money,
    required this.onOpen,
    this.activeFrom,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final first = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);

    return FoldSection(
      id: 'stats.heatmap',
      title: l.heatmapCalendar,
      initiallyOpen: true,
      padding: const EdgeInsets.all(kSectionInset),
      child: ValueListenableBuilder<DateTime?>(
        valueListenable: picked,
        builder: (context, day, _) {
          // A day of another period, or with nothing spent now: none.
          final shown =
              day != null &&
                  !day.isBefore(first) &&
                  !day.isAfter(last) &&
                  (values[day] ?? 0) > 0
              ? day
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JalaliAwareHeatmap(
                from: first,
                to: last,
                values: values,
                calendar: calendar,
                faDigits: faDigits,
                activeFrom: activeFrom,
                selected: shown,
                // The day picked tapped again: none.
                onPick: (d) => picked.value = d == shown ? null : d,
                cell: double.infinity, // fill the card width
                gap: 6.0,
                rowGap: 6.0,
                labelsGap: 14.0,
                numberScale: 0.38,
              ),
              const SizedBox(height: 14),
              _DayPreview(
                day: shown,
                // The day's own tone in the heatmap, for its total.
                tone: shown == null
                    ? null
                    : () {
                        final scheme = Theme.of(context).colorScheme;
                        final maxV = values.values.fold(0, math.max);
                        final b = heatBucket(values[shown] ?? 0, maxV);
                        return b == 0
                            ? scheme.surfaceContainerHighest
                            : heatBuckets(
                                scheme.primary,
                                Theme.of(context).brightness,
                              )[b - 1];
                      }(),
                entries: entries,
                nameOf: nameOf,
                colorOf: colorOf,
                money: money,
                onOpen: onOpen,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Under the heatmap (the owner, 2026-10-31): the day picked's expenses,
/// one row each (category, title, amount; the newest entered first, as in
/// History); a row tapped opens it in History. Nothing picked: one row's
/// height, saying to pick a day. More than [_maxRows]: a box that many
/// whole rows tall (it shows that it scrolls: [ScrollHint]), scrolling on
/// its own and handing the drag on to the page at its ends, as the
/// category chips do.
class _DayPreview extends StatelessWidget {
  const _DayPreview({
    required this.day,
    required this.tone,
    required this.entries,
    required this.nameOf,
    required this.colorOf,
    required this.money,
    required this.onOpen,
  });

  final DateTime? day;

  /// The day's color in the heatmap (its total's chip takes it).
  final Color? tone;
  final List<Map<String, dynamic>> entries;
  final String Function(String? gid) nameOf;
  final Color Function(String? gid) colorOf;
  final String Function(int amount) money;
  final ValueChanged<Map<String, dynamic>> onOpen;

  static const _maxRows = 4;
  static const _gap = 8.0, _padV = 8.0, _padH = 12.0;
  static const _titleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const _amountStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// A row's height when nothing in it wraps (the pill's, or a line's).
  static double _rowHeight(TextScaler scaler) =>
      2 * _padV +
      [
        28.0,
        scaler.scale(12.5) * 1.2 + 8,
        scaler.scale(14) * InkText.defaultHeight,
        scaler.scale(15) * 1.2,
      ].reduce(math.max);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowH = _rowHeight(MediaQuery.textScalerOf(context));
    final d = day;
    final rows = d == null
        ? const <Map<String, dynamic>>[]
        : (entries.where((e) {
            final t = (e['occurredAtUtc'] as DateTime).toLocal();
            return t.year == d.year && t.month == d.month && t.day == d.day;
          }).toList()..sort((a, b) {
            final c = (b['createdAtUtc'] as DateTime).compareTo(
              a['createdAtUtc'] as DateTime,
            );
            return c != 0
                ? c
                : (b['occurredAtUtc'] as DateTime).compareTo(
                    a['occurredAtUtc'] as DateTime,
                  );
          }));

    final Widget body;
    if (rows.isEmpty) {
      body = Container(
        height: rowH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: _padH),
        decoration: BoxDecoration(
          color: context.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkText(
          AppLocalizations.of(context)!.dayPreviewHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant.withValues(alpha: .7),
          ),
        ),
      );
    } else {
      Widget row(Map<String, dynamic> e) {
        final gid = e['categoryGid'] as String?;
        final color = colorOf(gid);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpen(e),
          child: Container(
            constraints: BoxConstraints(minHeight: rowH),
            padding: const EdgeInsets.symmetric(
              horizontal: _padH,
              vertical: _padV,
            ),
            decoration: BoxDecoration(
              color: context.raised,
              borderRadius: BorderRadius.circular(12),
            ),
            // The category as wide as its name, up to almost half the row
            // (a longer one takes a second line); the title what's left.
            child: LayoutBuilder(
              builder: (context, box) => Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * .45),
                    child: TilePill(
                      text: nameOf(gid),
                      background: color,
                      foreground: onColor(color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkText(
                      (e['title'] as String?)?.trim() ?? '',
                      style: _titleStyle.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkText(
                    money((e['amountMinor'] as int?) ?? 0),
                    style: _amountStyle.copyWith(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : _gap),
              child: row(rows[i]),
            ),
        ],
      );
      // On top, apart from the rows (it doesn't scroll with them): the
      // day's total, on the day's color in the heatmap (the owner,
      // 2026-10-31).
      final total = rows.fold<int>(
        0,
        (t, e) => t + ((e['amountMinor'] as int?) ?? 0),
      );
      final bg = tone ?? scheme.surfaceContainerHighest;
      // A row like the ones under it: its word in a pill on the day's color
      // in the heatmap (as a row's category), the amount at the end (the
      // owner, 2026-11-01).
      final totalChip = Container(
        constraints: BoxConstraints(minHeight: rowH),
        padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: _padV),
        decoration: BoxDecoration(
          color: context.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            TilePill(
              text: AppLocalizations.of(context)!.dayTotal,
              background: bg,
              foreground: onColor(bg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: InkText(
                  money(total),
                  style: _amountStyle.copyWith(color: scheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      );
      final box = rows.length <= _maxRows
          ? list
          : SizedBox(
              height: _maxRows * (rowH + _gap) - _gap,
              // Each day from its first row (and shown that it scrolls).
              child: HintedScroll(
                key: ValueKey(d),
                id: ScrollHint.dayPreview,
                // At its ends, the drag (and a fling's speed) goes on in the
                // page.
                builder: (context, scroll) => ScrollChain(
                  child: SingleChildScrollView(
                    controller: scroll,
                    // Its ends tell the page (a bounce would keep the drag).
                    physics: const ClampingScrollPhysics(),
                    child: list,
                  ),
                ),
              ),
            );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          totalChip,
          const SizedBox(height: _gap),
          box,
        ],
      );
    }
    return AnimatedSize(
      duration: kSectionAnim,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      // A day picked: the list brings it into view as it grows.
      child: KeepShown(trigger: d, gapBelow: _kSectionGap, child: body),
    );
  }
}

/// "All periods": every period's spending, one bar each (PeriodBarChart).
class _AllRangesCard extends StatelessWidget {
  const _AllRangesCard({
    required this.buckets,
    required this.calendar,
    required this.selectedIndex,
  });

  final List<_RangeBucket> buckets;
  final AppCalendar calendar;
  final int selectedIndex; // the period shown, or -1

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FoldSection(
      id: 'stats.allPeriods',
      title: l.overviewAllPeriods,
      initiallyOpen: true,
      padding: const EdgeInsets.all(kSectionInset),
      child: PeriodBarChart(
        values: [for (final b in buckets) b.total],
        labels: _periodLabels(context, buckets, calendar),
        selectedIndex: selectedIndex,
        color: Theme.of(context).colorScheme.primary,
        number: (m) => _digitsFor(context, shortMoney(m)),
        amount: (m) => _digitsFor(context, _moneyFull(m)),
      ),
    );
  }
}

/// One category's spending per period, the same chart under the add
/// sheet's category picker.
class _PerCategoryRangesCard extends StatelessWidget {
  const _PerCategoryRangesCard({
    required this.buckets,
    required this.categoryIds,
    required this.perCategorySeries,
    required this.colorOf,
    required this.selectedCategoryGid,
    required this.onSelectedChanged,
    required this.calendar,
    required this.selectedIndex,
  });

  final List<_RangeBucket> buckets;
  final List<String> categoryIds;
  final Map<String, List<int>> perCategorySeries;
  final Color Function(String gid, int idx) colorOf;
  final String? selectedCategoryGid;
  final ValueChanged<String?> onSelectedChanged;
  final AppCalendar calendar;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (categoryIds.isEmpty) return const SizedBox.shrink();
    final selected = selectedCategoryGid ?? categoryIds.first;
    final series =
        perCategorySeries[selected] ?? List<int>.filled(buckets.length, 0);
    if (series.every((v) => v == 0)) return const SizedBox.shrink();

    return FoldSection(
      id: 'stats.perCategory',
      title: AppLocalizations.of(context)!.categorySpendPerPeriod,
      initiallyOpen: true,
      padding: const EdgeInsets.all(kSectionInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The add sheet's category picker (the category's colors),
          // over the categories with spending here.
          CategoryPickerButton(
            key: ValueKey(categoryIds.join(',')),
            kind: TransactionKind.expense,
            initialCategoryGid: selected,
            only: categoryIds.toSet(),
            onChanged: onSelectedChanged,
          ),
          const SizedBox(height: kSectionInset),
          PeriodBarChart(
            values: series,
            labels: _periodLabels(context, buckets, calendar),
            selectedIndex: selectedIndex,
            color: colorOf(selected, 0),
            number: (m) => _digitsFor(context, shortMoney(m)),
            amount: (m) => _digitsFor(context, _moneyFull(m)),
          ),
        ],
      ),
    );
  }
}

/// An axis number: "50m", "12k" (minor units in).
/// An amount in full, with thousands separators (minor units in).
String _moneyFull(int n) {
  final major = n / 100;
  final intPart = major.floor();
  final decPart = (major - intPart) * 100;
  final digits = intPart.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromRight = digits.length - i;
    buf.write(digits[i]);
    if (fromRight > 1 && fromRight % 3 == 1) buf.write(',');
  }
  if (decPart > 0) {
    buf.write('.');
    buf.write(decPart.round().toString().padLeft(2, '0'));
  }
  return buf.toString();
}

/// [text] with the digits chosen in Settings.
String _digitsFor(BuildContext context, String text) =>
    faDigitsFor(isFaUi(context)) ? toFaDigits(text) : text;

/// yyyy/MM of each period's start, in the calendar chosen.
List<String> _periodLabels(
  BuildContext context,
  List<_RangeBucket> buckets,
  AppCalendar calendar,
) {
  String of(DateTime d) {
    if (calendar == AppCalendar.jalali) {
      final j = s.Jalali.fromDateTime(d);
      return '${j.year}/${j.month.toString().padLeft(2, '0')}';
    }
    return '${d.year}/${d.month.toString().padLeft(2, '0')}';
  }

  return [for (final b in buckets) _digitsFor(context, of(b.start))];
}

/// What the page's tip is about: a section's title.
final _tipSection = GlobalKey();

/// ======================= Value object =========================

/// The fewest periods a bar chart shows.
const int kMinPeriods = 5;

class _RangeBucket {
  final String key; // 'YYYY-MM-DD' of range start (Gregorian)
  final DateTime start; // range start (local)
  final DateTime end; // range end (local, 23:59:59)
  final int total;

  const _RangeBucket({
    required this.key,
    required this.start,
    required this.end,
    required this.total,
  });

  _RangeBucket copyWith({int? total}) => _RangeBucket(
    key: key,
    start: start,
    end: end,
    total: total ?? this.total,
  );
}

class _RangeStats {
  final List<_RangeBucket> buckets; // periods with data, oldest first
  final int selectedIndex; // bucket of the selected period, or -1
  final Map<String, List<int>> perCategory; // gid -> amounts per bucket

  const _RangeStats(this.buckets, this.selectedIndex, this.perCategory);
}

// lib/features/stats/daily_area_chart.dart
// Statistics' daily spending (the owner, 2026-11-01), in the bar chart's own
// design: its numbers, its ghost tracks cut at them, its rounded corner of
// lines, a chip under every day (today's tinted), five days in view at most
// and the rest scrolling, resting on whole days ([standFor], [SnapPhysics];
// a hint shows it scrolls, [ScrollHint.dailyChart]).
//  - Areas, their tops soft curves (level at each day, easing between),
//    days with nothing left out (gaps); one solid color each, layered: the
//    same day's average over every period (off at first), the period before,
//    the one shown in front. Where one passes behind another, its edge goes on
//    over what covers it, a thin line of tiny dots in its own color (the
//    owner's idea, 2026-11-02; see-through mixed colors, lines around areas,
//    a surface gap, flat tops and others were tried and dropped).
//  - The daily average over every day in use: a line straight across (off
//    at first).
//  - The scale fits the days in view (one big day elsewhere doesn't squash
//    them), easing to its new height as the view moves; with nothing in view
//    it stays where it is.
//  - Under it, a chip per series in its color, a tap turns it off and on
//    (kept: [SettingsProvider.dailyHidden]); one area stays on (a notice
//    says so), the average's line doesn't count.
//  - A touch shows that day's amounts above it (an information tip, fading
//    after the lift).

import 'dart:math' as math;
import 'dart:typed_data' show Float32List;
import 'dart:ui' show PointMode, lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/stats/period_bar_chart.dart'
    show
        niceStep,
        standFor,
        BarStand,
        SnapPhysics,
        kChipOver,
        kChartEdge,
        kChartSideStart,
        kChartSideEnd;
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/ui/hold_tip.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// The series, back to front (their ids are kept in prefs).
enum DailySeries {
  sameDay,
  previous,
  current,
  average;

  String get id => name;
}

class DailyAreaChart extends StatefulWidget {
  const DailyAreaChart({
    super.key,
    required this.current,
    required this.previous,
    required this.sameDay,
    required this.average,
    required this.today,
    required this.dayLabel,
    required this.dateOf,
    required this.number,
    required this.amount,
    required this.labels,
  });

  /// Spent each day of the period shown (null: a day still to come), and
  /// each day of the one before (null: before the first entry; empty: none
  /// of it was in use).
  final List<int?> current;
  final List<int?> previous;

  /// Each day's average over every period's same day (null: none in use).
  final List<int?> sameDay;

  /// Spent per day over every day in use (null: none).
  final int? average;

  /// Today's place in the period shown (-1: not in it): its chip is tinted,
  /// and the view opens on it.
  final int today;

  /// Day [i]'s number on its chip, and its date in the tip.
  final String Function(int i) dayLabel;
  final String Function(int i) dateOf;

  /// An axis number ("50k"), an amount in full.
  final String Function(int minor) number;
  final String Function(int minor) amount;

  /// The series' names.
  final Map<DailySeries, String> labels;

  @override
  State<DailyAreaChart> createState() => _DailyAreaChartState();
}

/// As the bar chart's: the plot's height and the room over it, from its
/// bottom to the bottom line and on to the day chips, the numbers' column
/// and its gap, how far the ghost tracks are cut at a number, the lines'
/// weights.
const double _kPlotH = 180, _kTop = 8, _kUnder = 9, _kToChips = 10;
const double _kNumbersW = 50, _kNumbersGap = 10, _kCut = 3;
const double _kGhostW = 2.4, _kAxisW = 3, _kChipH = 26;

/// The average's line (thin: the owner, 2026-11-01).
const double kChartLineW = 1.2;

/// The scale's easing to a new height, and a series fading in or out.
const Duration _kScaleTime = Duration(milliseconds: 420);
const Duration _kFadeTime = Duration(milliseconds: 240);

/// The charts' colors, each (light step, dark step): a warm coral, a second
/// hue where the theme's own is near it; yellow for the same day's average,
/// violet where the theme's is near it; a neutral for the daily average's
/// line (the owner, 2026-11-02: no grey area). White or black reads on their
/// chips ([onColor]).
const (Color, Color) _kCoral = (Color(0xFFE5574D), Color(0xFFF2665C));
const (Color, Color) _kSky = (Color(0xFF1E88E5), Color(0xFF2F9BEF));
const (Color, Color) _kNeutral = (Color(0xFF6B7079), Color(0xFFBFC3CA));
const (Color, Color) _kYellow = (Color(0xFF8F7F00), Color(0xFFE3C23A));
const (Color, Color) _kViolet = (Color(0xFF5F4FD0), Color(0xFFA99DF0));

/// How solid an area stands on the surface: more see-through drains the color
/// (orange at .42 read brown).
const double kChartFill = .8;

/// The tiny dots of an area's edge passing behind another: how far apart, and
/// their size.
const double _kDotGap = 2.2, _kDotSize = 1.1;

/// How far over the plot an amount is drawn: a day out of view far higher than
/// the scale runs up off it anyway, and at its true height (millions of pixels,
/// beside a very small day) just drawing the curve took seconds a frame.
const double _kHighest = -2 * _kPlotH;

/// Where a top's curve is between the points [p] and [q], [t] of the way along
/// it: level at each, easing between (the [Path.cubicTo] of [_AreasPainter],
/// worked out: this paints every frame the scale eases).
double _curveX(Offset p, Offset q, double t) =>
    p.dx + (q.dx - p.dx) * t * (1.5 - 1.5 * t + t * t);
double _curveY(Offset p, Offset q, double t) =>
    p.dy + (q.dy - p.dy) * t * t * (3 - 2 * t);

/// The height of the top along [points] at [x] (null: not over it).
double? _topAt(List<Offset> points, double x) {
  if (x < points.first.dx || x > points.last.dx) return null;
  var lo = 0, hi = points.length - 1;
  if (hi == 0) return points.first.dy;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (points[mid].dx <= x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final p = points[lo], q = points[hi];
  // The curve's place for this x: it always moves on, so a few steps find it.
  final u = (x - p.dx) / (q.dx - p.dx);
  var t = u;
  for (var k = 0; k < 3; k++) {
    t -= (t * (1.5 - 1.5 * t + t * t) - u) / (1.5 - 3 * t + 3 * t * t);
  }
  return _curveY(p, q, t);
}

/// The edges of [runs] drawn as tiny dots close together, nearly a thin line,
/// in [color], wherever one of [covers] stands over them: an area's edge where
/// it passes behind another. Worked out here, none of it through the canvas:
/// walking the paths (and clipping to the areas merged) cost too much for every
/// frame the scale eases.
void paintEdgeDots(
  Canvas canvas,
  List<List<Offset>> runs,
  List<List<Offset>> covers,
  Color color,
) {
  bool covered(double x, double y) {
    for (final cover in covers) {
      final top = _topAt(cover, x);
      if (top != null && y >= top) return true;
    }
    return false;
  }

  final dots = <double>[];
  for (final points in runs) {
    var prevX = points.first.dx, prevY = points.first.dy;
    var left = 0.0; // how far on the next dot is
    for (var k = 0; k + 1 < points.length; k++) {
      final p = points[k], q = points[k + 1];
      final length = (q.dx - p.dx).abs() + (q.dy - p.dy).abs();
      final steps = math.max(1, (length / (_kDotGap / 2)).ceil());
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final x = _curveX(p, q, t), y = _curveY(p, q, t);
        final dx = x - prevX, dy = y - prevY;
        final moved = math.sqrt(dx * dx + dy * dy);
        left -= moved;
        prevX = x;
        prevY = y;
        if (left > 0) continue;
        // Back to just where the next dot falls: evenly apart, on any slope.
        final back = -left / moved;
        final dotX = x - dx * back, dotY = y - dy * back;
        left += _kDotGap;
        if (dotY >= 0 && covered(dotX, dotY)) {
          dots
            ..add(dotX)
            ..add(dotY);
        }
      }
    }
  }
  if (dots.isEmpty) return;
  canvas.drawRawPoints(
    PointMode.points,
    Float32List.fromList(dots),
    Paint()
      ..color = color
      ..strokeWidth = _kDotSize
      ..strokeCap = StrokeCap.round,
  );
}

/// The charts' colors: the period shown in the theme's, readable on the
/// page; the rest above, passing over a hue within 40° of the theme's (a
/// grey theme passes none).
({Color current, Color previous, Color sameDay, Color average}) chartColors(
  BuildContext context,
) {
  final scheme = Theme.of(context).colorScheme;
  final hsv = HSVColor.fromColor(scheme.primary);
  final dark = scheme.brightness == Brightness.dark;
  Color step((Color, Color) c) => dark ? c.$2 : c.$1;
  bool near((Color, Color) c) {
    if (hsv.saturation < .25 || hsv.value < .2) return false;
    final d = (HSVColor.fromColor(step(c)).hue - hsv.hue).abs() % 360;
    return math.min(d, 360 - d) < 40;
  }

  return (
    current: context.primaryInk,
    previous: step(near(_kCoral) ? _kSky : _kCoral),
    sameDay: step(near(_kYellow) ? _kViolet : _kYellow),
    average: step(_kNeutral),
  );
}

class _DailyAreaChartState extends State<DailyAreaChart>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();

  /// The day touched (-1: none), heard by the guide and the tip alone; the
  /// last day touched (the tip fades out showing it); where the touch began
  /// (moving on is a scroll: the tip goes).
  final _touched = ValueNotifier<int>(-1);
  int _shown = -1;
  Offset? _downAt;

  /// The series turned off by their chips, and each one's fade (1: shown).
  late Set<String> _hidden;
  late final Map<DailySeries, AnimationController> _fades;

  /// The scale's top (an amount), easing from [_from] to [_to].
  late final AnimationController _scaleAnim;
  final _maxY = ValueNotifier<double>(1);
  double _from = 1, _to = 1;

  /// The layout last built (the days' places), and the viewport's width.
  BarStand? _stand;
  double _view = 0;

  /// What the scroll position was last set for; set once (before, the
  /// chart isn't shown: its scale isn't known yet).
  Object? _placedFor;
  bool _placedOnce = false;

  /// The axis' step at [maxY]: the step the scale is going to (its numbers
  /// come in as it reaches them), or, coming down, the step of where it is
  /// (never a crowd of them).
  double _stepAt(double maxY) =>
      maxY > _to + .5 ? niceStep(maxY.round()) : niceStep(_to.round());

  SettingsProvider? get _settings =>
      Provider.of<SettingsProvider?>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _hidden = {...?_settings?.dailyHidden};
    _fades = {
      for (final s in DailySeries.values)
        s: AnimationController(
          vsync: this,
          duration: _kFadeTime,
          value: _hidden.contains(s.id) ? 0 : 1,
        ),
    };
    _scaleAnim = AnimationController(vsync: this, duration: _kScaleTime)
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_scaleAnim.value);
        _maxY.value = lerpDouble(_from, _to, t)!;
      });
    _scroll.addListener(_retarget);
  }

  @override
  void didUpdateWidget(DailyAreaChart old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _retarget());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _touched.dispose();
    _maxY.dispose();
    _scaleAnim.dispose();
    for (final f in _fades.values) {
      f.dispose();
    }
    super.dispose();
  }

  int get _days => math.max(widget.current.length, widget.previous.length);

  bool _on(DailySeries s) => !_hidden.contains(s.id);

  double _xOf(int i) {
    final st = _stand!;
    return _kAxisW + st.lead + st.gap + i * st.pitch + st.barW / 2;
  }

  int? _valueOf(DailySeries s, int i) => switch (s) {
    DailySeries.current => i < widget.current.length ? widget.current[i] : null,
    DailySeries.previous =>
      i < widget.previous.length ? widget.previous[i] : null,
    DailySeries.sameDay => i < widget.sameDay.length ? widget.sameDay[i] : null,
    DailySeries.average => widget.average,
  };

  /// The highest of the series shown, on the days in view or on all of them.
  int _highest({required bool inView}) {
    final off = _scroll.hasClients ? _scroll.offset : 0.0;
    var maxV = 0;
    for (var i = 0; i < _days; i++) {
      if (inView) {
        final x = _xOf(i) - off;
        if (x < 0 || x > _view) continue;
      }
      for (final s in DailySeries.values) {
        if (!_on(s)) continue;
        final v = _valueOf(s, i);
        if (v != null && v > maxV) maxV = v;
      }
    }
    return maxV;
  }

  /// The scale for the days in view: the highest of the series shown on
  /// them, rounded up to the axis' step. Nothing in view: it stays where it is
  /// (it fell to almost nothing, every amount elsewhere then stood millions of
  /// pixels off, and that froze the app: the owner, 2026-11-03), or, set
  /// afresh ([fresh]: another period, a series toggled), fits the whole period.
  double _targetMax({bool fresh = false}) {
    if (_stand == null) return 1;
    var maxV = _highest(inView: true);
    if (maxV <= 0) {
      if (!fresh) return _to;
      maxV = _highest(inView: false);
      if (maxV <= 0) return niceStep(0);
    }
    final step = niceStep(maxV);
    return (maxV / step).ceil() * step;
  }

  /// Eases the scale to the days in view ([animate] false: at once).
  void _retarget({bool animate = true, bool fresh = false}) {
    if (!mounted) return;
    // Not placed yet: the jump to its place mustn't start an easing from the
    // placeholder scale, which the setting at once would then find already
    // on its way (every amount millions of pixels off, frame after frame).
    if (animate && !_placedOnce) return;
    final target = _targetMax(fresh: fresh);
    if (animate && target == _to) return;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _scaleAnim.stop();
      _from = _to = _maxY.value = target;
      return;
    }
    _from = _maxY.value;
    _to = target;
    _scaleAnim.forward(from: 0);
  }

  /// Where the view opens: today in the middle (rested on whole days), else
  /// the period's start.
  double _placeOffset() {
    final st = _stand!;
    final i = widget.today;
    if (i < 0) return 0;
    final snapped = ((_xOf(i) - _view / 2) / st.pitch).round() * st.pitch;
    return snapped.clamp(0.0, math.max(0.0, _kAxisW + st.width - _view));
  }

  /// To its place; the scale set for it at once the first time, easing after.
  void _place() {
    if (!mounted || !_scroll.hasClients || _stand == null) return;
    _scroll.jumpTo(_placeOffset());
    _retarget(animate: _placedOnce, fresh: true);
    if (!_placedOnce) setState(() => _placedOnce = true);
  }

  void _toggle(DailySeries s, List<DailySeries> present) {
    // One area stays on, always (the average's line alone is no chart, and
    // it doesn't count: the owner, 2026-11-01); trying says so.
    if (s != DailySeries.average &&
        _on(s) &&
        !present.any((p) => p != s && p != DailySeries.average && _on(p))) {
      showAppNotice(
        context,
        AppLocalizations.of(context)!.chartKeepOne,
        kind: NoticeKind.failure,
      );
      return;
    }
    setState(() {
      if (!_hidden.remove(s.id)) _hidden.add(s.id);
    });
    final f = _fades[s]!;
    _on(s) ? f.forward() : f.reverse();
    _settings?.setDailyHidden(_hidden);
    _retarget(fresh: true);
  }

  void _lift() => _touched.value = -1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    final ghost = (small?.color ?? scheme.onSurfaceVariant).withValues(
      alpha: .4,
    );
    final palette = chartColors(context);
    final colors = {
      DailySeries.current: palette.current,
      DailySeries.previous: palette.previous,
      DailySeries.sameDay: palette.sameDay,
      DailySeries.average: palette.average,
    };
    final n = _days;
    final bottom = _kTop + _kPlotH;
    final bottomLineY = (bottom + _kUnder).floorToDouble() + _kAxisW / 2;
    final chipsTop = bottomLineY + _kAxisW / 2 + _kToChips;
    final contentH = chipsTop + _kChipH;
    double yOf(double v) => _kTop + _kPlotH * (1 - v / _maxY.value);
    final fades = Listenable.merge([_maxY, ..._fades.values]);

    // Which series have anything to show.
    final hasSameDay = widget.sameDay.any((v) => v != null);
    final hasPrevious = widget.previous.any((v) => v != null);
    final present = [
      DailySeries.current,
      if (hasPrevious) DailySeries.previous,
      if (hasSameDay) DailySeries.sameDay,
      if (widget.average != null) DailySeries.average,
    ];
    final chips = [
      DailySeries.current,
      DailySeries.previous,
      DailySeries.sameDay,
      if (widget.average != null) DailySeries.average,
    ];
    // No area on (the only one on has nothing now): this period.
    if (!present.any((p) => p != DailySeries.average && _on(p))) {
      _hidden.remove(DailySeries.current.id);
      _fades[DailySeries.current]!.value = 1;
    }

    Widget numbers() => ValueListenableBuilder<double>(
      valueListenable: _maxY,
      builder: (context, maxY, _) {
        final step = _stepAt(maxY);
        return SizedBox(
          width: _kNumbersW,
          child: Stack(
            children: [
              for (var k = 0; k * step <= maxY * 1.001; k++)
                Positioned(
                  top: yOf(k * step) - 8,
                  left: 0,
                  right: 0,
                  height: 16,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InkText(
                      widget.number((k * step).round()),
                      style: small,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    Widget legend() {
      Widget chip(DailySeries s) {
        // Too little data for it: greyed, and a tap says why.
        final none =
            (s == DailySeries.sameDay && !hasSameDay) ||
            (s == DailySeries.previous && !hasPrevious);
        final on = _on(s) && !none;
        final color = colors[s]!;
        return Expanded(
          child: Semantics(
            button: true,
            toggled: on,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => none
                  ? showAppNotice(
                      context,
                      AppLocalizations.of(context)!.statsNotEnoughData,
                      kind: NoticeKind.failure,
                    )
                  : _toggle(s, present),
              child: AnimatedContainer(
                key: ValueKey(s),
                duration: _kFadeTime,
                constraints: const BoxConstraints(minHeight: 34),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: on
                      ? color
                      : none
                      ? context.raisedBy(.35)
                      : context.raised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkText(
                  widget.labels[s]!,
                  textAlign: TextAlign.center,
                  style: small?.copyWith(
                    color: on
                        ? onColor(color)
                        : none
                        ? scheme.onSurfaceVariant.withValues(alpha: .5)
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Two a row, one height a row (a long word on two lines).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < chips.length; r += 2) ...[
            if (r > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  chip(chips[r]),
                  if (r + 1 < chips.length) ...[
                    const SizedBox(width: 8),
                    chip(chips[r + 1]),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room round it as the bar chart's (the bottom line ran too near
        // the screen's edge: the owner, 2026-11-01).
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kChartSideStart,
            kChartEdge,
            kChartSideEnd,
            kChartEdge,
          ),
          child: Directionality(
            // The chart reads left to right (as the bar chart).
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: contentH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  numbers(),
                  const SizedBox(width: _kNumbersGap),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _view = box.maxWidth;
                        final st = _stand = standFor(n, box.maxWidth - _kAxisW);
                        final placed = (
                          n,
                          box.maxWidth,
                          widget.today,
                          widget.dateOf(0),
                        );
                        if (_placedFor != placed) {
                          _placedFor = placed;
                          // Another period: in place in the frame that shows
                          // it (a frame later, it jumped: the owner).
                          if (_placedOnce && _scroll.hasClients) {
                            final p = _scroll.position;
                            p.correctPixels(_placeOffset());
                            p.context.storageContext
                                .findRenderObject()
                                ?.markNeedsPaint();
                          }
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _place(),
                          );
                        }
                        final chipW = st.barW + 2 * kChipOver;
                        int dayAt(double x) =>
                            ((x - _xOf(0)) / st.pitch).round().clamp(0, n - 1);
                        final content = SizedBox(
                          width: _kAxisW + st.width,
                          height: contentH,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) {
                              _downAt = e.localPosition;
                              _touched.value = _shown = dayAt(
                                e.localPosition.dx,
                              );
                            },
                            // Moving on is a scroll (of the chart or the
                            // page): the tip goes.
                            onPointerMove: (e) {
                              final from = _downAt;
                              if (from != null &&
                                  (e.localPosition - from).distance > 12) {
                                _downAt = null;
                                _lift();
                              }
                            },
                            onPointerUp: (_) => _lift(),
                            onPointerCancel: (_) => _lift(),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _AreasPainter(
                                        repaint: fades,
                                        series: {
                                          for (final s in DailySeries.values)
                                            if (s != DailySeries.average)
                                              s: [
                                                for (var i = 0; i < n; i++)
                                                  _valueOf(s, i),
                                              ],
                                        },
                                        average: widget.average,
                                        fades: _fades,
                                        xOf: _xOf,
                                        maxY: _maxY,
                                        stepAt: _stepAt,
                                        stand: st,
                                        days: n,
                                        bottom: bottom,
                                        ghost: ghost,
                                        ready: _placedOnce,
                                        surface: context.surfaceHere,
                                        colors: colors,
                                      ),
                                    ),
                                  ),
                                ),
                                for (var i = 0; i < n; i++)
                                  Positioned(
                                    left: _xOf(i) - chipW / 2,
                                    width: chipW,
                                    top: chipsTop,
                                    height: _kChipH,
                                    child: ChartDayChip(
                                      text: widget.dayLabel(i),
                                      today: i == widget.today,
                                      color: colors[DailySeries.current]!,
                                    ),
                                  ),
                                // The day touched: a guide and dots on its
                                // series.
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _GuidePainter(
                                        touched: _touched,
                                        values: [
                                          for (final s in DailySeries.values)
                                            if (_on(s))
                                              (
                                                colors[s]!,
                                                (int i) => _valueOf(s, i),
                                              ),
                                        ],
                                        xOf: _xOf,
                                        maxY: _maxY,
                                        bottom: bottom,
                                        guide: scheme.onSurface.withValues(
                                          alpha: .5,
                                        ),
                                        ring: context.surfaceHere,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // More days than in view: it shows that it
                            // scrolls.
                            ScrollHint(
                              id: ScrollHint.dailyChart,
                              controller: _scroll,
                              child: ClipRect(
                                clipper: const _InsideAxis(),
                                child: SingleChildScrollView(
                                  controller: _scroll,
                                  scrollDirection: Axis.horizontal,
                                  physics: SnapPhysics(st.pitch),
                                  // Shown once its scale is set (one frame).
                                  child: Opacity(
                                    opacity: _placedOnce ? 1 : 0,
                                    child: content,
                                  ),
                                ),
                              ),
                            ),
                            // The left and bottom lines stay put.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: ChartAxisPainter(
                                    color: ghost,
                                    bottom: bottomLineY,
                                  ),
                                ),
                              ),
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: _touched,
                              builder: (context, i, _) {
                                final at = _shown;
                                if (at < 0 || at >= n) {
                                  return const SizedBox.shrink();
                                }
                                return AnimatedBuilder(
                                  animation: _scroll,
                                  builder: (context, _) => ChartTip(
                                    shown: i >= 0,
                                    x:
                                        _xOf(at) -
                                        (_scroll.hasClients
                                            ? _scroll.offset
                                            : 0),
                                    width: box.maxWidth,
                                    title: widget.dateOf(at),
                                    rows: [
                                      for (final s in [
                                        DailySeries.current,
                                        DailySeries.previous,
                                        DailySeries.sameDay,
                                        DailySeries.average,
                                      ])
                                        if (_on(s) && _valueOf(s, at) != null)
                                          (
                                            colors[s]!,
                                            widget.amount(_valueOf(s, at)!),
                                          ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        legend(),
      ],
    );
  }
}

/// The scrolled days' clip: from the left line's inner edge on, and as far
/// in as a day chip is wider than its day's room (the neighbors' chips
/// would show as slivers).
class _InsideAxis extends CustomClipper<Rect> {
  const _InsideAxis();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    _kAxisW + kChipOver,
    0,
    size.width - kChipOver,
    size.height,
  );

  @override
  bool shouldReclip(_InsideAxis old) => false;
}

/// A day's number in a chip, as the bar chart's date chips (today's tinted
/// in the chart's color).
class ChartDayChip extends StatelessWidget {
  const ChartDayChip({
    super.key,
    required this.text,
    required this.today,
    required this.color,
  });
  final String text;
  final bool today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: today ? color.withValues(alpha: .22) : context.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkText(
        text,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: today ? scheme.onSurface : null,
          fontWeight: today ? FontWeight.w700 : null,
        ),
      ),
    );
  }
}

/// The day's amounts, beside its guide, on the surface's own
/// tones (as the bar chart's tip), fading out after the lift.
class ChartTip extends StatelessWidget {
  const ChartTip({
    super.key,
    required this.shown,
    required this.x,
    required this.width,
    required this.title,
    required this.rows,
  });

  final bool shown;
  final double x, width;
  final String title;
  final List<(Color, String)> rows;

  static const double _w = 150;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );
    // Beside the guide, on the side with more room: its dots stay in sight.
    final beside = x < width / 2 ? x + 12 : x - 12 - _w;
    final left = beside.clamp(0.0, math.max(0.0, width - _w)).toDouble();
    return Positioned(
      left: left,
      width: _w,
      top: -8,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: shown ? kTipFadeIn : kTipFadeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.raisedBy(3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkText(title, textAlign: TextAlign.center, style: style),
                for (final (color, text) in rows)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkText(
                          text,
                          textAlign: TextAlign.end,
                          style: style,
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

/// The ghost tracks (cut at the numbers' levels, hidden where an area
/// stands), the areas back to front, each one see-through color, then the
/// average's line across.
class _AreasPainter extends CustomPainter {
  _AreasPainter({
    required Listenable repaint,
    required this.series,
    required this.average,
    required this.fades,
    required this.xOf,
    required this.maxY,
    required this.stepAt,
    required this.stand,
    required this.days,
    required this.bottom,
    required this.ghost,
    required this.ready,
    required this.surface,
    required this.colors,
  }) : super(repaint: repaint);

  final Map<DailySeries, List<int?>> series;
  final int? average;
  final Map<DailySeries, AnimationController> fades;
  final double Function(int) xOf;
  final ValueNotifier<double> maxY;
  final double Function(double maxY) stepAt;
  final BarStand stand;
  final int days;
  final double bottom;
  final Color ghost;
  final Color surface;

  /// The scale is known (before, the top is a placeholder, every amount
  /// millions of pixels off, and walking along such a curve froze the app; the
  /// chart isn't showing yet anyway).
  final bool ready;

  final Map<DailySeries, Color> colors;

  double _y(num v) =>
      math.max(_kHighest, _kTop + _kPlotH * (1 - v / maxY.value));

  /// [values]' days with anything (nothing, or no data: a gap; the owner,
  /// 2026-11-01), each run of them one area down to the bottom, its top a
  /// soft curve: level at every day's point, easing between them, so a
  /// rise or a fall is never a peak (the owner: softer ups and downs). A
  /// run next to a day with nothing eases down to the bottom halfway to
  /// it; at the period's ends, by the first entry, or before days still to
  /// come, it stops straight down (a day alone there eases down both ways: a
  /// straight line both ways would be no area at all).
  List<Path> _areas(List<int?> values) => [
    for (final points in _runs(values))
      _addEdge(
          Path()
            ..moveTo(points.first.dx, bottom)
            ..lineTo(points.first.dx, points.first.dy),
          points,
        )
        ..lineTo(points.last.dx, bottom)
        ..close(),
  ];

  /// [values]' runs of days with something, each its points along the top.
  List<List<Offset>> _runs(List<int?> values) {
    final out = <List<Offset>>[];
    final half = stand.pitch / 2;
    bool zeroAt(int k) => k >= 0 && k < values.length && values[k] == 0;
    var i = 0;
    while (i < values.length) {
      final v = values[i];
      if (v == null || v <= 0) {
        i++;
        continue;
      }
      // A run of days with something, [i] to [end].
      var end = i;
      while (end + 1 < values.length && (values[end + 1] ?? 0) > 0) {
        end++;
      }
      final alone = i == end;
      out.add([
        if (alone || zeroAt(i - 1)) Offset(xOf(i) - half, bottom),
        for (var k = i; k <= end; k++) Offset(xOf(k), _y(values[k]!)),
        if (alone || zeroAt(end + 1)) Offset(xOf(end) + half, bottom),
      ]);
      i = end + 1;
    }
    return out;
  }

  /// The soft curve along [points], added to [path], already at the first.
  Path _addEdge(Path path, List<Offset> points) {
    for (var k = 0; k + 1 < points.length; k++) {
      final p = points[k], q = points[k + 1];
      final h = (q.dx - p.dx) / 2;
      path.cubicTo(p.dx + h, p.dy, q.dx - h, q.dy, q.dx, q.dy);
    }
    return path;
  }

  /// Solid, back to front; then each one's edge, in dots, on whatever in front
  /// of it covers it.
  void _paintAreas(
    Canvas canvas,
    List<(DailySeries, double, List<Path>)> shown,
  ) {
    for (final (s, fade, areas) in shown) {
      final fill = Paint()
        ..color = Color.alphaBlend(
          colors[s]!.withValues(alpha: kChartFill),
          surface,
        ).withValues(alpha: fade);
      for (final area in areas) {
        canvas.drawPath(area, fill);
      }
    }
    for (var k = 0; k + 1 < shown.length; k++) {
      final (s, fade, _) = shown[k];
      paintEdgeDots(canvas, _runs(series[s]!), [
        for (final (front, _, _) in shown.sublist(k + 1))
          ..._runs(series[front]!),
      ], colors[s]!.withValues(alpha: fade));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!ready) return;
    // Nothing over the plot's top (a day out of view higher than the scale
    // runs up off it).
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, bottom + 1));
    final shown = <(DailySeries, double, List<Path>)>[
      for (final s in [
        DailySeries.sameDay,
        DailySeries.previous,
        DailySeries.current,
      ])
        if (fades[s]!.value > 0.01) (s, fades[s]!.value, _areas(series[s]!)),
    ];

    // Behind the areas: the ghost tracks, cut at the numbers' levels, each
    // down to the highest area on its day. Worked out, not clipped by merging
    // the areas' paths: this paints every frame of the scale's easing, and
    // merging paths lagged (the owner, 2026-11-01: scrolling).
    final step = stepAt(maxY.value);
    final cuts = [
      for (var k = 1; k * step <= maxY.value * 1.001; k++) _y(k * step),
    ]..sort();
    final track = Paint()
      ..color = ghost
      ..strokeWidth = _kGhostW
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < days; i++) {
      final x = xOf(i);
      var end = bottom;
      for (final (s, _, _) in shown) {
        final values = series[s]!;
        final v = i < values.length ? values[i] : null;
        if (v != null && v > 0) end = math.min(end, _y(v));
      }
      var from = _kTop;
      for (final y in cuts) {
        if (from >= end) break;
        final to = math.min(y - _kCut, end);
        if (to - from > 2) {
          canvas.drawLine(Offset(x, from + 1), Offset(x, to - 1), track);
        }
        from = y + _kCut;
      }
      if (end - from > 2) {
        canvas.drawLine(Offset(x, from + 1), Offset(x, end), track);
      }
    }

    _paintAreas(canvas, shown);

    // The daily average: a line straight across.
    final avg = average;
    final fade = fades[DailySeries.average]!.value;
    if (avg != null && avg > 0 && fade > 0.01) {
      final y = _y(avg);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = colors[DailySeries.average]!.withValues(alpha: fade)
          ..strokeWidth = kChartLineW,
      );
    }
  }

  @override
  bool shouldRepaint(_AreasPainter old) =>
      old.series != series ||
      old.average != average ||
      old.stand != stand ||
      old.days != days ||
      old.ghost != ghost ||
      old.ready != ready ||
      old.colors != colors ||
      old.bottom != bottom ||
      old.xOf != xOf;
}

/// The touched day's guide and its dots on the series shown (each ringed in
/// the surface's color).
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.touched,
    required this.values,
    required this.xOf,
    required this.maxY,
    required this.bottom,
    required this.guide,
    required this.ring,
  }) : super(repaint: Listenable.merge([touched, maxY]));

  final ValueNotifier<int> touched;
  final List<(Color, int? Function(int))> values;
  final double Function(int) xOf;
  final ValueNotifier<double> maxY;
  final double bottom;
  final Color guide, ring;

  @override
  void paint(Canvas canvas, Size size) {
    final i = touched.value;
    if (i < 0) return;
    final x = xOf(i);
    canvas.drawLine(
      Offset(x, _kTop),
      Offset(x, bottom),
      Paint()
        ..color = guide
        ..strokeWidth = 1,
    );
    for (final (color, valueAt) in values) {
      final v = valueAt(i);
      if (v == null || v <= 0) continue; // no area there: no dot
      final y = _kTop + _kPlotH * (1 - v / maxY.value);
      if (y < 0) continue;
      final at = Offset(x, y);
      canvas.drawCircle(at, 6.5, Paint()..color = ring);
      canvas.drawCircle(at, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => true;
}

/// The left line and the bottom line, one weight, round-ended, the corner
/// rounded (as the bar chart's).
class ChartAxisPainter extends CustomPainter {
  ChartAxisPainter({required this.color, required this.bottom});
  final Color color;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    const w = _kAxisW, r = 10.0;
    const x = w / 2;
    canvas.drawPath(
      Path()
        ..moveTo(x, _kTop - 2)
        ..lineTo(x, bottom - r)
        ..quadraticBezierTo(x, bottom, x + r, bottom)
        ..lineTo(size.width - w / 2, bottom),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(ChartAxisPainter old) =>
      old.color != color || old.bottom != bottom;
}

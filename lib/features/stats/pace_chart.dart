// lib/features/stats/pace_chart.dart
// Statistics' spending pace (the owner, 2026-11-01): what's been spent so
// far in the period, day by day (a running total), against the same in the
// period before, the same days' averages over every period (off at first),
// and the daily average kept up every day (a thin line, straight: the same
// amount each day adds up evenly). The daily chart's data, added up.
//  - The whole period at once, its days evenly across (a running total
//    only rises: one big day is a step, it squashes nothing), as solid lines:
//    the period shown the heaviest; the axis runs from their lowest amount
//    to their highest, exactly, easing to a new fit. Its numbers and rounded corner of lines
//    are the daily chart's. No ghost tracks, no day chips (the owner: a touch
//    tells the day).
//  - Under it, a chip per series in its color; a tap turns it off and on
//    (one of the three stays on, the average's line doesn't count; kept:
//    [SettingsProvider.paceHidden]); the scale eases to what's shown.
//  - A touch shows that day's running totals.
// (A budget line was tried and dropped: Budget counts only the categories
// with a budget, this counts all spending.)

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/stats/daily_area_chart.dart'
    show ChartAxisPainter, ChartTip, chartColors, kChartLineW;
import 'package:openfinances/features/stats/period_bar_chart.dart'
    show niceStep, kChartEdge, kChartSideStart, kChartSideEnd;
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// The series (their ids are kept in prefs).
enum PaceSeries {
  sameDay,
  previous,
  current,
  average;

  String get id => name;
}

class PaceChart extends StatefulWidget {
  const PaceChart({
    super.key,
    required this.current,
    required this.previous,
    required this.sameDay,
    required this.average,
    required this.dateOf,
    required this.number,
    required this.amount,
    required this.labels,
  });

  /// Spent so far by each day of the period shown (null: a day still to
  /// come), and by each day of the one before (null: before the first entry;
  /// empty: none of it was in use).
  final List<int?> current;
  final List<int?> previous;

  /// The same days' averages over every period, added up (null: none in
  /// use).
  final List<int?> sameDay;

  /// Spent per day over every day in use (null: none).
  final int? average;

  /// Day [i]'s date in the tip.
  final String Function(int i) dateOf;

  /// An axis number ("50k"), an amount in full.
  final String Function(int minor) number;
  final String Function(int minor) amount;

  /// The series' names.
  final Map<PaceSeries, String> labels;

  @override
  State<PaceChart> createState() => _PaceChartState();
}

/// As the daily chart's: the plot's height and the room over it, from its
/// bottom to the bottom line, the numbers' column and its gap, the lines.
const double _kPlotH = 180, _kTop = 8, _kUnder = 9;
const double _kNumbersW = 50, _kNumbersGap = 10, _kAxisW = 3;

/// The first and last days' room from the left line and from the end.
const double _kEnds = 8;

/// The lines' weights: the others, and the period shown (it leads).
const double _kLineW = 1.2, _kCurrentW = 1.6;

const Duration _kScaleTime = Duration(milliseconds: 420);
const Duration _kFadeTime = Duration(milliseconds: 240);

/// The amounts at the plot's bottom and top.
typedef _Range = (double, double);

/// Where amount [v] stands on [range].
double _yOn(_Range range, num v) =>
    _kTop + _kPlotH * (1 - (v - range.$1) / (range.$2 - range.$1));

class _PaceChartState extends State<PaceChart> with TickerProviderStateMixin {
  final _touched = ValueNotifier<int>(-1);
  int _shown = -1;

  late Set<String> _hidden;
  late final Map<PaceSeries, AnimationController> _fades;

  late final AnimationController _scaleAnim;
  final _range = ValueNotifier<_Range>((0, 1));
  _Range _from = (0, 1), _to = (0, 1);
  bool _scaled = false;

  SettingsProvider? get _settings =>
      Provider.of<SettingsProvider?>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _hidden = {...?_settings?.paceHidden};
    // One area stays on, always.
    if (!_areas.any(_on)) _hidden.remove(PaceSeries.current.id);
    _fades = {
      for (final s in PaceSeries.values)
        s: AnimationController(
          vsync: this,
          duration: _kFadeTime,
          value: _hidden.contains(s.id) ? 0 : 1,
        ),
    };
    _scaleAnim = AnimationController(vsync: this, duration: _kScaleTime)
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_scaleAnim.value);
        _range.value = (
          lerpDouble(_from.$1, _to.$1, t)!,
          lerpDouble(_from.$2, _to.$2, t)!,
        );
      });
    _retarget(animate: false);
  }

  @override
  void didUpdateWidget(PaceChart old) {
    super.didUpdateWidget(old);
    _retarget();
  }

  @override
  void dispose() {
    _touched.dispose();
    _range.dispose();
    _scaleAnim.dispose();
    for (final f in _fades.values) {
      f.dispose();
    }
    super.dispose();
  }

  int get _days => math.max(widget.current.length, widget.previous.length);

  bool _on(PaceSeries s) => !_hidden.contains(s.id);

  /// The areas this period has (the line isn't one).
  List<PaceSeries> get _areas => [
    PaceSeries.current,
    if (widget.previous.any((v) => v != null)) PaceSeries.previous,
    if (widget.sameDay.any((v) => v != null)) PaceSeries.sameDay,
  ];

  int? _valueOf(PaceSeries s, int i) => switch (s) {
    PaceSeries.current => i < widget.current.length ? widget.current[i] : null,
    PaceSeries.previous =>
      i < widget.previous.length ? widget.previous[i] : null,
    PaceSeries.sameDay => i < widget.sameDay.length ? widget.sameDay[i] : null,
    PaceSeries.average =>
      widget.average == null ? null : widget.average! * (i + 1),
  };

  /// The lines shown, exactly: their lowest amount at the plot's bottom, their
  /// highest at its top (the owner, 2026-11-02: no number the lines don't
  /// reach). All one amount: it in the middle.
  _Range _targetRange() {
    int? low, high;
    for (final series in PaceSeries.values) {
      if (!_on(series)) continue;
      for (var i = 0; i < _days; i++) {
        final v = _valueOf(series, i);
        if (v == null) continue;
        if (low == null || v < low) low = v;
        if (high == null || v > high) high = v;
      }
    }
    if (low == null || high == null) return (0, 1);
    if (low == high) return (low - 1, high + 1);
    return (low.toDouble(), high.toDouble());
  }

  void _retarget({bool animate = true}) {
    final target = _targetRange();
    if (_scaled && target == _to) return;
    if (!animate || !_scaled) {
      _scaled = true;
      _scaleAnim.stop();
      _from = _to = _range.value = target;
      return;
    }
    _from = _range.value;
    _to = target;
    _scaleAnim.forward(from: 0);
  }

  /// The numbers for the range it's going to: its two ends, the lines' own
  /// amounts, and round ones between them, none crowding an end. They slide
  /// as the range eases; one still beyond the range waits.
  List<double> _axisNumbers() {
    final (low, high) = _to;
    final span = high - low;
    // All one amount (or nothing): just that.
    if (span <= 2) return [(low + high) / 2];
    final step = niceStep(span.round());
    // Room for a number's height from either end.
    final clear = span * 22 / _kPlotH;
    return [
      low,
      for (var k = (low / step).ceil(); k * step < high; k++)
        if (k * step - low >= clear && high - k * step >= clear) k * step,
      high,
    ];
  }

  void _toggle(PaceSeries s) {
    // One area stays on, always (the average's line alone is no chart, and
    // it doesn't count: the owner, 2026-11-01); trying says so.
    if (s != PaceSeries.average &&
        _on(s) &&
        !_areas.any((p) => p != s && _on(p))) {
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
    _settings?.setPaceHidden(_hidden);
    _retarget(animate: !MediaQuery.disableAnimationsOf(context));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    final ghost = (small?.color ?? scheme.onSurfaceVariant).withValues(
      alpha: .4,
    );
    final palette = chartColors(context);
    final colors = {
      PaceSeries.current: palette.current,
      PaceSeries.previous: palette.previous,
      PaceSeries.sameDay: palette.sameDay,
      PaceSeries.average: palette.average,
    };
    final n = _days;
    if (n == 0) return const SizedBox.shrink();
    // No area on (the only one on has nothing now): this period.
    if (!_areas.any(_on)) {
      _hidden.remove(PaceSeries.current.id);
      _fades[PaceSeries.current]!.value = 1;
    }
    final bottomLineY =
        (_kTop + _kPlotH + _kUnder).floorToDouble() + _kAxisW / 2;
    double yOf(double v) => _yOn(_range.value, v);

    Widget numbers() => ValueListenableBuilder<_Range>(
      valueListenable: _range,
      builder: (context, range, _) {
        final span = range.$2 - range.$1;
        // Amounts very close together can shorten to the same text: just once.
        final said = <String>{};
        return SizedBox(
          width: _kNumbersW,
          child: Stack(
            children: [
              for (final v in _axisNumbers())
                if (v >= range.$1 - span * .001 &&
                    v <= range.$2 + span * .001 &&
                    said.add(widget.number(v.round())))
                  Positioned(
                    top: yOf(v) - 8,
                    left: 0,
                    right: 0,
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: InkText(widget.number(v.round()), style: small),
                    ),
                  ),
            ],
          ),
        );
      },
    );

    Widget legend() {
      Widget chip(PaceSeries s) {
        // Too little data for it: greyed, and a tap says why.
        final none = s != PaceSeries.average && !_areas.contains(s);
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
                  : _toggle(s),
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

      // Two a row, one height a row (a long word on two lines), as the
      // daily chart's.
      final present = [
        PaceSeries.current,
        PaceSeries.previous,
        PaceSeries.sameDay,
        if (widget.average != null) PaceSeries.average,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < present.length; r += 2) ...[
            if (r > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  chip(present[r]),
                  if (r + 1 < present.length) ...[
                    const SizedBox(width: 8),
                    chip(present[r + 1]),
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
              height: bottomLineY + _kAxisW / 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  numbers(),
                  const SizedBox(width: _kNumbersGap),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // The days evenly across, from inside the left
                        // line to the end.
                        const left = _kAxisW + _kEnds;
                        final w = box.maxWidth - left - _kEnds;
                        double xOf(int i) =>
                            left + (n <= 1 ? w / 2 : w * i / (n - 1));
                        int dayAt(double x) => n <= 1
                            ? 0
                            : ((x - left) / w * (n - 1)).round().clamp(
                                0,
                                n - 1,
                              );
                        void touch(Offset p) =>
                            _touched.value = _shown = dayAt(p.dx);
                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) => touch(e.localPosition),
                          onPointerMove: (e) => touch(e.localPosition),
                          onPointerUp: (_) => _touched.value = -1,
                          onPointerCancel: (_) => _touched.value = -1,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _PacePainter(
                                      repaint: Listenable.merge([
                                        _range,
                                        ..._fades.values,
                                      ]),
                                      current: widget.current,
                                      previous: widget.previous,
                                      sameDay: widget.sameDay,
                                      average: widget.average,
                                      days: n,
                                      fades: _fades,
                                      xOf: xOf,
                                      width: box.maxWidth,
                                      range: _range,
                                      colors: colors,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _GuidePainter(
                                      touched: _touched,
                                      range: _range,
                                      xOf: xOf,
                                      values: [
                                        for (final s in PaceSeries.values)
                                          if (_on(s))
                                            (
                                              colors[s]!,
                                              (int i) => _valueOf(s, i),
                                            ),
                                      ],
                                      guide: scheme.onSurface.withValues(
                                        alpha: .5,
                                      ),
                                      ring: context.surfaceHere,
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
                                  return ChartTip(
                                    shown: i >= 0,
                                    x: xOf(at),
                                    width: box.maxWidth,
                                    title: widget.dateOf(at),
                                    rows: [
                                      for (final s in [
                                        PaceSeries.current,
                                        PaceSeries.previous,
                                        PaceSeries.sameDay,
                                        PaceSeries.average,
                                      ])
                                        if (_on(s) && _valueOf(s, at) != null)
                                          (
                                            colors[s]!,
                                            widget.amount(_valueOf(s, at)!),
                                          ),
                                    ],
                                  );
                                },
                              ),
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
                            ],
                          ),
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

/// The running totals' areas, one see-through color each, the period
/// before behind the one shown, then the daily average kept up: a thin line
/// over them.
class _PacePainter extends CustomPainter {
  _PacePainter({
    required Listenable repaint,
    required this.current,
    required this.previous,
    required this.sameDay,
    required this.average,
    required this.days,
    required this.fades,
    required this.xOf,
    required this.width,
    required this.range,
    required this.colors,
  }) : super(repaint: repaint);

  final List<int?> current;
  final List<int?> previous;
  final List<int?> sameDay;
  final int? average;
  final int days;
  final Map<PaceSeries, AnimationController> fades;
  final double Function(int) xOf;
  final double width;
  final ValueNotifier<_Range> range;
  final Map<PaceSeries, Color> colors;

  static const double _bottom = _kTop + _kPlotH;

  double _y(num v) => _yOn(range.value, v);

  /// [values]' runs of known days, each its points (it may start late: the
  /// first entry; an average may have too few days to go by in between).
  List<List<Offset>> _runs(List<int?> values) {
    final out = <List<Offset>>[];
    List<Offset>? run;
    for (final (i, v) in values.indexed) {
      if (v == null) {
        run = null;
      } else {
        if (run == null) out.add(run = []);
        run.add(Offset(xOf(i), _y(v)));
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // A heavy line on the bottom number keeps its whole width.
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, _bottom + _kCurrentW));
    // Lines, not areas (the owner, 2026-11-02: running totals run close, and
    // an area hid what was under it): the averages behind, the period shown
    // in front and the heaviest.
    void line(PaceSeries s, List<List<Offset>> runs, double width) {
      final fade = fades[s]!.value;
      if (fade <= .01) return;
      final color = colors[s]!.withValues(alpha: fade);
      for (final points in runs) {
        // One day so far (the first entry's): a dot.
        if (points.length == 1) {
          canvas.drawCircle(points.first, 1.5 * width, Paint()..color = color);
          continue;
        }
        canvas.drawPath(
          Path()..addPolygon(points, false),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    final avg = average;
    if (avg != null && avg > 0) {
      line(PaceSeries.average, [
        [Offset(xOf(0), _y(avg)), Offset(xOf(days - 1), _y(avg * days))],
      ], kChartLineW);
    }
    line(PaceSeries.sameDay, _runs(sameDay), _kLineW);
    line(PaceSeries.previous, _runs(previous), _kLineW);
    line(PaceSeries.current, _runs(current), _kCurrentW);
  }

  @override
  bool shouldRepaint(_PacePainter old) =>
      old.current != current ||
      old.previous != previous ||
      old.sameDay != sameDay ||
      old.average != average ||
      old.days != days ||
      old.width != width ||
      old.colors != colors;
}

/// The touched day's guide and its dots on the series shown, ringed in
/// the surface's color.
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.touched,
    required this.range,
    required this.xOf,
    required this.values,
    required this.guide,
    required this.ring,
  }) : super(repaint: Listenable.merge([touched, range]));

  final ValueNotifier<int> touched;
  final ValueNotifier<_Range> range;
  final double Function(int) xOf;
  final List<(Color, int? Function(int))> values;
  final Color guide, ring;

  @override
  void paint(Canvas canvas, Size size) {
    final i = touched.value;
    if (i < 0) return;
    final x = xOf(i);
    canvas.drawLine(
      Offset(x, _kTop),
      Offset(x, _kTop + _kPlotH),
      Paint()
        ..color = guide
        ..strokeWidth = 1,
    );
    for (final (color, valueAt) in values) {
      final v = valueAt(i);
      if (v == null) continue;
      final at = Offset(x, _yOn(range.value, v));
      canvas.drawCircle(at, 6.5, Paint()..color = ring);
      canvas.drawCircle(at, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => true;
}

// lib/features/stats/period_bar_chart.dart
// Statistics' per-period bar chart: ONE chart for both of its uses (all
// periods, and one category per period; the owner, 2026-10-28: the same UI).
//
//  - The bars stand with ONE gap between each other, from the left line and
//    from the end (the owner, 2026-10-28: the look of five bars, any few);
//    the gap is never under [_kMinGap], so more bars than fit scroll. Under
//    each, its date in a chip of its own (the period shown tinted).
//  - Behind them, each period's FAINT line from the top to the bottom, broken
//    only where the axis numbers sit; a bar stands on its line with no gap
//    (the lines are background). A period with nothing is just the line and
//    its chip.
//  - The left and bottom lines one weight, a little thicker than those,
//    round-ended, the corner rounded; the bottom one a little under the bars.
//  - A touch on a bar shows its amount, on the surface tones (dark in the
//    dark theme, light in the light).
// Drawn here, not by fl_chart: the lines, cuts and chips share one set of
// coordinates, which a chart library doesn't give.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/hold_tip.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// The bar's corner; its width and the gaps stay between these (a narrow
/// phone shows fewer bars, a wide one stops at the maximum and centers).
const double _kBarR = 4;
const double _kBarMin = 20, _kBarIdeal = 24, _kBarMax = 40;
const double _kGapMin = 12, _kGapMax = 80;

/// How many bars the viewport shows without scrolling, at most.
const int kVisibleBars = 5;

/// The bars' height; the room above them for the top number and a tooltip.
const double _kPlotH = 207, _kTop = 8;

/// From the bars' bottom to the bottom line (the owner, 2026-10-28: a bit
/// more), and from the line to the date chips.
const double _kUnder = 9, _kToChips = 10;

/// The axis numbers' column (right-aligned against the chart) and its gap
/// to the plot.
const double _kNumbersW = 50, _kNumbersGap = 10;

/// How far the axis numbers' lines are cut either side of a number.
const double _kCut = 3;

/// Room round the whole chart (the owner, 2026-10-28: more): above and
/// below, and at the sides (the end more, the numbers' own slack is the
/// start's).
const double kChartEdge = 24, kChartSideStart = 8, kChartSideEnd = 16;

/// The ghost lines' thickness, and the left / bottom lines' (thicker, one
/// for both).
const double _kGhostW = 2.4, _kAxisW = 3;

/// How far a date chip sticks out past its bar on each side.
const double kChipOver = 3;

/// A nice step for the axis: about four of them to reach [maxV].
double niceStep(int maxV) {
  if (maxV <= 0) return 1;
  final raw = maxV / 4.0;
  final pow10 = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final c in const [1, 2, 5, 10]) {
    if (raw <= c * pow10) return c * pow10;
  }
  return pow10 * 10;
}

/// How [n] bars stand in a viewport [view] wide.
///  - [visible]: how many fit side by side, at most [kVisibleBars]: fewer on a
///    narrow screen, where the gap would drop under [_kGapMin].
///  - Those share the viewport evenly: ONE gap between bars, before the first
///    and after the last, one bar width. The gap is never over [_kGapMax]
///    (the bars grow to [_kBarMax] instead, then the group is centered).
///  - [n] under [visible]: just those, the same way; [n] over it: the same
///    bar and gap, scrolling.
/// [lead] centers a group narrower than the viewport.
typedef BarStand = ({
  int visible,
  double barW,
  double gap,
  double pitch,
  double width,
  double lead,
});

BarStand standFor(int n, double view) {
  var k = kVisibleBars;
  while (k > 3 && (view - k * _kBarIdeal) / (k + 1) < _kGapMin) {
    k--;
  }
  // The bar and gap for [m] bars filling the viewport, within the limits.
  (double, double) fit(int m) {
    var barW = _kBarIdeal;
    var gap = (view - m * barW) / (m + 1);
    if (gap > _kGapMax) {
      gap = _kGapMax;
      barW = math.min(_kBarMax, (view - (m + 1) * gap) / m);
    } else if (gap < _kGapMin) {
      gap = _kGapMin;
      barW = math.max(_kBarMin, (view - (m + 1) * gap) / m);
    }
    return (barW, gap);
  }

  final (barW, gap) = fit(math.max(1, math.min(n, k)));
  final count = math.max(n, 1);
  final content = count * barW + (count + 1) * gap;
  // More bars than [k] that still fit (a wide screen) are centered too.
  final width = math.max(view, content);
  return (
    visible: k,
    barW: barW,
    gap: gap,
    pitch: barW + gap,
    width: width,
    lead: (width - content) / 2,
  );
}

/// Scrolling that rests only on whole bars: a multiple of [pitch], so the
/// left edge never shows a half bar or a half date chip (the owner,
/// 2026-10-28). The viewport holds a whole number of pitches (the bars were
/// laid out to fill it), so every rest shows only whole bars.
/// (The daily chart's days rest the same way.)
class SnapPhysics extends ScrollPhysics {
  const SnapPhysics(this.pitch, {super.parent});
  final double pitch;

  @override
  SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      SnapPhysics(pitch, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tol = toleranceFor(position);
    // Past an end: the usual way back.
    if (position.pixels < position.minScrollExtent ||
        position.pixels > position.maxScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }
    final toward = position.pixels + velocity * 0.25;
    final target = ((toward / pitch).round() * pitch).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tol.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tol,
    );
  }
}

class PeriodBarChart extends StatefulWidget {
  const PeriodBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.selectedIndex,
    required this.color,
    required this.number,
    required this.amount,
  });

  /// Spent per period, oldest first (minor units).
  final List<int> values;

  /// Each period's date (digits as chosen).
  final List<String> labels;

  /// The period shown on the page (-1: none).
  final int selectedIndex;

  /// The bars' color.
  final Color color;

  /// An axis number, short ("50m"), and an amount in full, for [minor].
  final String Function(int minor) number, amount;

  @override
  State<PeriodBarChart> createState() => _PeriodBarChartState();
}

class _PeriodBarChartState extends State<PeriodBarChart> {
  final _scroll = ScrollController();

  /// The bar held (-1: none), and the bar whose amount shows: the one held,
  /// then, after the lift, the one fading out. Heard by the tip alone: a
  /// touch doesn't build the chart again.
  final _touch = ValueNotifier<(int, int)>((-1, -1));

  void _press(int i) => _touch.value = (i, i);
  void _lift() => _touch.value = (-1, _touch.value.$2);

  /// What the scroll position was last set for (count, width, period shown).
  (int, double, int)? _placedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toSelected());
  }

  @override
  void didUpdateWidget(PeriodBarChart old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toSelected());
    }
  }

  /// Where the shown period's bar stands in the middle of a viewport [view]
  /// wide (none: the newest, at the end).
  double _selectedOffset(double view) {
    final st = standFor(widget.values.length, view - _kAxisW);
    final max = math.max(0.0, _kAxisW + st.width - view);
    final i = widget.selectedIndex;
    if (i < 0 || widget.values.isEmpty) return max;
    final target =
        _kAxisW + st.lead + st.gap + i * st.pitch + st.barW / 2 - view / 2;
    // On whole bars, like every other rest.
    final snapped = (target / st.pitch).round() * st.pitch;
    return snapped.clamp(0.0, max);
  }

  void _toSelected() {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_selectedOffset(_scroll.position.viewportDimension));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _touch.dispose();
    super.dispose();
  }

  double _width(BuildContext context, String text, TextStyle? style) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final n = w.values.length;
    final maxV = w.values.fold<int>(0, math.max);
    final step = niceStep(maxV);
    // Nothing anywhere: just the zero (a scale of one tick).
    final ticks = maxV <= 0 ? 0 : (maxV / step).ceil();
    final maxY = ticks == 0 ? 1.0 : ticks * step;
    double yOf(double v) => _kTop + _kPlotH * (1 - v / maxY);
    final tickYs = [for (var k = 0; k <= ticks; k++) yOf(k * step)];
    final tickTexts = [
      for (var k = 0; k <= ticks; k++) w.number((k * step).round()),
    ];

    final small = Theme.of(context).textTheme.bodySmall;
    // The date chips, upright: as long as the longest date.
    final chipStyle = small?.copyWith(fontSize: 12);
    final longest = w.labels
        .map((t) => _width(context, t, chipStyle))
        .fold(0.0, math.max);
    final chipH = longest + 18;

    // The bottom line's middle on a half of its weight, so it and the left
    // line (flush with the edge) cover whole pixels alike.
    final bottomLineY =
        (_kTop + _kPlotH + _kUnder).floorToDouble() + _kAxisW / 2;
    final contentH = bottomLineY + _kAxisW / 2 + _kToChips + chipH;
    final ghost =
        (Theme.of(context).textTheme.bodySmall?.color ??
                Theme.of(context).colorScheme.onSurfaceVariant)
            .withValues(alpha: .4);

    Widget numbers() => SizedBox(
      width: _kNumbersW,
      height: contentH,
      child: Stack(
        children: [
          for (var k = 0; k <= ticks; k++)
            Positioned(
              top: tickYs[k] - 8,
              left: 0,
              right: 0,
              height: 16,
              child: Align(
                alignment: Alignment.centerRight,
                child: InkText(tickTexts[k], style: small),
              ),
            ),
        ],
      ),
    );

    // On the surface's own tones (a step above the section): dark in the
    // dark theme, light in the light (the owner, 2026-10-28).
    Widget tooltip(int i, double centerX, bool held) {
      final top = yOf(w.values[i].toDouble());
      final box = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.raisedBy(3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkText(
          w.amount(w.values[i]),
          style: small?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
      // Above the bar, or inside it when it reaches too near the top; in
      // the viewport (the scrolled content is clipped), over its bar.
      final above = top >= 36;
      return AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) => Positioned(
          left: centerX - (_scroll.hasClients ? _scroll.offset : 0) - 80,
          width: 160,
          top: above ? top - 34 : top + 6,
          // Fading out slowly once the finger lifts (as every tip).
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: held ? 1 : 0,
                duration: held ? kTipFadeIn : kTipFadeOut,
                onEnd: () {
                  if (!held && mounted) _touch.value = (-1, -1);
                },
                child: box,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kChartSideStart,
        kChartEdge,
        kChartSideEnd,
        kChartEdge,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr, // the chart reads left to right
        child: SizedBox(
          height: contentH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              numbers(),
              const SizedBox(width: _kNumbersGap),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        // The gaps are measured from the left line's inner
                        // edge, so the first looks like the rest (the line
                        // is [_kAxisW] thick).
                        final st = standFor(n, box.maxWidth - _kAxisW);
                        // Put the scroll where it belongs once the sizes are
                        // known, and again whenever they change.
                        final placed = (n, box.maxWidth, w.selectedIndex);
                        if (_placedFor != placed) {
                          _placedFor = placed;
                          // Another period: in place in the frame that shows
                          // it (a frame later, it jumped: the owner).
                          if (_scroll.hasClients) {
                            final p = _scroll.position;
                            p.correctPixels(_selectedOffset(box.maxWidth));
                            p.context.storageContext
                                .findRenderObject()
                                ?.markNeedsPaint();
                          }
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _toSelected(),
                          );
                        }
                        double leftOf(int i) =>
                            _kAxisW + st.lead + st.gap + i * st.pitch;
                        final chipW = st.barW + 2 * kChipOver;
                        // Clipped at the left line's inner edge: the bar before
                        // the first one shown ends right there and would show
                        // under the line.
                        // Older periods out of view: it shows that it
                        // scrolls ([ScrollHint]).
                        return ScrollHint(
                          id: ScrollHint.periodChart,
                          controller: _scroll,
                          child: ClipRect(
                            clipper: const _InsideAxis(),
                            child: SingleChildScrollView(
                              controller: _scroll,
                              scrollDirection: Axis.horizontal,
                              physics: SnapPhysics(st.pitch),
                              child: SizedBox(
                                width: _kAxisW + st.width,
                                height: contentH,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _BarsPainter(
                                            values: w.values,
                                            first: _kAxisW + st.lead + st.gap,
                                            barW: st.barW,
                                            pitch: st.pitch,
                                            maxY: maxY,
                                            ticks: ticks,
                                            yOf: yOf,
                                            bottom: _kTop + _kPlotH,
                                            color: w.color,
                                            ghost: ghost,
                                          ),
                                        ),
                                      ),
                                    ),
                                    for (var i = 0; i < n; i++) ...[
                                      // The bar's touch: its amount, while held.
                                      Positioned(
                                        left: leftOf(i) - st.gap / 2,
                                        top: 0,
                                        width: st.pitch,
                                        height: _kTop + _kPlotH,
                                        child: Listener(
                                          behavior: HitTestBehavior.translucent,
                                          onPointerDown: (_) {
                                            if (w.values[i] > 0) _press(i);
                                          },
                                          onPointerUp: (_) => _lift(),
                                          onPointerCancel: (_) => _lift(),
                                        ),
                                      ),
                                      // Its date, in a chip of its own (a touch on it
                                      // shows its bar's amount too).
                                      Positioned(
                                        left: leftOf(i) + (st.barW - chipW) / 2,
                                        top:
                                            bottomLineY +
                                            _kAxisW / 2 +
                                            _kToChips,
                                        width: chipW,
                                        height: chipH,
                                        child: Listener(
                                          onPointerDown: (_) => _press(i),
                                          onPointerUp: (_) => _lift(),
                                          onPointerCancel: (_) => _lift(),
                                          child: _DateChip(
                                            text: w.labels[i],
                                            selected: i == w.selectedIndex,
                                            color: w.color,
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
                      },
                    ),
                    ValueListenableBuilder<(int, int)>(
                      valueListenable: _touch,
                      builder: (context, touch, _) {
                        final (held, tip) = touch;
                        if (tip < 0 || tip >= n) return const SizedBox.shrink();
                        return LayoutBuilder(
                          builder: (context, box) {
                            final st = standFor(n, box.maxWidth - _kAxisW);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                tooltip(
                                  tip,
                                  _kAxisW +
                                      st.lead +
                                      st.gap +
                                      tip * st.pitch +
                                      st.barW / 2,
                                  held >= 0,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    // The left and bottom lines stay put while the bars scroll.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _AxisPainter(
                            color: ghost,
                            bottom: bottomLineY,
                            top: _kTop - 2,
                          ),
                        ),
                      ),
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

/// The scrolled bars' clip: from the left line's inner edge on, and as far in
/// as a date chip is wider than its bar (on each side: the neighbors' chips
/// would show as slivers in the gaps).
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

/// A period's date upright in a chip; the one shown is tinted in the
/// chart's color.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.text,
    required this.selected,
    required this.color,
  });
  final String text;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .22) : context.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: InkText(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: selected ? scheme.onSurface : null,
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}

/// The bars, and behind them the ghost lines.
class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.first,
    required this.barW,
    required this.pitch,
    required this.maxY,
    required this.ticks,
    required this.yOf,
    required this.bottom,
    required this.color,
    required this.ghost,
  });

  final List<int> values;

  /// The first bar's left, and the pitch (bar + gap).
  final double first, barW, pitch;
  final double maxY, bottom;
  final int ticks;
  final double Function(double) yOf;
  final Color color, ghost;

  @override
  void paint(Canvas canvas, Size size) {
    final step = ticks == 0 ? 1.0 : maxY / ticks;
    // Where the numbers sit (the top one, then down; the bottom is the line).
    final cuts = [for (var k = ticks; k >= 1; k--) yOf(k * step)];
    double leftOf(int i) => first + i * pitch;
    double topOf(int i) => math.min(yOf(values[i].toDouble()), bottom - 2);

    // Behind the bars: clipped out where one stands (a bar is a little
    // see-through when it isn't the one shown).
    final bars = Path();
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      bars.addRRect(
        RRect.fromLTRBR(
          leftOf(i),
          topOf(i),
          leftOf(i) + barW,
          bottom + 4,
          const Radius.circular(_kBarR),
        ),
      );
    }
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        bars,
      ),
    );
    final line = Paint()
      ..color = ghost
      ..strokeWidth = _kGhostW
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < values.length; i++) {
      final x = leftOf(i) + barW / 2;
      var from = _kTop;
      for (final y in cuts) {
        final to = y - _kCut;
        if (to - from > 2) {
          canvas.drawLine(Offset(x, from + 1), Offset(x, to - 1), line);
        }
        from = y + _kCut;
      }
      if (bottom - from > 2) {
        canvas.drawLine(Offset(x, from + 1), Offset(x, bottom), line);
      }
    }
    canvas.restore();

    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      canvas.drawRRect(
        RRect.fromLTRBR(
          leftOf(i),
          topOf(i),
          leftOf(i) + barW,
          bottom,
          const Radius.circular(_kBarR),
        ),
        // Every bar one color: the period shown is told by its date chip
        // alone (the owner, 2026-11-01).
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      !listEquals(old.values, values) ||
      old.first != first ||
      old.barW != barW ||
      old.pitch != pitch ||
      old.maxY != maxY ||
      old.color != color ||
      old.ghost != ghost;
}

/// The left line and the bottom line (the bottom one a little under the
/// bars), one weight, round-ended, the corner rounded.
class _AxisPainter extends CustomPainter {
  _AxisPainter({required this.color, required this.bottom, required this.top});
  final Color color;
  final double bottom, top;

  @override
  void paint(Canvas canvas, Size size) {
    const w = _kAxisW, r = 10.0;
    const x = w / 2;
    canvas.drawPath(
      Path()
        ..moveTo(x, top)
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
  bool shouldRepaint(_AxisPainter old) =>
      old.color != color || old.bottom != bottom || old.top != top;
}

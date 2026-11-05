// lib/features/stats/category_charts.dart
// Statistics' "By category" chart (the owner, 2026-10-27; the bubbles it
// was shown beside were dropped 2026-10-28: the ring is enough alone):
//  - CategoryPie: a ring whose slices each reach out as far as they're big
//    (the biggest all the way, the smallest still four fifths), the middle
//    open, the slices a little apart with round corners; a touched slice
//    grows a little further out.
// No text in it: the chips under it say what's what.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One category on a chart: its amount and color.
typedef CategoryPart = ({String gid, int amount, Color color});

// ============================================================================
// The ring
// ============================================================================

class CategoryPie extends StatefulWidget {
  const CategoryPie({
    super.key,
    required this.parts,
    required this.touched,
    required this.onTouch,
    this.radius = 118,
  });

  /// Biggest first.
  final List<CategoryPart> parts;

  /// The part lit (an index into [parts]; -1: none).
  final int touched;

  /// A part touched (its index) or let go (-1).
  final ValueChanged<int> onTouch;

  /// The biggest slice's reach; a touched one goes [grow] further.
  final double radius;
  static const double grow = 10;

  /// The open middle, of the radius; the smallest slice's reach (the
  /// owner, 2026-10-27: the sizes less apart than .66 had them).
  static const double hole = .3, least = .8;

  /// Between two slices, and their corners' round.
  static const double gap = 3, corner = 5;

  /// The narrowest a slice gets (radians): a sliver still shows.
  static const double minSweep = .14;

  @override
  State<CategoryPie> createState() => _CategoryPieState();
}

class _CategoryPieState extends State<CategoryPie>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 200);

  /// How far out each part is (0..1), by gid.
  final Map<String, double> _grown = {};
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  String? get _lit =>
      widget.touched >= 0 && widget.touched < widget.parts.length
      ? widget.parts[widget.touched].gid
      : null;

  @override
  void didUpdateWidget(CategoryPie old) {
    super.didUpdateWidget(old);
    // Only when a part may have to move (the page building again for
    // something else cost a frame of work here).
    final was = old.touched >= 0 && old.touched < old.parts.length
        ? old.parts[old.touched].gid
        : null;
    if (was == _lit && _grown.keys.every((g) => g == _lit)) return;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final step = (elapsed - _last).inMicroseconds / _duration.inMicroseconds;
    _last = elapsed;
    var moving = false;
    setState(() {
      for (final gid in {..._grown.keys, ?_lit}) {
        final to = gid == _lit ? 1.0 : 0.0;
        final from = _grown[gid] ?? 0;
        final now = from < to
            ? math.min(to, from + step)
            : math.max(to, from - step);
        if (now == 0) {
          _grown.remove(gid);
        } else {
          _grown[gid] = now;
        }
        if (now != to) moving = true;
      }
    });
    if (!moving) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Each part's start and sweep (radians, from the top, clockwise) and
  /// reach (of the radius).
  List<(double, double, double)> _slices() {
    final parts = widget.parts;
    final sum = parts.fold<int>(0, (a, p) => a + p.amount);
    if (sum <= 0) return const [];
    var sweeps = [for (final p in parts) 2 * math.pi * p.amount / sum];
    final small = sweeps.where((s) => s < CategoryPie.minSweep).length;
    if (small > 0 && small < sweeps.length) {
      final big = sweeps
          .where((s) => s >= CategoryPie.minSweep)
          .fold(0.0, (a, s) => a + s);
      final scale = (2 * math.pi - small * CategoryPie.minSweep) / big;
      sweeps = [
        for (final s in sweeps)
          s < CategoryPie.minSweep ? CategoryPie.minSweep : s * scale,
      ];
    }
    final top = parts.first.amount.toDouble();
    final out = <(double, double, double)>[];
    var a = -math.pi / 2;
    for (var i = 0; i < parts.length; i++) {
      // Reach by the square root of the size against the biggest's: the
      // small ones still stand well out of the middle.
      final reach =
          CategoryPie.least +
          (1 - CategoryPie.least) * math.sqrt(parts[i].amount / top);
      out.add((a, sweeps[i], reach));
      a += sweeps[i];
    }
    return out;
  }

  int _partAt(Offset p, Size size) {
    final c = size.center(Offset.zero);
    final d = p - c;
    final dist = d.distance;
    if (dist < widget.radius * CategoryPie.hole) return -1;
    // From the top, clockwise.
    var ang = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (ang < 0) ang += 2 * math.pi;
    final slices = _slices();
    for (var i = 0; i < slices.length; i++) {
      final (start, sweep, reach) = slices[i];
      final s = start + math.pi / 2;
      if (ang >= s && ang <= s + sweep) {
        final r = widget.radius * reach + CategoryPie.grow;
        return dist <= r ? i : -1;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, 2 * (widget.radius + CategoryPie.grow));
      void touch(Offset p) => widget.onTouch(_partAt(p, size));
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => touch(e.localPosition),
        onPointerMove: (e) => touch(e.localPosition),
        onPointerUp: (_) => widget.onTouch(-1),
        onPointerCancel: (_) => widget.onTouch(-1),
        child: CustomPaint(
          size: size,
          painter: _PiePainter(
            slices: _slices(),
            colors: [for (final p in widget.parts) p.color],
            grown: [
              for (final p in widget.parts)
                Curves.easeOutCubic.transform(_grown[p.gid] ?? 0),
            ],
            radius: widget.radius,
          ),
        ),
      );
    },
  );
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.colors,
    required this.grown,
    required this.radius,
  });

  final List<(double, double, double)> slices;
  final List<Color> colors;
  final List<double> grown;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final inner = radius * CategoryPie.hole;
    for (var i = 0; i < slices.length; i++) {
      final (start, sweep, reach) = slices[i];
      final r = radius * reach + CategoryPie.grow * grown[i];
      final path = slices.length == 1
          // One category: the whole ring.
          ? (Path()
              ..fillType = PathFillType.evenOdd
              ..addOval(Rect.fromCircle(center: c, radius: r))
              ..addOval(Rect.fromCircle(center: c, radius: inner)))
          : _slice(c, inner, r, start, sweep);
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[i]
          ..isAntiAlias = true,
      );
    }
  }

  /// A slice from [a] through [sweep] between radii [ri] and [ro], its
  /// sides [CategoryPie.gap] / 2 in from the cut (straight: the gap one
  /// width all along), its four corners rounded.
  static Path _slice(Offset c, double ri, double ro, double a, double sweep) {
    Offset at(double r, double ang) =>
        c + Offset(math.cos(ang), math.sin(ang)) * r;
    // The sides' angle in from the cut at a radius (a sliver: never past
    // its middle).
    double inset(double r) =>
        math.min(math.asin(CategoryPie.gap / 2 / r), sweep / 2 - .002);
    final dO = inset(ro), dI = inset(ri);
    final a0o = a + dO, a1o = a + sweep - dO;
    final a0i = a + dI, a1i = a + sweep - dI;
    // The corners' round, as far as the slice's edges allow.
    final kO = math.max(
      0.0,
      math.min(
        CategoryPie.corner,
        math.min((a1o - a0o) * ro / 2, (ro - ri) / 2),
      ),
    );
    final kI = math.max(
      0.0,
      math.min(
        CategoryPie.corner,
        math.min((a1i - a0i) * ri / 2, (ro - ri) / 2),
      ),
    );
    Offset toward(Offset from, Offset to, double d) {
      final v = to - from;
      final l = v.distance;
      return l == 0 ? from : from + v / l * d;
    }

    final po0 = at(ro, a0o), po1 = at(ro, a1o);
    final pi0 = at(ri, a0i), pi1 = at(ri, a1i);
    final start = toward(po0, pi0, kO);
    final path = Path()..moveTo(start.dx, start.dy);
    // The outer start corner, the outer arc, the outer end corner.
    var q = at(ro, a0o + kO / ro);
    path.quadraticBezierTo(po0.dx, po0.dy, q.dx, q.dy);
    path.arcTo(
      Rect.fromCircle(center: c, radius: ro),
      a0o + kO / ro,
      math.max(0.0, (a1o - a0o) - 2 * kO / ro),
      false,
    );
    q = toward(po1, pi1, kO);
    path.quadraticBezierTo(po1.dx, po1.dy, q.dx, q.dy);
    // Down the side, the inner end corner, the inner arc back, the inner
    // start corner, up the other side.
    q = toward(pi1, po1, kI);
    path.lineTo(q.dx, q.dy);
    q = at(ri, a1i - kI / ri);
    path.quadraticBezierTo(pi1.dx, pi1.dy, q.dx, q.dy);
    path.arcTo(
      Rect.fromCircle(center: c, radius: ri),
      a1i - kI / ri,
      -math.max(0.0, (a1i - a0i) - 2 * kI / ri),
      false,
    );
    q = toward(pi0, po0, kI);
    path.quadraticBezierTo(pi0.dx, pi0.dy, q.dx, q.dy);
    return path..close();
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.radius != radius ||
      old.slices.length != slices.length ||
      [
        for (var i = 0; i < slices.length; i++)
          old.slices[i] != slices[i] ||
              old.colors[i] != colors[i] ||
              old.grown[i] != grown[i],
      ].any((d) => d);
}

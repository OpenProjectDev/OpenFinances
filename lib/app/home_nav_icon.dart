// lib/app/home_nav_icon.dart
// The Home tab's icon (Uicons "house blank", drawn from its vector path) in
// two parts, the roof and the rest; a tap lifts the roof and lets it drop
// back with a small bounce. At rest it's the icon itself, in one piece (the
// owner's rule: an icon looks exactly as given unless asked otherwise).

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The house outline on a 24 × 24 grid (Uicons Solid Rounded "house-blank").
final Path _house = Path()
  ..moveTo(19, 24)
  ..lineTo(5, 24)
  ..cubicTo(2.243, 24, 0, 21.757, 0, 19)
  ..lineTo(0, 9.724)
  ..cubicTo(0, 8.059, 0.824, 6.509, 2.204, 5.579)
  ..lineTo(9.203, 0.855)
  ..cubicTo(10.902, -0.291, 13.098, -0.291, 14.797, 0.855)
  ..lineTo(21.797, 5.579)
  ..cubicTo(23.176, 6.509, 24, 8.058, 24, 9.724)
  ..lineTo(24, 19)
  ..cubicTo(24, 21.757, 21.757, 24, 19, 24)
  ..close();

/// Where the roof ends and the walls begin (one line: no gap; at rest the
/// house is drawn whole, exactly as the icon is).
const double _eaves = 8.0;

final Path _roof = Path.combine(
  PathOperation.intersect,
  _house,
  Path()..addRect(const Rect.fromLTRB(-1, -1, 25, _eaves)),
);
final Path _walls = Path.combine(
  PathOperation.intersect,
  _house,
  Path()..addRect(const Rect.fromLTRB(-1, _eaves, 25, 25)),
);

/// The Home tab's icon; [bounce] changes (e.g. a tap counter) lift the roof.
class HomeNavIcon extends StatefulWidget {
  const HomeNavIcon({
    super.key,
    required this.color,
    required this.size,
    required this.bounce,
  });

  final Color color;
  final double size;

  /// Each new value plays the roof's hop once.
  final int bounce;

  @override
  State<HomeNavIcon> createState() => _HomeNavIconState();
}

class _HomeNavIconState extends State<HomeNavIcon>
    with SingleTickerProviderStateMixin {
  late final _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(covariant HomeNavIcon old) {
    super.didUpdateWidget(old);
    // A tap while the roof is still up doesn't start it over.
    if (old.bounce != widget.bounce && !_hop.isAnimating) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  /// The roof's lift (grid units) at [t]: up fast, down, two small bounces.
  static double _lift(double t) {
    if (t < .28) return 3.2 * Curves.easeOutCubic.transform(t / .28);
    final u = (t - .28) / .72;
    // A falling bounce: |cos| decaying, landing at 0.
    return 3.2 * math.pow(1 - u, 2) * (math.cos(u * math.pi * 2.5)).abs();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Its own layer: its animation repaints only itself.
    child: AnimatedBuilder(
      animation: _hop,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _HousePainter(
          color: widget.color,
          lift: _hop.isAnimating ? _lift(_hop.value) : 0,
        ),
      ),
    ),
  );
}

class _HousePainter extends CustomPainter {
  const _HousePainter({required this.color, required this.lift});
  final Color color;
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.scale(size.width / 24, size.height / 24);
    // At rest: the whole house (two parts meeting would leave a hairline).
    if (lift == 0) {
      canvas.drawPath(_house, paint);
      return;
    }
    canvas.drawPath(_walls, paint);
    canvas.save();
    canvas.translate(0, -lift);
    canvas.drawPath(_roof, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HousePainter old) =>
      old.color != color || old.lift != lift;
}

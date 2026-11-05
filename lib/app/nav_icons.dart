// lib/app/nav_icons.dart
// The bottom bar's own icons, besides Home's house (home_nav_icon.dart):
// Budget's drive, whose two lights flash on a tap; Statistics' bars, which
// rise and fall on a tap; Settings' gear, which turns two teeth on a tap;
// and the "+", whose plus tilts when what it adds changes. At rest each is
// exactly the owner's icon.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/app_icons.dart';

/// Plays [controller] from the start whenever [bounce] changes, unless
/// it's still playing (a tap during it doesn't start it over).
mixin _PlaysOnBounce<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  Duration get duration;
  int bounceOf(T widget);

  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: duration,
  );

  @override
  void didUpdateWidget(covariant T old) {
    super.didUpdateWidget(old);
    if (bounceOf(old) != bounceOf(widget) && !controller.isAnimating) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// A closed outline around the middle of a 512 px icon, from its edge's
/// distance to the middle every half degree from 0° to 45° ([radii], 91
/// of them); the rest mirrors it (the shape is symmetric 8 ways).
Path _outline(List<double> radii) {
  final p = Path();
  // Every 2° is plenty (a chord strays under 0.05 px from the curve).
  for (var k = 0; k < 720; k += 4) {
    final q = k % 180; // within a quarter
    final r = radii[q <= 90 ? q : 180 - q];
    final a = k * math.pi / 360;
    final pt = Offset(256 + r * math.cos(a), 256 + r * math.sin(a));
    k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

// ---- Budget: Uicons "HDD"; its two lights flash ---------------------------

/// The Budget tab's drive (Uicons "HDD"); each new [bounce] flashes its two
/// round lights: the left one red, the right one orange, the left one red
/// again, each lit full and gone.
class BudgetNavIcon extends StatefulWidget {
  const BudgetNavIcon({
    super.key,
    required this.color,
    required this.size,
    required this.bounce,
  });

  final Color color;
  final double size;
  final int bounce;

  @override
  State<BudgetNavIcon> createState() => _BudgetNavIconState();
}

class _BudgetNavIconState extends State<BudgetNavIcon>
    with SingleTickerProviderStateMixin, _PlaysOnBounce {
  @override
  Duration get duration => const Duration(milliseconds: 1200);
  @override
  int bounceOf(BudgetNavIcon w) => w.bounce;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Its own layer: its animation repaints only itself.
    child: SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          ImageIcon(AppIcons.budget, color: widget.color, size: widget.size),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => controller.isAnimating
                ? CustomPaint(
                    size: Size.square(widget.size),
                    painter: _LightsPainter(controller.value, widget.color),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

class _LightsPainter extends CustomPainter {
  const _LightsPainter(this.t, this.drive);
  final double t;

  /// The drive's color (the theme color while its tab is picked).
  final Color drive;

  /// The lights' centers and radius in the 512 px icon.
  static const _left = Offset(309.33, 437.33), _right = Offset(394.67, 437.33);
  static const double _r = 32;
  // Orange, not green: green is as bright as the blue drive and too near it
  // in hue, it all but vanished (the owner, 2026-10-25); orange is blue's
  // opposite.
  static const _orange = Color(0xFFFF9800);

  /// [light], or blue on a drive near it in hue (a red or orange theme
  /// color): a flash stands out from the drive it's on.
  static Color _against(Color light, Color drive) {
    final d = HSLColor.fromColor(drive);
    if (d.saturation < .25 || d.lightness < .12 || d.lightness > .9) {
      return light; // a gray, black or white drive: any color shows
    }
    final gap = (d.hue - HSLColor.fromColor(light).hue).abs();
    return math.min(gap, 360 - gap) < 50 ? kBrandBlue : light;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Three flashes in a row, a third of the time each.
    final i = math.min(2, (t * 3).floor());
    final u = t * 3 - i;
    // On fast, held a moment, off a little slower.
    final level = u < .25 ? u / .25 : (u < .5 ? 1.0 : 1 - (u - .5) / .5);
    final color = _against(
      i == 1 ? _orange : kStrongRed,
      drive,
    ).withValues(alpha: level);
    canvas.scale(size.width / 512);
    // A hair wider than the hole: no rim of the background around it.
    canvas.drawCircle(
      i == 1 ? _right : _left,
      _r + 1.5,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_LightsPainter old) => old.t != t || old.drive != drive;
}

// ---- Statistics: four bars on a rounded square -----------------------------

/// The Statistics tab's icon: Uicons "Stats"' four bars (without its axes,
/// made thicker and given room around them), cut out of a rounded square.
/// Each new [bounce] lets the bars rise and fall a moment, each to its own
/// beat, back to where they stood.
class StatsNavIcon extends StatefulWidget {
  const StatsNavIcon({
    super.key,
    required this.color,
    required this.size,
    required this.bounce,
  });

  final Color color;
  final double size;
  final int bounce;

  @override
  State<StatsNavIcon> createState() => _StatsNavIconState();
}

class _StatsNavIconState extends State<StatsNavIcon>
    with SingleTickerProviderStateMixin, _PlaysOnBounce {
  @override
  Duration get duration => const Duration(milliseconds: 1000);
  @override
  int bounceOf(StatsNavIcon w) => w.bounce;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Its own layer: its animation repaints only itself.
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _BarsPainter(
          widget.color,
          controller.isAnimating ? controller.value : 0,
        ),
      ),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter(this.color, this.t);
  final Color color;
  final double t;

  /// The plate (512 px icon): a square 470 wide, corners a quarter of it.
  static final _plate = Path()
    ..addRRect(
      RRect.fromLTRBR(21, 21, 491, 491, const Radius.circular(470 * .25)),
    );

  /// The bars: 34 wide with round ends, 74 apart, short and tall in Stats'
  /// proportions, standing on one line, the group in the plate's middle
  /// (about 110 from its sides, 120 from its top and bottom).
  static const _x = [145.0, 219.0, 293.0, 367.0];
  static const _top = [223.0, 141.0, 223.0, 141.0];
  static const double _bottom = 371, _w = 34;

  /// Each bar's beat, so they don't move together.
  static const _phase = [0.0, 1.9, 0.9, 2.8];

  /// How far each bar may rise and sink at most (512 px icon): the tall
  /// ones rise a little and sink far, the short ones rise far and sink a
  /// little (the owner tunes these by eye).
  static const _up = [62.0, 20.0, 62.0, 20.0];
  static const _down = [28.0, 66.0, 28.0, 66.0];

  /// The icon at rest, worked out once.
  static final Path _rest = _shape(0);

  static Path _shape(double t) {
    final bars = Path();
    for (var i = 0; i < 4; i++) {
      // Up and down, swelling in and dying out.
      final wave = t == 0
          ? 0.0
          : math.sin(math.pi * t) * math.sin(2 * math.pi * 1.5 * t + _phase[i]);
      final lift = wave * (wave > 0 ? _up[i] : _down[i]);
      bars.addRRect(
        RRect.fromLTRBR(
          _x[i] - _w / 2,
          _top[i] - lift,
          _x[i] + _w / 2,
          _bottom,
          const Radius.circular(_w / 2),
        ),
      );
    }
    return Path.combine(PathOperation.difference, _plate, bars);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    canvas.drawPath(
      t == 0 ? _rest : _shape(t),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.color != color || old.t != t;
}

// ---- Settings: a gear that turns two teeth --------------------------------

/// The Settings tab's gear (Phoenix Group's "Setting"); each new [bounce]
/// turns it by two of its six teeth (120°) at one slow, even speed, like
/// heavy machinery, and stops there: it repeats every 60°, so it ends
/// looking as it started.
class SettingsNavIcon extends StatefulWidget {
  const SettingsNavIcon({
    super.key,
    required this.color,
    required this.size,
    required this.bounce,
  });

  final Color color;
  final double size;
  final int bounce;

  @override
  State<SettingsNavIcon> createState() => _SettingsNavIconState();
}

class _SettingsNavIconState extends State<SettingsNavIcon>
    with SingleTickerProviderStateMixin, _PlaysOnBounce {
  @override
  Duration get duration => const Duration(milliseconds: 1300);
  @override
  int bounceOf(SettingsNavIcon w) => w.bounce;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Its own layer: its animation repaints only itself.
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Transform.rotate(
        // Even speed all the way: no easing, no overshoot.
        angle: controller.isAnimating ? controller.value * 2 * math.pi / 3 : 0,
        child: child,
      ),
      child: ImageIcon(
        AppIcons.settings,
        color: widget.color,
        size: widget.size,
      ),
    ),
  );
}

// ---- The "+": its plus tilts when what it adds changes --------------------

/// The "+"'s rounded square (Icon Mart's "Add"): its edge's distance from
/// the middle of the 512 px icon every half degree, 0° to 45°, measured on
/// the owner's image (traced back, it matches it to the pixel).
const List<double> _addRadii = [
  175.68,
  175.68,
  175.68,
  175.68,
  175.72,
  175.77,
  175.84,
  175.92,
  176.00,
  176.07,
  176.17,
  176.26,
  176.39,
  176.50,
  176.66,
  176.79,
  176.98,
  177.14,
  177.32,
  177.53,
  177.76,
  178.00,
  178.25,
  178.52,
  178.80,
  179.08,
  179.35,
  179.61,
  179.90,
  180.20,
  180.53,
  180.85,
  181.20,
  181.58,
  181.97,
  182.38,
  182.80,
  183.21,
  183.62,
  184.06,
  184.50,
  184.93,
  185.41,
  185.93,
  186.46,
  186.99,
  187.50,
  188.05,
  188.59,
  189.15,
  189.76,
  190.39,
  190.99,
  191.62,
  192.27,
  192.91,
  193.61,
  194.31,
  195.00,
  195.74,
  196.46,
  197.24,
  197.95,
  198.65,
  199.36,
  200.09,
  200.60,
  201.31,
  201.84,
  202.48,
  202.86,
  203.49,
  203.95,
  204.31,
  204.80,
  205.27,
  205.59,
  205.85,
  206.16,
  206.48,
  206.78,
  206.97,
  207.24,
  207.40,
  207.58,
  207.69,
  207.87,
  207.96,
  208.05,
  208.07,
  208.06,
];

final Path _addSquare = _outline(_addRadii);

/// What the bottom bar's "+" opens: the SHEET (or page), never what's
/// preset in it. The plus tilts only when this changes (the owner's rule):
/// an expense and an income are one sheet, so are an expense and an income
/// category. A new kind of add gets its own value here.
enum AddSheet {
  /// The add-entry sheet (expense or income, whichever side is preset).
  entry,

  /// The add-upcoming-payment sheet.
  upcoming,

  /// The add-debt sheet.
  debt,

  /// The add-category sheet (expense or income categories).
  category,

  /// Not a sheet: the SMS tab's unknown messages, to define a format.
  smsFormat,
}

/// The bottom bar's "+" (Icon Mart's "Add": its rounded square and its
/// plus on it). [adds] is the sheet it opens here ([AddSheet]): when that
/// changes, from one page or tab to another or back, the plus tilts a
/// little to the right, then to the left, and settles (a tap alone
/// doesn't, nor a change of what's preset in the same sheet). Only the bar
/// on top plays it: a page pushed over the main page brings its own bar,
/// and going back to the main page's is a change too.
class AddNavIcon extends StatefulWidget {
  const AddNavIcon({
    super.key,
    required this.adds,
    required this.color,
    required this.size,
    required this.plusColor,
  });

  final AddSheet adds;
  final Color color;
  final double size;

  /// How many tilts have started (tests check the rule with it).
  @visibleForTesting
  static int debugTilts = 0;

  /// The plus's own color, drawn on the square (opaque, not a cut-out).
  final Color plusColor;

  @override
  State<AddNavIcon> createState() => _AddNavIconState();
}

class _AddNavIconState extends State<AddNavIcon>
    with SingleTickerProviderStateMixin {
  /// The bars showing, oldest first (the last one is on top).
  static final List<_AddNavIconState> _live = [];

  /// What the "+" on top opened when it was last seen.
  static AddSheet? _shown;

  late final AnimationController _tilt = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    _live.add(this);
    _cameOnTop();
  }

  /// This bar is on top now (or what it adds changed): tilt if the "+" now
  /// does something else.
  void _cameOnTop() {
    // Not over itself: a tilt still playing plays on.
    if (_shown != null && _shown != widget.adds && !_tilt.isAnimating) {
      AddNavIcon.debugTilts++;
      _tilt.forward(from: 0);
    }
    _shown = widget.adds;
  }

  @override
  void didUpdateWidget(covariant AddNavIcon old) {
    super.didUpdateWidget(old);
    if (_live.isNotEmpty && _live.last == this && old.adds != widget.adds) {
      _cameOnTop();
    }
  }

  @override
  void dispose() {
    final top = _live.isNotEmpty && _live.last == this;
    _live.remove(this);
    // Back to the bar below: it shows what it adds again. After this frame:
    // the tree is being torn down now, nothing may start building.
    if (top && _live.isNotEmpty) {
      final below = _live.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (below.mounted && _live.isNotEmpty && _live.last == below) {
          below._cameOnTop();
        }
      });
    }
    _tilt.dispose();
    super.dispose();
  }

  /// The plus's turn (radians, clockwise) at [t]: right, then left, then
  /// home, easing in and out.
  static double _angle(double t) =>
      22 * math.pi / 180 * math.sin(2 * math.pi * t) * math.sin(math.pi * t);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Its own layer: its animation repaints only itself.
    child: AnimatedBuilder(
      animation: _tilt,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _AddPainter(
          widget.color,
          widget.plusColor,
          _tilt.isAnimating ? _angle(_tilt.value) : 0,
        ),
      ),
    ),
  );
}

class _AddPainter extends CustomPainter {
  const _AddPainter(this.color, this.plusColor, this.angle);
  final Color color, plusColor;
  final double angle;

  /// The plus in the 512 px icon: two bars 212 long and 32 thick with round
  /// ends, crossing in the middle; from the middle to an end's center: 90.
  static const double _arm = 90, _thick = 32;

  /// One bar of the plus, lying [angle] (radians) off level.
  static Path _bar(double angle) {
    const end = _arm + _thick / 2;
    final level = Path()
      ..addRRect(
        RRect.fromLTRBR(
          256 - end,
          256 - _thick / 2,
          256 + end,
          256 + _thick / 2,
          const Radius.circular(_thick / 2),
        ),
      );
    final turn = Matrix4.identity()
      ..translateByDouble(256, 256, 0, 1)
      ..rotateZ(angle)
      ..translateByDouble(-256, -256, 0, 1);
    return level.transform(turn.storage);
  }

  /// The plus at rest, worked out once.
  static final Path _rest = _plus(0);

  static Path _plus(double angle) =>
      Path.combine(PathOperation.union, _bar(angle), _bar(angle + math.pi / 2));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    canvas.drawPath(_addSquare, Paint()..color = color);
    canvas.drawPath(
      angle == 0 ? _rest : _plus(angle),
      Paint()..color = plusColor,
    );
  }

  @override
  bool shouldRepaint(_AddPainter old) =>
      old.color != color || old.plusColor != plusColor || old.angle != angle;
}

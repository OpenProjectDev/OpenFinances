// lib/shared/ui/day_wheel.dart
// A wheel of values inside a chip (Settings' month start day, Statistics'
// days): drag up or down anywhere on it, a flick carries on a little, and
// it snaps to a value; only the value under its middle shows, its
// neighbours fading in as it turns. A tap shows that it turns: half a step
// up, back, half a step down, back (a drag takes over at once).

import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/ink_text.dart';

class DayWheel extends StatefulWidget {
  const DayWheel({
    super.key,
    required this.value,
    required this.count,
    required this.labelOf,
    required this.onChanged,
    required this.style,
    this.loop = false,
    this.min = 0,
    this.max,
    this.alignment = AlignmentDirectional.center,
    this.padding = EdgeInsetsDirectional.zero,
    this.labelWidth,
  });

  /// The value it stands on, 0..[count) (it turns to a new one given).
  final int value;
  final int count;

  /// What value [i] reads.
  final String Function(int i) labelOf;

  /// It settled on a new value.
  final ValueChanged<int> onChanged;
  final TextStyle style;

  /// Past the last comes the first; else it stops at [min] and [max]
  /// (default: the last), and values past those aren't shown at all.
  final bool loop;
  final int min;
  final int? max;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  /// Each value centered in a slot this wide (placed by [alignment] and
  /// [padding]): the wheel can be wider than where it shows (Statistics'
  /// days: a whole half of the chip turns it).
  final double? labelWidth;

  @override
  State<DayWheel> createState() => _DayWheelState();
}

class _DayWheelState extends State<DayWheel>
    with SingleTickerProviderStateMixin {
  /// From one value to the next: just past the fade's reach (22 dp,
  /// [_alpha]), so settled, the neighbours are out of view, and turning the
  /// wheel shows them coming in.
  static const _step = 30.0;

  /// Where the wheel is, in steps from value 0 (any real number when it
  /// loops). Driven by drags and by [_anim].
  late double _pos = widget.value.toDouble();
  late final AnimationController _anim = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _pos = _anim.value));

  bool _hinting = false, _dragging = false;

  int get _max => widget.max ?? widget.count - 1;

  /// The value at wheel position [p].
  int _at(double p) => widget.loop
      ? p.round() % widget.count
      : p.round().clamp(widget.min, _max);

  @override
  void didUpdateWidget(DayWheel old) {
    super.didUpdateWidget(old);
    // Given a new value (or bounds that leave it out): turn to it.
    if (!_dragging && !_anim.isAnimating && _at(_pos) != widget.value) {
      _glide(_nearest(widget.value));
    }
  }

  /// [v]'s position nearest where the wheel stands (a loop has many).
  double _nearest(int v) {
    if (!widget.loop) return v.toDouble();
    final n = widget.count;
    final base = (_pos / n).floorToDouble() * n;
    return [
      base - n + v,
      base + v,
      base + n + v,
    ].reduce((a, b) => (a - _pos).abs() <= (b - _pos).abs() ? a : b);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _glide(
    double to, {
    int ms = 260,
    Curve curve = Curves.easeOutCubic,
  }) async {
    _anim.value = _pos;
    await _anim.animateTo(
      to,
      duration: Duration(milliseconds: ms),
      curve: curve,
    );
  }

  Future<void> _hint() async {
    if (_hinting) return;
    _hinting = true;
    final at = _pos.roundToDouble();
    for (final to in [at - .5, at, at + .5, at]) {
      if (!_hinting || !mounted) break;
      await _glide(to, curve: Curves.easeInOutCubic);
    }
    _hinting = false;
  }

  void _dragStart(DragStartDetails _) {
    _hinting = false; // the user's motion, not ours
    _dragging = true;
    _anim.stop();
  }

  // Dragging down brings the value above (the previous one) in.
  void _drag(DragUpdateDetails d) => setState(() {
    _pos -= d.delta.dy / _step;
    if (!widget.loop) {
      _pos = _pos.clamp(widget.min - .4, _max + .4);
    }
  });

  // Let go: a flick carries on a little, then it snaps to a value.
  Future<void> _dragEnd(DragEndDetails d) async {
    _dragging = false;
    final carry = -(d.primaryVelocity ?? 0) / _step * .12;
    var to = (_pos + carry).roundToDouble();
    if (!widget.loop) to = to.clamp(widget.min, _max).toDouble();
    await _glide(to, ms: carry.abs() > 1 ? 420 : 240);
    // Settled (not taken over by another drag): that's the value now.
    if (mounted && _pos == to && _at(to) != widget.value) {
      widget.onChanged(_at(to));
    }
  }

  /// How solid the value [i] steps from 0 is where the wheel stands.
  double _alpha(int i) {
    final off = (i - _pos).abs() * _step;
    return (1 - (off - 4) / 18).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _hint,
    onVerticalDragStart: _dragStart,
    onVerticalDragUpdate: _drag,
    onVerticalDragEnd: _dragEnd,
    child: ClipRect(
      child: LayoutBuilder(
        builder: (context, box) {
          final color =
              widget.style.color ?? DefaultTextStyle.of(context).style.color!;
          // The value under the wheel's middle and its neighbours, sliding
          // as it turns. Each fades by its own distance from the middle
          // (solid within 4 dp, gone at 22 dp), so one is drawn only while
          // it's well inside the chip: nothing reaches an edge.
          return Stack(
            fit: StackFit.expand,
            children: [
              for (var i = _pos.floor() - 1; i <= _pos.floor() + 2; i++)
                if (_alpha(i) > 0 &&
                    (widget.loop || (i >= widget.min && i <= _max)))
                  Positioned(
                    top: (i - _pos) * _step,
                    height: box.maxHeight,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: widget.alignment,
                      child: Padding(
                        padding: widget.padding,
                        child: SizedBox(
                          width: widget.labelWidth,
                          child: InkText(
                            widget.labelOf(widget.loop ? i % widget.count : i),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: widget.style.copyWith(
                              color: color.withValues(
                                alpha: color.a * _alpha(i),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
}

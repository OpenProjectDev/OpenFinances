import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lifts [child] above the soft keyboard without re-laying it out on every
/// keyboard-animation frame.
///
/// A plain `Padding(bottom: viewInsets.bottom)` hands the child smaller
/// constraints each frame, so a whole form re-lays-out ~30 times while the
/// keyboard slides in (visible stutter). Here the child keeps its original
/// constraints whenever it fits above the keyboard; only this box's own
/// height grows by the inset, which moves the child up. If the child is too
/// tall to fit, it is given the reduced height instead (and can scroll).
///
/// Pass the same [child] instance on every build (build it once, then reuse)
/// so it isn't rebuilt either. A sheet in it can always be pulled down to
/// close ([SheetPull]), also once the keyboard makes its form scroll.
class KeyboardInset extends StatelessWidget {
  const KeyboardInset({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _KeyboardLift(
    inset: MediaQuery.viewInsetsOf(context).bottom,
    // Moving the child then only re-composites its layer, no repaint.
    child: SheetPull(child: RepaintBoundary(child: child)),
  );
}

/// A sheet whose content scrolls can still be pulled down to close: from
/// its content's top, the pull moves the sheet down and, let go far or fast
/// enough, closes it (else it settles back). A sheet's own drag handles
/// content that doesn't scroll; content that does (a form with the keyboard
/// up, a long list) took every downward drag for itself, so the sheet
/// couldn't be pulled away (the owner, 2026-10-25).
class SheetPull extends StatefulWidget {
  const SheetPull({super.key, required this.child});
  final Widget child;

  @override
  State<SheetPull> createState() => _SheetPullState();
}

class _SheetPullState extends State<SheetPull>
    with SingleTickerProviderStateMixin {
  /// How far it's pulled down (logical pixels).
  double _pull = 0;
  double _from = 0;
  bool _closing = false;

  /// Let go past this, or flung down faster than [_speed], it closes.
  static const double _distance = 96, _speed = 700;

  late final AnimationController _back =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(() {
        setState(
          () =>
              _pull = _from * (1 - Curves.easeOutCubic.transform(_back.value)),
        );
      });

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _release(double velocity) {
    if (_pull <= 0) return;
    if (_pull >= _distance || velocity >= _speed) {
      _closing = true;
      Navigator.of(context).maybePop();
      return;
    }
    _from = _pull;
    _back.forward(from: 0);
  }

  bool _onScroll(ScrollNotification n) {
    if (_closing || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      // Dragged down past the content's top.
      _back.stop();
      setState(() => _pull -= n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        _pull > 0 &&
        (n.scrollDelta ?? 0) > 0) {
      // Pushed back up while pulled: the sheet goes up first.
      setState(() => _pull = math.max(0, _pull - n.scrollDelta!));
    } else if (n is ScrollEndNotification) {
      _release(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Transform.translate(
          offset: Offset(0, _pull),
          child: widget.child,
        ),
      );
}

class _KeyboardLift extends SingleChildRenderObjectWidget {
  const _KeyboardLift({required this.inset, super.child});
  final double inset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderKeyboardLift(inset: inset);

  @override
  void updateRenderObject(BuildContext context, _RenderKeyboardLift r) =>
      r.inset = inset;
}

class _RenderKeyboardLift extends RenderShiftedBox {
  _RenderKeyboardLift({required double inset}) : _inset = inset, super(null);

  double _inset;
  bool _onlyInsetChanged = false;
  double? _naturalHeight;
  BoxConstraints? _naturalFor;

  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    _onlyInsetChanged = true;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    final c = constraints;
    if (child == null) {
      size = c.constrain(Size(0, _inset));
      return;
    }

    // Child's height with the full constraints. When only the inset moved,
    // reuse the last measurement instead of laying the child out again.
    final reuse =
        _onlyInsetChanged && _naturalFor == c && _naturalHeight != null;
    _onlyInsetChanged = false;
    if (!reuse) {
      child.layout(c, parentUsesSize: true);
      _naturalHeight = child.size.height;
      _naturalFor = c;
    }

    final fits = !c.hasBoundedHeight || _naturalHeight! + _inset <= c.maxHeight;
    // Same constraints as last frame => Flutter skips the child's layout.
    child.layout(
      fits
          ? c
          : c.copyWith(
              minHeight: 0,
              maxHeight: math.max(0.0, c.maxHeight - _inset),
            ),
      parentUsesSize: true,
    );
    (child.parentData! as BoxParentData).offset = Offset.zero;
    size = c.constrain(Size(child.size.width, child.size.height + _inset));
  }
}

/// Focuses [node] once the route containing [context] has finished its
/// entrance animation, so the keyboard doesn't slide in while a sheet is
/// still sliding up (two animations at once is what makes sheets feel slow).
void focusAfterRouteOpens(BuildContext context, FocusNode node) {
  final animation = ModalRoute.of(context)?.animation;
  void focus() {
    if (node.context != null && node.canRequestFocus) node.requestFocus();
  }

  if (animation == null || animation.isCompleted) {
    WidgetsBinding.instance.addPostFrameCallback((_) => focus());
    return;
  }
  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      animation.removeStatusListener(onStatus);
      focus();
    }
  }

  animation.addStatusListener(onStatus);
}

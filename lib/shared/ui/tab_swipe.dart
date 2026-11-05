// lib/shared/ui/tab_swipe.dart
// Swiping sideways over a tabbed area moves to the next / previous tab.

import 'package:flutter/material.dart';

/// Over [child], a sideways swipe moves to the next tab ([onNext]) or the
/// previous one ([onPrevious]; null: none that way). It comes last: anything
/// inside that swipes sideways itself (a list row's swipe actions, a row of
/// chips that scrolls) wins the gesture, being deeper; vertical scrolling is
/// another direction and never meets it.
///
/// Tabs read from the start side, so in a right-to-left layout the next tab
/// is to the left: there a swipe to the right brings it, as a page would.
class TabSwipe extends StatefulWidget {
  const TabSwipe({
    super.key,
    required this.child,
    this.onNext,
    this.onPrevious,
  });

  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  @override
  State<TabSwipe> createState() => _TabSwipeState();
}

class _TabSwipeState extends State<TabSwipe> {
  double _dx = 0;

  /// How far, or how fast, a swipe has to go to count.
  static const double _distance = 56, _speed = 450;

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _dx.abs() >= _distance ? _dx : (v.abs() >= _speed ? v : 0.0);
    _dx = 0;
    if (dx == 0) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Toward the start side of the reading direction: the next tab.
    final next = rtl ? dx > 0 : dx < 0;
    (next ? widget.onNext : widget.onPrevious)?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onNext == null && widget.onPrevious == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _dx = 0,
      child: widget.child,
    );
  }
}

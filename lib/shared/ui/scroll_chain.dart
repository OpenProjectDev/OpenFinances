// lib/shared/ui/scroll_chain.dart
// A list inside a list: when the inner one can go no further, the drag (or
// fling) carries on in the one around it.

import 'package:flutter/widgets.dart';

/// Wraps a scrollable ([child]) that sits inside another one scrolling the
/// same way (e.g. Settings' ignore-list chips inside the Settings page).
/// Dragged past its end, what's left of the drag scrolls the outer list; a
/// fling that reaches its end (or starts there) goes on in the outer list.
class ScrollChain extends StatelessWidget {
  const ScrollChain({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Only the inner list's own (not lists inside it).
        if (n.depth != 0) return false;
        final outer = Scrollable.maybeOf(context);
        if (outer == null || outer.position.axis != n.metrics.axis) {
          return false;
        }
        final pos = outer.position;
        if (n is OverscrollNotification) {
          if (n.dragDetails != null) {
            // Dragging: the rest of the drag moves the outer list.
            pos.jumpTo(
              (pos.pixels + n.overscroll).clamp(
                pos.minScrollExtent,
                pos.maxScrollExtent,
              ),
            );
          } else if (n.velocity != 0) {
            _fling(pos, n.velocity); // a fling ran into the end
          }
        } else if (n is ScrollEndNotification) {
          // Let go at the end with speed: the inner list can't fling, the
          // outer one does.
          final v = -(n.dragDetails?.primaryVelocity ?? 0);
          final m = n.metrics;
          if ((v > 0 && m.pixels >= m.maxScrollExtent) ||
              (v < 0 && m.pixels <= m.minScrollExtent)) {
            _fling(pos, v);
          }
        }
        return false;
      },
      child: child,
    );
  }

  static void _fling(ScrollPosition pos, double velocity) {
    if (pos is ScrollPositionWithSingleContext) pos.goBallistic(velocity);
  }
}

// lib/shared/ui/hold_tip.dart
// How every tip comes and goes. Tips only carry information (a chart bar's
// amount, a heatmap day's, what a short chip's number means): a touch shows
// it above what's touched until the lift (a quick tap: all the way first),
// then it fades out slowly. Buttons get no tips (the owner, 2026-10-31: no
// tooltips as guides); their names are for screen readers only
// ([Semantics] labels).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/ink_text.dart';

/// How fast a tip comes, and how slowly it goes once the finger lifts
/// (every tip in the app; the owner, 2026-10-29).
const Duration kTipFadeIn = Duration(milliseconds: 120);
const Duration kTipFadeOut = Duration(milliseconds: 500);

/// [child] with [message] over it from the touch, in the theme's tooltip
/// look. The touch is its own: a tap on it doesn't reach what it sits in
/// (a tile's sheet doesn't open).
class HoldTip extends StatefulWidget {
  const HoldTip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<HoldTip> createState() => _HoldTipState();
}

class _HoldTipState extends State<HoldTip> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  late final _fade =
      AnimationController(
        vsync: this,
        duration: kTipFadeIn,
        reverseDuration: kTipFadeOut,
      )..addStatusListener((s) {
        if (s == AnimationStatus.dismissed) _portal.hide();
      });

  /// Where the touch came down (a finger moving on is a scroll: the tip
  /// goes).
  Offset? _down;

  void _press(PointerDownEvent e) {
    _down = e.position;
    _portal.show();
    _fade.forward();
  }

  void _move(PointerMoveEvent e) {
    final d = _down;
    if (d != null && (e.position - d).distance > kTouchSlop) _hide();
  }

  void _hide() {
    _down = null;
    // A quick tap: it comes all the way first, then goes.
    if (_fade.status == AnimationStatus.forward) {
      _fade.forward().whenCompleteOrCancel(() {
        if (mounted && _down == null) _fade.reverse();
      });
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TooltipTheme.of(context);
    return Listener(
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: (_) => _hide(),
      onPointerCancel: (_) => _hide(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            // Above it, its middle over the touched thing's middle.
            overlayChildBuilder: (context) => Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: const Offset(0, -6),
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: theme.decoration,
                      child: InkText(widget.message, style: theme.textStyle),
                    ),
                  ),
                ),
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// lib/shared/ui/keep_in_view.dart
// Something that grows (a box opening, a list unfolding) stays in view
// while it grows, frame by frame: what was tapped never slips off screen
// and comes back after (the owner, 2026-10-31: the Backup button did).
// FoldSection does the same for its sections.

import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderAnimatedSize;
import 'package:flutter/widgets.dart';

import 'package:openfinances/shared/ui/fold_section.dart'
    show FoldSectionState, kSectionAnim;

/// Scrolls the list [context] is in (if needed) so its box shows: first the
/// end that was tapped ([bottomFirst]: its bottom, for a box growing upward
/// from a button at its end; else its top), then as much of the rest as
/// fits. A jump, not an animation: it's called for every frame of a growth.
/// Not while the user is scrolling the list.
///
/// [grow]: how much taller the box is about to get, at its end, before the
/// next layout: called as the animation ticks (before the frame is laid
/// out) with what this frame adds, it lands right on every frame; called
/// after a frame, it's always a frame behind (what showed then).
/// [gapBelow]: the room to leave under its end (default a small margin).
void keepInView(
  BuildContext context, {
  bool bottomFirst = false,
  double grow = 0,
}) {
  final pos = Scrollable.maybeOf(context)?.position;
  final delta = inViewDelta(context, bottomFirst: bottomFirst, grow: grow);
  if (pos == null || delta == null) return;
  pos.jumpTo(
    (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent),
  );
}

/// How far the list [context] is in must scroll for its box to show, as
/// [keepInView] does it; null: not at all (or the user is scrolling it).
double? inViewDelta(
  BuildContext context, {
  bool bottomFirst = false,
  double grow = 0,
  double gapBelow = 8,
}) {
  if (!context.mounted) return null;
  final list = Scrollable.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  if (list == null || box == null || !box.attached) return null;
  final pos = list.position;
  if (pos.isScrollingNotifier.value) return null;
  final view = list.context.findRenderObject() as RenderBox?;
  if (view == null || !view.attached) return null;
  final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
  final bottom = top + box.size.height + grow;
  // The list may run under the bottom bar: its padding says how far.
  final visible = view.size.height - MediaQuery.paddingOf(list.context).bottom;
  const margin = 8.0;
  final double delta;
  if (bottomFirst) {
    if (bottom > visible - margin) {
      // Up far enough to show its end.
      delta = bottom - visible + margin;
    } else if (top < margin) {
      // Down to its top, but never so far its end leaves.
      delta = math.max(top - margin, bottom - visible + margin);
    } else {
      return null;
    }
  } else if (top < margin) {
    delta = top - margin; // its top is above the view's: back to it
  } else if (bottom > visible - gapBelow) {
    // Down far enough to show its end, but never past its top.
    delta = math.min(bottom - visible + gapBelow, top - margin);
  } else {
    return null;
  }
  return delta.abs() < .5 ? null : delta;
}

/// [child] brought into view when [trigger] changes to something (a day
/// picked: the owner, 2026-11-01, its preview spawned out of view): the
/// list glides there, as long as the growth that shows it. Put it inside
/// what animates its size (an [AnimatedSize]): its own box is the new size
/// at once, so the list moves along with the growth, not after it.
///
/// In a section, it's the section that comes into view, with [gapBelow] under
/// it: the section's end doesn't meet the bottom bar, and the next section
/// stays out of view (the owner, 2026-11-02: only this box was measured, so
/// the section's end landed on the bar). Short of room, its own top wins.
class KeepShown extends StatefulWidget {
  const KeepShown({
    super.key,
    required this.trigger,
    required this.child,
    this.gapBelow = 8,
  });

  final Object? trigger;
  final Widget child;
  final double gapBelow;

  @override
  State<KeepShown> createState() => _KeepShownState();
}

class _KeepShownState extends State<KeepShown> {
  @override
  void didUpdateWidget(KeepShown old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pos = Scrollable.maybeOf(context)?.position;
        final delta = inViewDelta(
          context,
          grow: _sectionBelow(),
          gapBelow: widget.gapBelow,
        );
        if (pos == null || delta == null) return;
        pos.animateTo(
          (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent),
          duration: kSectionAnim,
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  /// How far its section goes on below what's growing (measured at what
  /// animates, which is still its old size: this box is already the new one).
  double _sectionBelow() {
    final box = context.findRenderObject();
    final section = context
        .findAncestorStateOfType<FoldSectionState>()
        ?.context
        .findRenderObject();
    if (box is! RenderBox || section is! RenderBox) return 0;
    RenderObject? grows = box.parent;
    while (grows != null && grows is! RenderAnimatedSize) {
      if (identical(grows, section)) return 0;
      grows = grows.parent;
    }
    if (grows is! RenderBox) return 0;
    final end = grows.localToGlobal(Offset(0, grows.size.height));
    final sectionEnd = section.localToGlobal(Offset(0, section.size.height));
    return math.max(0.0, sectionEnd.dy - end.dy);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

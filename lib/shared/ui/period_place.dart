// lib/shared/ui/period_place.dart
// Changing the period leaves the page where it is (the owner, 2026-11-01).
// The scroll offset alone doesn't: sections above the view change height
// with the period (a heatmap of 5 or 6 weeks, more or fewer category chips),
// moving what's being read, and a shorter period pulls the page up for good.
// So the first section starting in the view stays where it stands; a period
// too short for that goes as far as it can, and the next one long enough
// comes back to the place (unless the page was moved in between). No sections
// (a plain list): the offset itself is the place. At the very top it stays at
// the top. Also when the list is gone for a period (nothing to list).
//
// It's put right DURING layout ([RememberedScroll.holdAt]), before anything
// is painted: put right after the frame, the wrong place showed for a frame
// (the owner: a bad flicker). So a section's place is read from the content
// (its distance from the content's start), not the screen, which isn't known
// yet at that moment.

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/ui/fold_section.dart';

/// [child]: the page's scroll view, driven by [controller].
class PeriodPlace extends StatefulWidget {
  const PeriodPlace({super.key, required this.controller, required this.child});

  final RememberedScroll controller;
  final Widget child;

  @override
  State<PeriodPlace> createState() => _PeriodPlaceState();
}

/// Where the page was: the offset, and the section it's held by with how far
/// down the view it stood; [cutAt]: the offset a shorter period held it at
/// (still there: this is still the place to come back to); [heldAt]: where it
/// was last put (anywhere else now: something else moved it).
class _Place {
  _Place(this.offset, this.section, this.viewTop);
  final double offset;
  final RenderBox? section;
  final double viewTop;
  double? cutAt;
  double? heldAt;
}

/// How long after a change sections may still settle (one growing by a
/// little animation) and the place is kept through it.
const Duration _kHold = Duration(milliseconds: 450);

class _PeriodPlaceState extends State<PeriodPlace> {
  late final SettingsProvider _settings;
  late int _period;
  _Place? _place;
  bool _holding = false;
  Timer? _holdEnds;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _period = _settings.periodOffset;
    _settings.addListener(_onSettings);
    _bind(widget.controller);
  }

  @override
  void didUpdateWidget(PeriodPlace old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _unbind(old.controller);
      _bind(widget.controller);
    }
  }

  void _bind(RememberedScroll c) {
    c.holdAt = _holdAt;
    c.onUserMove = _letGo;
  }

  void _unbind(RememberedScroll c) {
    c.holdAt = null;
    c.onUserMove = null;
  }

  @override
  void dispose() {
    _holdEnds?.cancel();
    _settings.removeListener(_onSettings);
    _unbind(widget.controller);
    super.dispose();
  }

  /// Heard as the period is set, before anything is built for it.
  void _onSettings() {
    if (_settings.periodOffset == _period) return;
    _period = _settings.periodOffset;
    _remember();
    _holding = true;
    _holdEnds?.cancel();
    _holdEnds = Timer(_kHold, _letGo);
  }

  /// The time's up, or the page was moved: what's left is only a place a
  /// short period cut, to come back to.
  void _letGo() {
    _holdEnds?.cancel();
    _holding = false;
    if (_place?.cutAt == null) _place = null;
  }

  /// [box]'s distance from the content's start: known once it's laid out,
  /// wherever the list stands.
  static double? _contentY(RenderBox box) {
    var top = box;
    while (true) {
      final parent = top.parent;
      if (parent is RenderSliver) {
        return parent.constraints.precedingScrollExtent +
            box.getTransformTo(top).getTranslation().y;
      }
      if (parent is RenderAbstractViewport) {
        return box.getTransformTo(top).getTranslation().y;
      }
      if (parent is! RenderBox) return null;
      top = parent;
    }
  }

  void _remember() {
    final c = widget.controller;
    if (!c.hasClients) return; // gone for a period: the place is the one before
    final p = c.position;
    final had = _place;
    // Held back by a short period and not moved since: still the one before.
    if (had?.cutAt != null && (p.pixels - had!.cutAt!).abs() < 1) {
      had.heldAt = null;
      return;
    }
    RenderBox? section;
    final view = p.context.storageContext.findRenderObject();
    if (p.pixels > p.minScrollExtent + .5 &&
        view is RenderBox &&
        view.attached &&
        view.hasSize) {
      section = _sectionInView(view);
    }
    final y = section == null ? null : _contentY(section);
    _place = _Place(
      p.pixels,
      y == null ? null : section,
      y == null ? 0 : y - p.pixels,
    );
  }

  /// The first section starting in [view] (the one ending there may be what
  /// changes height); none: the one filling it.
  RenderBox? _sectionInView(RenderBox view) {
    RenderBox? found;
    var done = false;
    void walk(Element e) {
      if (done) return;
      if (e.widget is FoldSection) {
        final box = e.renderObject;
        if (box is RenderBox && box.attached && box.hasSize) {
          final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
          if (top >= view.size.height) {
            done = true;
          } else if (top >= 0) {
            found = box;
            done = true;
          } else if (top + box.size.height > 0) {
            found = box;
          }
        }
        return; // nothing to look for inside one
      }
      e.visitChildren(walk);
    }

    context.visitChildElements(walk);
    return found;
  }

  /// Asked during every layout of the list.
  double? _holdAt(double pixels, double min, double max) {
    final place = _place;
    if (!_holding || place == null) return null;
    // Moved by something else since (a day gone to): that wins.
    if (place.heldAt != null && (pixels - place.heldAt!).abs() > .5) {
      _letGo();
      return null;
    }
    var target = place.offset;
    final box = place.section;
    if (box != null && box.attached) {
      final y = _contentY(box);
      if (y != null) target = y - place.viewTop;
    }
    final held = target.clamp(min, max).toDouble();
    place
      ..cutAt = target > max + .5 ? held : null
      ..heldAt = held;
    return held;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// lib/shared/ui/group_fit.dart
// Labels side by side shrink together: each [GroupFit] under one
// [FitGroup] is drawn at the smallest scale any of them needs to fit its
// room, so a row's words stay one size ("Toman" too long for its share in
// English no longer shrinks alone next to "Rial"; the owner, 2026-10-25).
// Alone, a [GroupFit] is a FittedBox(scaleDown): it shrinks only itself.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The labels under it ([GroupFit]) share one scale.
class FitGroup extends StatefulWidget {
  const FitGroup({super.key, required this.child});
  final Widget child;

  @override
  State<FitGroup> createState() => _FitGroupState();
}

class _FitGroupState extends State<FitGroup> {
  final _group = _Group();

  @override
  Widget build(BuildContext context) =>
      _GroupScope(group: _group, child: widget.child);
}

class _GroupScope extends InheritedWidget {
  const _GroupScope({required this.group, required super.child});
  final _Group group;

  @override
  bool updateShouldNotify(_GroupScope old) => old.group != group;
}

/// The members, and the scale they share: the smallest any needs.
class _Group {
  final _members = <_RenderGroupFit>{};

  double get scale => _members.fold(1.0, (s, m) => math.min(s, m._fit));

  /// A member's need changed (or one came or went): all draw again.
  void changed() {
    for (final m in _members) {
      if (m.attached) m.markNeedsPaint();
    }
  }
}

/// A label that shrinks (never grows) to fit its room, by its group's
/// scale ([FitGroup]) or, alone, its own; centered in its box. Its height
/// stays the label's own (rows keep theirs).
class GroupFit extends SingleChildRenderObjectWidget {
  const GroupFit({super.key, required Widget super.child});

  static _Group? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroupScope>()?.group;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGroupFit(_of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderGroupFit).group = _of(context);
}

class _RenderGroupFit extends RenderProxyBox {
  _RenderGroupFit(this._group);

  _Group? _group;
  set group(_Group? g) {
    if (g == _group) return;
    _leave();
    _group = g;
    if (attached) _join();
    markNeedsPaint();
  }

  /// What this one needs on its own (1: it fits).
  double _fit = 1;

  double get _scale => math.min(_fit, _group?.scale ?? _fit);

  void _join() {
    _group?._members.add(this);
    _group?.changed();
  }

  void _leave() {
    if (_group?._members.remove(this) ?? false) _group?.changed();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _join();
  }

  @override
  void detach() {
    _leave();
    super.detach();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    // Its own width (unbounded), within the height it's given.
    c.layout(
      BoxConstraints(maxHeight: constraints.maxHeight),
      parentUsesSize: true,
    );
    final natural = c.size;
    final room = constraints.maxWidth;
    final fit = natural.width <= 0 || !room.isFinite
        ? 1.0
        : math.min(1.0, room / natural.width);
    if (fit != _fit) {
      _fit = fit;
      _group?.changed();
    }
    size = constraints.constrain(
      Size(math.min(natural.width, room), natural.height),
    );
  }

  Matrix4 _transform() {
    final c = child!;
    final s = _scale;
    return Matrix4.translationValues(
      (size.width - c.size.width * s) / 2,
      (size.height - c.size.height * s) / 2,
      0,
    )..scaleByDouble(s, s, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform(),
      (context, offset) => context.paintChild(c, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_transform());

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintTransform(
      transform: _transform(),
      position: position,
      hitTest: (result, position) => c.hitTest(result, position: position),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;
}

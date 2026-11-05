// lib/shared/ui/scroll_hint.dart
// Boxes that scroll show it by moving, not by a half-cut row (the owner,
// 2026-10-31: a half-shown row teaches it once, then stays half-shown for
// good). Everything shows whole; a box whose content goes on, until the
// user has scrolled one of its kind by hand, scrolls a little and back the
// first time it's in view (as the month-start wheel turns a little when
// tapped). Scrolled once, by hand, that kind never does it again (kept in
// prefs: in full backups).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';

/// [child]: a scroll view driven by [controller]. [id] names its kind (one
/// scrolled by hand teaches all of them).
class ScrollHint extends StatefulWidget {
  const ScrollHint({
    super.key,
    required this.id,
    required this.controller,
    required this.child,
  });

  final String id;
  final ScrollController controller;
  final Widget child;

  /// The kinds (each its own lesson).
  static const categoryChips = 'categoryChips';
  static const ignoredChips = 'ignoredChips';
  static const dayPreview = 'dayPreview';
  static const suggestions = 'suggestions';
  static const chipsRow = 'chipsRow';
  static const colorRow = 'colorRow';
  static const menu = 'menu';
  static const periodChart = 'periodChart';
  static const dailyChart = 'dailyChart';
  static const changeLog = 'changeLog';
  static const datePicker = 'datePicker';
  static const datePickerYears = 'datePickerYears';
  static const calendarWeeks = 'calendarWeeks';

  /// How long each way takes (the wheel's step).
  static const Duration move = Duration(milliseconds: 380);

  @override
  State<ScrollHint> createState() => _ScrollHintState();
}

class _ScrollHintState extends State<ScrollHint> {
  /// Shown (or not needed) this time it's on screen.
  bool _done = false;
  bool _moving = false;
  Timer? _wait;

  /// The list it sits in (a page), heard to tell when it comes into view.
  ScrollPosition? _outer;

  @override
  void initState() {
    super.initState();
    _later();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = Scrollable.maybeOf(context)?.position;
    if (outer != _outer) {
      _outer?.removeListener(_later);
      _outer = outer?..addListener(_later);
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _outer?.removeListener(_later);
    super.dispose();
  }

  bool _queued = false;

  /// Looks once this frame is laid out (a scroll tells before layout, when
  /// it still stands where the last frame left it).
  void _later() {
    if (_queued || _done) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      _check();
    });
  }

  /// Where it's remembered (none, e.g. a widget on its own in a test: no
  /// hint).
  SettingsProvider? get _settings =>
      Provider.of<SettingsProvider?>(context, listen: false);

  bool get _learned => _settings?.scrollLearned(widget.id) ?? true;

  /// Whether it has somewhere to go (its content goes on).
  bool get _scrolls {
    final c = widget.controller;
    return c.hasClients &&
        c.positions.length == 1 &&
        c.position.hasContentDimensions &&
        c.position.maxScrollExtent > c.position.minScrollExtent + 1;
  }

  /// Most of it on screen, on the page shown.
  bool get _inView {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return false;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return false;
    final outer = _outer;
    if (outer == null) return true;
    final view = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (view is! RenderBox) return true;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    final h = box.size.height;
    // The page runs under the bottom bar: its padding says how far.
    final visible = view.size.height - MediaQuery.paddingOf(context).bottom;
    final shown = math.min(top + h, visible) - math.max(top, 0.0);
    return shown >= math.min(h * .9, visible * .7);
  }

  void _check() {
    if (_done || _wait != null || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context) || _learned) {
      _done = true;
      return;
    }
    if (!_scrolls || !_inView) return;
    // A moment after it's come into view (and still there, at rest).
    _wait = Timer(const Duration(milliseconds: 650), () {
      _wait = null;
      final outer = _outer;
      if (!mounted || _done) return;
      // The page still moving: wait for it to stop.
      if (outer != null && outer.isScrollingNotifier.value) return _check();
      if (_scrolls && _inView) _play();
    });
  }

  /// A little into what's further on, and back.
  Future<void> _play() async {
    _done = true;
    _moving = true;
    final c = widget.controller;
    final p = c.position;
    final from = p.pixels;
    final reach = math.min(56.0, p.viewportDimension * .4);
    final ahead = p.maxScrollExtent - from, behind = from - p.minScrollExtent;
    // Toward the side with more to see (from the start: on).
    final to = ahead >= behind
        ? from + math.min(reach, ahead)
        : from - math.min(reach, behind);
    await c.animateTo(
      to,
      duration: ScrollHint.move,
      curve: Curves.easeInOutCubic,
    );
    if (!_moving || !mounted || !c.hasClients) return;
    await c.animateTo(
      from,
      duration: ScrollHint.move,
      curve: Curves.easeInOutCubic,
    );
    _moving = false;
  }

  /// The user's own scroll (a drag, not the hint): learned, for good.
  bool _heard(Notification n) {
    if (n is ScrollNotification && n.depth == 0) {
      final byHand =
          (n is ScrollStartNotification && n.dragDetails != null) ||
          (n is ScrollUpdateNotification && n.dragDetails != null) ||
          (n is OverscrollNotification && n.dragDetails != null);
      if (byHand) {
        _moving = false; // the hint gives way
        _done = true;
        if (!_learned) _settings?.markScrollLearned(widget.id);
      }
    } else if (n is ScrollMetricsNotification && n.depth == 0) {
      // Its content changed (more of it, now it scrolls): look again.
      if (!_done) _later();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
    onNotification: _heard,
    child: widget.child,
  );
}

/// A [ScrollHint] with its own controller: [builder] puts it on its scroll
/// view.
class HintedScroll extends StatefulWidget {
  const HintedScroll({super.key, required this.id, required this.builder});

  final String id;
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<HintedScroll> createState() => _HintedScrollState();
}

class _HintedScrollState extends State<HintedScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollHint(
    id: widget.id,
    controller: _controller,
    child: widget.builder(context, _controller),
  );
}

// lib/shared/ui/fold_section.dart
// Sections that fold (Settings, Budget, Statistics), and scroll spots the
// app can remember (Settings > History).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// Space between a section's edges and what's inside it, everywhere.
const double kSectionInset = 11;

/// Space between the rows inside a section.
const double kSectionRowGap = 8;

/// How long a section takes to open or close.
const Duration kSectionAnim = Duration(milliseconds: 320);

/// A titled section: one box a step above what it sits on, its title on a
/// band on top ([SectionTitleBand]); tapping the title folds it to just the
/// band and opens it again. Open or closed is kept for the run, and across
/// restarts while Settings > History > "keep folds" is on ([id] names it
/// for that).
///
/// Sections side by side (in the same section, else in the same scrolling
/// list) are a group: when one opens, those that start closed
/// ([initiallyOpen] false) close (the owner's rule). Opening, it brings
/// itself into view as it grows: all of it if it fits, else its top.
class FoldSection extends StatefulWidget {
  const FoldSection({
    super.key,
    required this.id,
    required this.title,
    this.children = const [],
    this.child,
    this.initiallyOpen = false,
    this.buildClosed = false,
    this.padding = const EdgeInsets.all(kSectionInset),
    this.radius = 14,
    this.titleKey,
  }) : itemCount = null,
       itemBuilder = null;

  /// A section of many rows, as a sliver (in a [CustomScrollView]): open
  /// and still, its rows are a lazy list, built as they scroll into view
  /// (the SMS tab's hundreds of messages were all built at once, and again
  /// on every change; the owner, 2026-10-31). Opening and closing, it's
  /// the box the others are, with the rows that fit on a screen: the rest
  /// is out of sight then.
  const FoldSection.sliver({
    super.key,
    required this.id,
    required this.title,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.initiallyOpen = false,
    this.padding = const EdgeInsets.all(kSectionInset),
    this.radius = 14,
    this.titleKey,
  }) : children = const [],
       child = null,
       buildClosed = false;

  /// On its title's band (a tip about it).
  final GlobalKey? titleKey;

  /// The rows of a [FoldSection.sliver].
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;

  /// Names it for remembering its state (unique in the app).
  final String id;
  final String title;

  /// Rows, [kSectionRowGap] apart (unless [child] is given).
  final List<Widget> children;

  /// The whole body instead of [children].
  final Widget? child;

  /// Open the first time it's shown.
  final bool initiallyOpen;

  /// Builds its rows even while closed (they listen for something, e.g.
  /// a request to point at one of them); otherwise a closed section builds
  /// only its title.
  final bool buildClosed;

  /// Around the body (all sections use [kSectionInset]).
  final EdgeInsetsGeometry padding;

  /// Corners; null: square (a part at the end of a larger section).
  final double? radius;

  /// Open or closed, by section id, for this run.
  static final Map<String, bool> _session = {};

  /// Every section on screen (for [closeAll]).
  static final Set<FoldSectionState> _live = {};

  /// Closes every section whose id starts with [idPrefix] (Settings, when
  /// tips are turned on: the tour starts on a page of titles).
  static void closeAll(String idPrefix) {
    for (final s in [..._live]) {
      if (s.widget.id.startsWith(idPrefix)) s.close();
    }
  }

  /// Every section back to how it starts, at once, unless Settings >
  /// History > "keep folds" is on: called when the page changes (the
  /// owner, 2026-10-26: off, a page should come back with its defaults).
  static void resetUnlessKept(SettingsProvider settings) {
    if (settings.rememberSections) return;
    _session.clear();
    for (final s in [..._live]) {
      s._reset();
    }
  }

  /// The groups of the scrolling lists sections sit in directly.
  static final Expando<_FoldGroup> _listGroups = Expando();

  @override
  State<FoldSection> createState() => FoldSectionState();
}

class FoldSectionState extends State<FoldSection>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: kSectionAnim,
    value: _startsOpen ? 1 : 0,
  );
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  /// The siblings' group (see [FoldSection]), and the one this section is
  /// for the sections inside it.
  _FoldGroup? _group;
  final _inner = _FoldGroup();

  /// Opening: it follows itself into view each frame.
  bool _revealing = false;

  /// A sliver section's box part (its title, and its rows while it moves):
  /// what's kept in view.
  final _box = GlobalKey();
  bool get _isSliver => widget.itemBuilder != null;

  @override
  void initState() {
    super.initState();
    FoldSection._live.add(this);
    // Its rows are built from when it starts opening until it's closed.
    _c.addStatusListener((s) {
      if (s == AnimationStatus.dismissed ||
          s == AnimationStatus.forward ||
          // A sliver section: still and open, its rows go lazy; moving,
          // they're a box again.
          _isSliver) {
        if (mounted) setState(() {});
      }
      if (s == AnimationStatus.completed) {
        // Once more where it ended, then done.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reveal();
          _revealing = false;
        });
      } else if (s != AnimationStatus.forward) {
        _revealing = false;
      }
    });
    _c.addListener(() {
      if (_revealing) {
        // After this frame's layout: where it is now.
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inSection = _FoldScope.maybeOf(context);
    final list = Scrollable.maybeOf(context);
    final group =
        inSection ??
        (list == null ? null : FoldSection._listGroups[list] ??= _FoldGroup());
    if (group != _group) {
      _group?.live.remove(this);
      _group = group?..join(this);
    }
  }

  /// Scrolls its list (if needed) so the section shows: its top, and as
  /// much of the rest as fits. Not while the user is scrolling it.
  void _reveal() {
    if (!mounted || !_revealing) return;
    final list = Scrollable.maybeOf(context);
    final at = _isSliver ? _box.currentContext : context;
    final box = at?.findRenderObject() as RenderBox?;
    if (list == null || box == null || !box.attached) return;
    final pos = list.position;
    if (pos.isScrollingNotifier.value) return;
    final view = list.context.findRenderObject() as RenderBox?;
    if (view == null || !view.attached) return;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    final bottom = top + box.size.height;
    // The list may run under the bottom bar: its padding says how far.
    final visible =
        view.size.height - MediaQuery.paddingOf(list.context).bottom;
    const margin = 8.0;
    final double delta;
    if (top < margin) {
      delta = top - margin; // its top is at or above the view's: back to it
    } else if (bottom > visible - margin) {
      // Down far enough to show its end, but never past its top.
      delta = math.min(bottom - visible + margin, top - margin);
    } else {
      return;
    }
    if (delta.abs() < .5) return;
    pos.jumpTo(
      (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent),
    );
  }

  /// Starts opening: the group's start-closed sections close, and this one
  /// keeps itself in view as it grows.
  void _opening() {
    _remember(true);
    _group?.opened(this);
    _revealing = true;
  }

  /// Back to its default (open or closed), without animating.
  void _reset() {
    if (!mounted) return;
    _revealing = false;
    _c.value = widget.initiallyOpen ? 1 : 0;
  }

  /// Closes it (if open), as a tap on its title would.
  void close() {
    _revealing = false;
    if (_c.value > 0 && _c.status != AnimationStatus.reverse) {
      _remember(false);
      _c.reverse();
    }
  }

  bool get _startsOpen =>
      FoldSection._session[widget.id] ??
      context.read<SettingsProvider>().sectionOpen(widget.id) ??
      widget.initiallyOpen;

  void _remember(bool open) {
    FoldSection._session[widget.id] = open;
    context.read<SettingsProvider>().saveSectionOpen(widget.id, open);
  }

  /// Opens it (if closed); resolves once it's open.
  Future<void> open() async {
    if (_c.value < 1) {
      _opening();
      await _c.forward();
    }
  }

  void _toggle() {
    if (_c.value <= .5) {
      _opening();
      _c.forward();
    } else {
      close();
    }
  }

  @override
  void dispose() {
    FoldSection._live.remove(this);
    _group?.live.remove(this);
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _isSliver ? _buildSliver(context) : _buildBox(context);

  Widget _buildSliver(BuildContext context) {
    final n = widget.itemCount!;
    final r = Radius.circular(widget.radius ?? 0);
    final still = _c.isCompleted;
    // Moving (or closed): the rows that fit on a screen (none is under
    // 40 dp), in the box.
    final shown = still
        ? 0
        : math.min(n, (MediaQuery.sizeOf(context).height / 40).ceil() + 1);
    final head = KeyedSubtree(
      key: _box,
      child: ClipRRect(
        borderRadius: still
            ? BorderRadius.vertical(top: r)
            : BorderRadius.all(r),
        child: SurfaceBox(
          radius: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: widget.titleKey,
                child: SectionTitleBand(widget.title, onTap: _toggle),
              ),
              if (!still)
                SizeTransition(
                  sizeFactor: _curve,
                  alignment: AlignmentDirectional.topCenter,
                  child: FadeTransition(
                    opacity: _curve,
                    child: _c.isDismissed
                        ? const SizedBox(width: double.infinity)
                        : _FoldScope(
                            group: _inner,
                            child: Padding(
                              padding: widget.padding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < shown; i++) ...[
                                    if (i > 0)
                                      const SizedBox(height: kSectionRowGap),
                                    widget.itemBuilder!(context, i),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!still) return SliverToBoxAdapter(child: head);
    // Open and still: the title, then the rows on the section's tone, its
    // lower corners rounded, as the box was.
    final level = SurfaceDepth.of(context) + 1;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: head),
        DecoratedSliver(
          decoration: BoxDecoration(
            color: surfaceTone(Theme.of(context).colorScheme, level),
            borderRadius: BorderRadius.vertical(bottom: r),
          ),
          sliver: SliverPadding(
            padding: widget.padding,
            sliver: SurfaceDepth(
              depth: level,
              child: _FoldScope(
                group: _inner,
                child: SliverList.separated(
                  itemCount: n,
                  itemBuilder: widget.itemBuilder!,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: kSectionRowGap),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // A paint layer of its own: scrolling the page moves it whole, nothing in it
  // is drawn again (the owner, 2026-11-01: scrolling lagged).
  Widget _buildBox(BuildContext context) => RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius ?? 0),
      child: SurfaceBox(
        radius: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(
              key: widget.titleKey,
              child: SectionTitleBand(widget.title, onTap: _toggle),
            ),
            SizeTransition(
              sizeFactor: _curve,
              alignment: AlignmentDirectional.topCenter,
              child: FadeTransition(
                opacity: _curve,
                child: _c.isDismissed && !widget.buildClosed
                    ? const SizedBox(width: double.infinity)
                    : _FoldScope(
                        group: _inner,
                        child: Padding(
                          padding: widget.padding,
                          child:
                              widget.child ??
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = 0;
                                    i < widget.children.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const SizedBox(height: kSectionRowGap),
                                    widget.children[i],
                                  ],
                                ],
                              ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Sections side by side ([FoldSection]): who's in it now, and every id
/// that has been, with whether it starts closed (one scrolled out of its
/// list and disposed still closes, by its remembered state).
class _FoldGroup {
  final Set<FoldSectionState> live = {};
  final Map<String, bool> _startsClosed = {};

  void join(FoldSectionState s) {
    live.add(s);
    _startsClosed[s.widget.id] = !s.widget.initiallyOpen;
  }

  /// [s] is opening: the others that start closed close.
  void opened(FoldSectionState s) {
    final shown = {for (final o in live) o.widget.id: o};
    for (final MapEntry(key: id, value: startsClosed)
        in _startsClosed.entries) {
      if (!startsClosed || id == s.widget.id) continue;
      final o = shown[id];
      if (o != null) {
        if (o.mounted) o.close();
      } else if (FoldSection._session[id] ?? false) {
        FoldSection._session[id] = false;
        s.context.read<SettingsProvider>().saveSectionOpen(id, false);
      }
    }
  }
}

/// The group the sections inside a section belong to.
class _FoldScope extends InheritedWidget {
  const _FoldScope({required this.group, required super.child});
  final _FoldGroup group;

  static _FoldGroup? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FoldScope>()?.group;

  @override
  bool updateShouldNotify(_FoldScope old) => old.group != group;
}

/// A scroll controller for the scrollable [id]: it starts where that one
/// was left and saves where it stops, while Settings > History > "keep
/// place" is on. Dispose it like any controller.
class RememberedScroll extends ScrollController {
  RememberedScroll(this.id, SettingsProvider settings)
    : _settings = settings,
      super(initialScrollOffset: settings.scrollOffset(id)) {
    _live.add(this);
  }

  final String id;
  final SettingsProvider _settings;
  Timer? _save;

  /// Asked during each layout of the list, with where it stands and how far
  /// it can go: where it should stand instead (null: where it is). Put right
  /// there, before anything is painted ([PeriodPlace]).
  double? Function(double pixels, double min, double max)? holdAt;

  /// The user took hold of the list.
  VoidCallback? onUserMove;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _HeldPosition(
    this,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );

  /// Every one in use (for [toTopUnlessKept]).
  static final Set<RememberedScroll> _live = {};

  /// Every list back to its top, at once, unless Settings > History >
  /// "keep place" is on: called when the page changes (the owner,
  /// 2026-10-26: off, a page should come back at its top).
  static void toTopUnlessKept(SettingsProvider settings) {
    if (settings.rememberScroll) return;
    for (final c in _live) {
      for (final p in [...c.positions]) {
        p.jumpTo(p.minScrollExtent);
      }
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_settings.rememberScroll || !hasClients) return;
    // Saved once it settles (not on every frame of a fling).
    _save?.cancel();
    final at = offset;
    _save = Timer(
      const Duration(milliseconds: 400),
      () => _settings.saveScrollOffset(id, at),
    );
  }

  @override
  void dispose() {
    _live.remove(this);
    _save?.cancel();
    super.dispose();
  }
}

/// A [RememberedScroll]'s position: it asks [RememberedScroll.holdAt] when
/// the viewport tells it the content's size, the moment a viewport can still
/// lay out again within the same frame.
class _HeldPosition extends ScrollPositionWithSingleContext {
  _HeldPosition(
    this._owner, {
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final RememberedScroll _owner;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final hold = _owner.holdAt;
    var moved = false;
    if (hold != null && hasPixels) {
      final want = hold(pixels, minScrollExtent, maxScrollExtent);
      if (want != null && (want - pixels).abs() > .5) {
        // Before the sizes are taken in: never seen out of range, so no
        // spring back starts.
        correctPixels(want);
        moved = true;
        // Those following the list hear of it once the frame is done.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_owner.positions.contains(this)) notifyListeners();
        });
      }
    }
    final applied = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    // False: a viewport lays its content out again at the new place.
    return applied && !moved;
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    _owner.onUserMove?.call();
    return super.drag(details, dragCancelCallback);
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    _owner.onUserMove?.call();
    return super.hold(holdCancelCallback);
  }
}

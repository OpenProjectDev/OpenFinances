// lib/shared/ui/category_legend.dart
// The chips under a chart of categories (Statistics' pie, Budget's total
// bar): each a box in the category's color (a checkbox: tapped, it leaves
// the chart), its name and its percentage, one chip a row, the biggest share
// first (the owner, 2026-10-28; it was balanced pairs in a shuffled order).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/scroll_chain.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/split_chip.dart';
import 'package:openfinances/shared/ui/percent_text.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// Each of [values]' share of their sum in tenths of a percent, adding up
/// to exactly 1000 (100.0%): the remainders go to the largest leftovers, and
/// a value above 0 never shows 0.0 (rounding each alone could add up to 98).
List<int> shareTenths(List<int> values) {
  final total = values.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return [for (final _ in values) 0];
  final exact = [for (final v in values) v * 1000 / total];
  final out = [
    for (var i = 0; i < values.length; i++)
      values[i] > 0 ? math.max(1, exact[i].floor()) : 0,
  ];
  var left = 1000 - out.fold<int>(0, (a, b) => a + b);
  // By leftover: the largest get the tenths still to give; the smallest
  // (above their floor of 1) give back any taken by the floors.
  final order = [for (var i = 0; i < values.length; i++) i]
    ..sort((a, b) => (exact[b] - out[b]).compareTo(exact[a] - out[a]));
  // (A value above 0 is always in [order]; total > 0 means one is.)
  while (left > 0) {
    for (final i in order) {
      if (left == 0) break;
      if (values[i] > 0) {
        out[i]++;
        left--;
      }
    }
  }
  while (left < 0) {
    var gave = false;
    for (final i in order.reversed) {
      if (left == 0) break;
      if (out[i] > 1) {
        out[i]--;
        left++;
        gave = true;
      }
    }
    if (!gave) break; // more categories than tenths: can't happen
  }
  return out;
}

/// The chips of [gids] (the chart's order). A chip: its box + name at its
/// start, its percentage ([tenths]; none while it's off the chart) at its
/// end on a lighter step of its own (as the debt sheet's split rows' words;
/// the owner, 2026-10-26), the percent icon after the number. Touched, it lights up ([touched], [onTouch]: its part of the chart
/// does too). Its box is a checkbox: tapped (only the box), the category
/// leaves the chart ([off], [onToggle]: the box empties to its outline, the
/// chip greys) or comes back.
///
/// One chip a row, the width of the row: the name takes what the percentage
/// leaves (a name too long takes a second line). Sorted by share, the
/// biggest first, by [layoutTenths] (as if all were on, so a box tapped
/// doesn't shuffle the chips; the same share keeps the chart's order).
///
/// Many chips (the owner, 2026-10-30: a long list pushed the next section
/// far down, and the chart off screen while its chips were read): past
/// [_maxRows] they sit in a box [_maxRows] whole rows tall (no half row:
/// [ScrollHint] shows that it scrolls) that scrolls on its own and hands
/// the drag (and a fling) on to the page at its ends ([ScrollChain]). A part of the chart touched
/// scrolls its chip into the box's middle (unless it's already in view),
/// lit.
class CategoryLegend extends StatefulWidget {
  const CategoryLegend({
    super.key,
    required this.gids,
    required this.tenths,
    required this.layoutTenths,
    required this.colorOf,
    required this.nameOf,
    required this.off,
    required this.onToggle,
    required this.touched,
    required this.onTouch,
    this.pinned,
  });

  final List<String> gids;
  final List<int?> tenths;
  final List<int> layoutTenths;
  final Color Function(String gid, int index) colorOf;
  final String Function(String gid) nameOf;
  final Set<String> off;
  final ValueChanged<String> onToggle;

  /// The chip lit (an index into [gids]; -1: none).
  final int touched;

  /// A chip touched (its index) or let go (-1).
  final ValueChanged<int> onTouch;

  /// A chip always on top, whatever its share (Budget's "Remaining").
  final String? pinned;

  static const _hPad = 9.0, _dot = 18.0, _gapDot = 7.0, _height = 38.0;
  static const _gap = 8.0;
  static const _pctStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );

  /// Up to this many chips show whole; more, and they're in a box.
  static const _maxRows = 6;

  @override
  State<CategoryLegend> createState() => _CategoryLegendState();
}

class _CategoryLegendState extends State<CategoryLegend> {
  final _scroll = ScrollController();
  final _content = GlobalKey();
  final _keys = <String, GlobalKey>{};

  /// The chip lit by a touch on itself (not the chart's), and where that
  /// touch came down: one that moves on is a scroll, not a touch.
  int _own = -1;
  Offset? _downAt;

  /// The percentages' width, and the text size and style it's for.
  double _pctWidth = 0;
  Object? _pctKey;

  @override
  void didUpdateWidget(CategoryLegend old) {
    super.didUpdateWidget(old);
    final i = widget.touched;
    // Only a touch on the chart brings its chip into view (one on a chip
    // would scroll the box out from under the finger, and stop its drag).
    if (i >= 0 && i != old.touched && i != _own && i < widget.gids.length) {
      final gid = widget.gids[i];
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(gid));
    }
  }

  void _let() {
    if (_downAt == null && _own < 0) return;
    _downAt = null;
    _own = -1;
    widget.onTouch(-1);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// [gid]'s chip into the box's middle, unless it's whole in view already
  /// (a chip touched itself is; the page itself never moves for it).
  void _reveal(String gid) {
    if (!mounted || !_scroll.hasClients) return;
    final chip = _keys[gid]?.currentContext?.findRenderObject() as RenderBox?;
    final content = _content.currentContext?.findRenderObject() as RenderBox?;
    if (chip == null || content == null || !chip.attached) return;
    final top = chip.localToGlobal(Offset.zero, ancestor: content).dy;
    final h = chip.size.height;
    final p = _scroll.position;
    final view = p.viewportDimension;
    // Never while the box is being scrolled.
    if (p.userScrollDirection != ScrollDirection.idle) return;
    if (top >= p.pixels && top + h <= p.pixels + view) return;
    _scroll.animateTo(
      (top - (view - h) / 2).clamp(p.minScrollExtent, p.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final gids = w.gids, tenths = w.tenths, off = w.off, touched = w.touched;
    final scheme = Theme.of(context).colorScheme;
    bool isOn(int i) => !off.contains(gids[i]);

    // Every chip's percentage end as wide as the widest a share can be
    // ("100", or a two-digit one with its decimal), so they line up (the
    // owner, 2026-10-26); a chip off the chart keeps the room, empty.
    // Measured once for the text's size and style (a touch rebuilds the
    // chips: no need to lay nine numbers out again).
    final pctKey = (
      MediaQuery.textScalerOf(context),
      DefaultTextStyle.of(context).style,
    );
    if (pctKey != _pctKey) {
      _pctKey = pctKey;
      _pctWidth =
          2 * CategoryLegend._hPad +
          [
            for (final t in const [
              1000,
              999,
              888,
              777,
              666,
              555,
              444,
              333,
              222,
            ])
              PercentText.widthOf(context, t, CategoryLegend._pctStyle),
          ].reduce(math.max).ceilToDouble();
    }
    final pctWidth = _pctWidth;
    Widget chip(int i) {
      final on = isOn(i);
      final selected = on && i == touched;
      final color = w.colorOf(gids[i], i);
      final faint = scheme.onSurfaceVariant.withValues(alpha: .45);
      // A touch that starts on the box isn't the chip's (the box's own
      // listener sees it first).
      var onBox = false;
      final box = Listener(
        onPointerDown: (_) => onBox = true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => w.onToggle(gids[i]),
          child: Container(
            width: CategoryLegend._dot,
            height: CategoryLegend._dot,
            decoration: BoxDecoration(
              color: on ? color : Colors.transparent,
              border: on ? null : Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
      // Lit from the touch itself until the finger lifts, exactly like its
      // part of the chart.
      return Listener(
        onPointerDown: (e) {
          if (!onBox && on) {
            _own = i;
            _downAt = e.position;
            w.onTouch(i);
          }
          onBox = false;
        },
        // A touch that moves on is a scroll: the chip (and its part of
        // the chart) goes out.
        onPointerMove: (e) {
          final d = _downAt;
          if (d != null && (e.position - d).distance > kTouchSlop) {
            _downAt = null;
            _own = -1;
            w.onTouch(-1);
          }
        },
        onPointerUp: (_) => _let(),
        onPointerCancel: (_) => _let(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CategoryLegend._height),
          // Its parts as tall as the chip (a long name takes two lines),
          // a little apart.
          child: SplitChip(
            parts: [
              // Its box and name, the row's spare room after the name; a
              // name too long for its room takes a second line.
              Expanded(
                child: Container(
                  color: selected
                      ? scheme.primary.withValues(alpha: .15)
                      : scheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CategoryLegend._hPad,
                  ),
                  child: Row(
                    children: [
                      box,
                      const SizedBox(width: CategoryLegend._gapDot),
                      Expanded(
                        child: InkText(
                          w.nameOf(gids[i]),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: !on
                                ? faint
                                : selected
                                ? context.primaryInk
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Its percentage on a lighter step.
              Container(
                width: pctWidth,
                alignment: Alignment.center,
                color: selected
                    ? scheme.primary.withValues(alpha: .25)
                    : surfaceTone(scheme, 3),
                child: tenths[i] == null
                    ? null
                    : PercentText(
                        tenths[i]!,
                        style: CategoryLegend._pctStyle.copyWith(
                          color: selected
                              ? context.primaryInk
                              : scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    final order = [for (var i = 0; i < gids.length; i++) i]
      ..sort((a, b) {
        final pa = gids[a] == w.pinned, pb = gids[b] == w.pinned;
        if (pa != pb) return pa ? -1 : 1;
        final c = w.layoutTenths[b].compareTo(w.layoutTenths[a]);
        return c != 0 ? c : a.compareTo(b);
      });

    final list = Column(
      key: _content,
      children: [
        for (var r = 0; r < order.length; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : CategoryLegend._gap),
            child: SizedBox(
              key: _keys.putIfAbsent(gids[order[r]], GlobalKey.new),
              width: double.infinity,
              child: chip(order[r]),
            ),
          ),
      ],
    );
    if (order.length <= CategoryLegend._maxRows) return list;
    return SizedBox(
      height:
          CategoryLegend._maxRows *
              (CategoryLegend._height + CategoryLegend._gap) -
          CategoryLegend._gap,
      // At its ends, the drag (and a fling's speed) goes on in the page.
      child: ScrollHint(
        id: ScrollHint.categoryChips,
        controller: _scroll,
        child: ScrollChain(
          child: SingleChildScrollView(
            controller: _scroll,
            // Its ends tell the page (a bounce would keep the drag).
            physics: const ClampingScrollPhysics(),
            child: list,
          ),
        ),
      ),
    );
  }
}

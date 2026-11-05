// lib/shared/ui/joined_menu.dart
// A button whose menu opens joined to it (the category pickers, the Budget
// sort field).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/scroll_hint.dart';

/// A button with a menu joined to it: as wide, no gap, no shadow, and the
/// corners where they meet square, so the two read as one piece. The menu
/// lists only the choices other than the shown one: picking the shown one is
/// a tap on the button, which closes the menu.
///
/// Rows are all [rowHeight] tall, so the menu's height is known before it
/// opens, and so is the side it opens on (below the button if it fits, else
/// above). A list too long to show whole shows as many whole rows as fit
/// and shows that it scrolls by moving a little ([ScrollHint]; no half
/// row); opening above, the list runs upward (its first row next to the
/// button).
class JoinedMenu extends StatefulWidget {
  const JoinedMenu({
    super.key,
    required this.rowCount,
    required this.rows,
    required this.button,
    this.background,
    this.radius = 12,
    this.rowHeight = 48,
    this.maxHeight = 290,
    this.onOpen,
  });

  /// How many rows [rows] gives (none: the button doesn't open).
  final int rowCount;

  /// The menu's rows (each gets [rowHeight]); [close] closes it.
  final List<Widget> Function(VoidCallback close) rows;

  /// The button, with its corners ([radius], square where the open menu
  /// meets it) and what a tap does ([toggle]).
  final Widget Function(
    BuildContext context,
    BorderRadius radius,
    VoidCallback toggle,
  )
  button;

  /// Behind the rows (rows that fill themselves don't show it).
  final Color? background;
  final double radius;

  /// Every row's height.
  final double rowHeight;

  /// At most this tall; longer lists scroll.
  final double maxHeight;

  /// Called as the menu opens.
  final VoidCallback? onOpen;

  @override
  State<JoinedMenu> createState() => _JoinedMenuState();
}

class _JoinedMenuState extends State<JoinedMenu> {
  final _ctrl = MenuController();
  final _anchorKey = GlobalKey();
  double _width = 0;

  /// While open: whether the menu sits above the button (null: closed).
  bool? _up;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWidth());
  }

  @override
  void didUpdateWidget(covariant JoinedMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWidth());
  }

  Rect? _globalRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _updateWidth() {
    final w = _globalRect(_anchorKey)?.width ?? 0;
    if (w > 0 && w != _width && mounted) setState(() => _width = w);
  }

  /// The menu's height: every row if they fit, else as many whole rows as
  /// fit.
  double get _menuHeight {
    final h = widget.rowHeight;
    final all = widget.rowCount * h;
    if (all <= widget.maxHeight) return all;
    return math.max(1, (widget.maxHeight / h).floor()) * h;
  }

  /// The side MenuAnchor puts the menu on: below the button if it fits
  /// there, else above if it fits there. (Its overlay sees the whole
  /// window: the system bars and the keyboard are left out.)
  bool _opensUp() {
    final button = _globalRect(_anchorKey);
    if (button == null) return false;
    final view = MediaQueryData.fromView(View.of(context));
    final room = view.padding.deflateRect(
      view.viewInsets.deflateRect(Offset.zero & view.size),
    );
    final h = _menuHeight;
    if (button.bottom + h <= room.bottom) return false;
    return button.top - h >= room.top;
  }

  void _toggle() {
    if (_ctrl.isOpen) {
      _ctrl.close();
      return;
    }
    if (widget.rowCount == 0) return;
    widget.onOpen?.call();
    _updateWidth();
    setState(() => _up = _opensUp());
    _ctrl.open();
  }

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(widget.radius);
    final up = _up;
    final buttonRadius = up == null
        ? BorderRadius.all(r)
        : up
        ? BorderRadius.vertical(bottom: r)
        : BorderRadius.vertical(top: r);
    final menuRadius = up == true
        ? BorderRadius.vertical(top: r)
        : BorderRadius.vertical(bottom: r);
    final height = _menuHeight;

    return MenuAnchor(
      controller: _ctrl,
      onClose: () {
        if (mounted && _up != null) setState(() => _up = null);
      },
      style: MenuStyle(
        // No shadow: it fell on the button and darkened its color.
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStatePropertyAll(
          widget.background ?? Theme.of(context).colorScheme.surface,
        ),
        maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
        // Rows run to the menu's edges.
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: menuRadius),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: _width,
          height: height,
          child: Builder(
            builder: (context) {
              final rows = widget.rows(_ctrl.close);
              return HintedScroll(
                id: ScrollHint.menu,
                builder: (context, scroll) => ListView.builder(
                  // Its own scrolling (not the page's primary controller).
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  // Above the button: the first row next to it, the list
                  // running up (its far end away from the button).
                  reverse: up == true,
                  itemExtent: widget.rowHeight,
                  itemCount: rows.length,
                  itemBuilder: (_, i) => rows[i],
                ),
              );
            },
          ),
        ),
      ],
      builder: (context, _, _) => KeyedSubtree(
        key: _anchorKey,
        child: widget.button(context, buttonRadius, _toggle),
      ),
    );
  }
}

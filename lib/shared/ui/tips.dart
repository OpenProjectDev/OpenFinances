// lib/shared/ui/tips.dart
// Tips (off by default; the first page and Settings > Personalization turn
// them on): a small card by what it's about, the page left as it is, one at a
// time, a little point toward what it's about; any touch sends it away and goes
// on to the page as usual (the owner, 2026-11-04: the blurred tour with its
// buttons, and then tinting the target, were too much). Each shows once,
// when what it's about is in view (Settings turning tips on shows them all
// again), the page never moved for one.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/ink_text.dart';

/// One tip: what it says and where to press ([targets]' widgets, a point toward
/// each; none: about the page, in the middle of the screen).
class Tip {
  const Tip(this.id, this.targets, this.text, {this.overBar = false});

  /// Remembered once shown (prefs), never shown again.
  final String id;
  final List<GlobalKey> targets;
  final String Function(AppLocalizations l) text;

  /// Its target is in the bottom bar (anywhere else, under the bar isn't in
  /// view).
  final bool overBar;
}

/// Every tip in the app (its id): once all have been seen, tips turn off.
/// A new tip goes here too.
const kTipIds = [
  'history.welcome',
  'history.period',
  'history.cards',
  'add',
  'history.tiles',
  'history.chips',
  'budget.noBudget',
  'stats.sections',
];

/// How often a page looks for a tip to show, while it has any left. Looking is
/// next to nothing, and sees everything alike: a first entry, a chips row, a
/// section scrolled to.
const Duration _kLookEvery = Duration(milliseconds: 400);

/// The tip showing, in the whole app: one at a time.
OverlayEntry? _showing;

/// Around a page (or a tab of one): while it's the one in view (its tickers on,
/// its route on top) and tips are on, shows [tips] as their targets come into
/// view, in order.
class TipsTrigger extends StatefulWidget {
  const TipsTrigger({
    super.key,
    required this.tips,
    required this.child,
    this.delay = const Duration(milliseconds: 350),
  });

  final List<Tip> Function() tips;
  final Widget child;

  /// How long after the page comes into view its first tip comes (the home
  /// page waits longer: the app has just opened).
  final Duration delay;

  @override
  State<TipsTrigger> createState() => _TipsTriggerState();
}

class _TipsTriggerState extends State<TipsTrigger> {
  Timer? _wait, _looking;
  OverlayEntry? _mine;

  void _start() {
    if (_wait != null || _looking != null) return;
    _wait = Timer(widget.delay, () {
      _wait = null;
      _look();
      _looking = Timer.periodic(_kLookEvery, (_) => _look());
    });
  }

  void _stop() {
    _wait?.cancel();
    _wait = null;
    _looking?.cancel();
    _looking = null;
  }

  /// Where [key]'s widget is, if it's wholly in view.
  Rect? _inView(Tip tip, GlobalKey key) {
    final target = key.currentContext;
    final box = target?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final at = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(context);
    var top = media.padding.top, bottom = media.size.height;
    if (!tip.overBar) {
      // The bottom bar's own height (this page's padding says it).
      bottom -= math.max(media.padding.bottom, kBottomNavigationBarHeight);
      final view = Scrollable.maybeOf(target!)?.context.findRenderObject();
      if (view is RenderBox && view.attached && view.hasSize) {
        final area = view.localToGlobal(Offset.zero) & view.size;
        top = math.max(top, area.top);
        bottom = math.min(bottom, area.bottom);
      }
    }
    return at.top >= top && at.bottom <= bottom ? at : null;
  }

  void _look() {
    if (!mounted || _showing != null) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final sp = context.read<SettingsProvider>();
    final waiting = [
      for (final t in widget.tips())
        if (!sp.tipSeen(t.id)) t,
    ];
    if (waiting.isEmpty) return _stop();
    for (final tip in waiting) {
      if (tip.targets.isEmpty) return _show(sp, tip, const []);
      // Those there: a filtered History has one of its two cards.
      final at = [for (final key in tip.targets) ?_inView(tip, key)];
      if (at.isNotEmpty) return _show(sp, tip, at);
    }
  }

  void _show(SettingsProvider sp, Tip tip, List<Rect> at) {
    sp.markTipSeen(tip.id);
    final text = tip.text(AppLocalizations.of(context)!);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TipCard(
        text: text,
        at: at,
        onGone: () {
          _remove(entry);
          // Every tip seen: tips turn themselves off.
          if (kTipIds.every(sp.tipSeen)) sp.setTipsOn(false);
        },
      ),
    );
    _showing = _mine = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (_showing == entry) _showing = null;
    if (_mine == entry) _mine = null;
  }

  @override
  void dispose() {
    _stop();
    if (_mine case final entry?) _remove(entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = context.select<SettingsProvider, bool>((s) => s.tipsOn);
    if (on && TickerMode.valuesOf(context).enabled) {
      _start();
    } else {
      _stop();
    }
    return widget.child;
  }
}

/// The tip, by [at] (where to press): over it or under it, on the side with
/// room, a little point toward each; touches go through to the page and send it
/// away.
class _TipCard extends StatefulWidget {
  const _TipCard({required this.text, required this.at, required this.onGone});
  final String text;
  final List<Rect> at;
  final VoidCallback onGone;

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  bool _leaving = false;

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _fade.reverse();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _leave(),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: Semantics(
            liveRegion: true,
            label: widget.text,
            child: FadeTransition(
              opacity: _fade,
              // The theme's text for what's in it (above any Material, text
              // comes out in the app's error style: red, underlined in yellow).
              child: Material(
                type: MaterialType.transparency,
                child: Builder(builder: _parts),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _parts(BuildContext context) {
    const side = 16.0, pointH = 9.0, pointW = 18.0, gap = 2.0;
    const padX = 14.0, padY = 10.0;
    // Solid (the owner, 2026-11-04: a tint of the page read as see-through): a
    // deeper shade of the theme's color, as in the color itself the card melted
    // into what's that color (History's and Statistics' total cards).
    final primary = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
    final color = primary
        .withLightness(
          primary.lightness > .3
              ? primary.lightness * .62
              : primary.lightness + .25,
        )
        .toColor();
    final style = TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: onColor(color),
    );
    final screen = MediaQuery.sizeOf(context);

    final widest = math.min(screen.width - 2 * side, 320.0);
    final (lines, textW) = _balanced(context, style, widest - 2 * padX);
    final width = textW + 2 * padX;

    final card = SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padX, vertical: padY),
          child: InkText(lines, textAlign: TextAlign.center, style: style),
        ),
      ),
    );

    if (widget.at.isEmpty) return Center(child: card);
    final at = widget.at.reduce((a, b) => a.expandToInclude(b));
    // Under it when it's in the top half, else over it; a point toward each.
    final below = at.center.dy < screen.height / 2;
    final left = (at.center.dx - width / 2)
        .clamp(side, math.max(side, screen.width - side - width))
        .toDouble();
    return Stack(
      children: [
        for (final target in widget.at)
          Positioned(
            left: (target.center.dx - pointW / 2)
                .clamp(
                  left + 12,
                  math.max(left + 12, left + width - 12 - pointW),
                )
                .toDouble(),
            width: pointW,
            height: pointH + 1,
            top: below ? at.bottom + gap : at.top - gap - pointH - 1,
            child: CustomPaint(
              painter: _Point(color: color, up: below),
            ),
          ),
        Positioned(
          left: left,
          top: below ? at.bottom + gap + pointH : null,
          bottom: below ? null : screen.height - at.top + gap + pointH,
          child: card,
        ),
      ],
    );
  }

  /// The tip's text in as many lines as it needs at [most], those lines evened
  /// out (no word or two left alone on the last), with no line ending in a mark
  /// ([tipLines]); and how wide that is.
  (String, double) _balanced(
    BuildContext context,
    TextStyle style,
    double most,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textWidthBasis: TextWidthBasis.longestLine,
    );
    int linesAt(double w) {
      painter.layout(maxWidth: w);
      return painter.computeLineMetrics().length;
    }

    final count = linesAt(most);
    var low = 0.0, high = most;
    for (var i = 0; i < 10; i++) {
      final mid = (low + high) / 2;
      if (linesAt(mid) == count) {
        high = mid;
      } else {
        low = mid;
      }
    }
    painter.layout(maxWidth: high);
    final lines = <String>[];
    for (var at = 0; at < widget.text.length;) {
      final line = painter.getLineBoundary(TextPosition(offset: at));
      if (line.end <= at) break;
      lines.add(widget.text.substring(line.start, line.end));
      at = line.end;
    }
    final shown = tipLines(lines);
    painter
      ..text = TextSpan(
        text: shown,
        style: DefaultTextStyle.of(context).style.merge(style),
      )
      ..layout();
    final width = painter.width.ceilToDouble() + 2;
    painter.dispose();
    return (shown, math.min(width, most));
  }
}

/// [lines] as one text, none ending in a period, a comma or the like, in either
/// language (the owner, 2026-11-04: only between words on a line).
String tipLines(Iterable<String> lines) => lines
    .map((l) => l.trim().replaceFirst(RegExp(r'[.,;:،؛]+$'), ''))
    .join('\n');

/// The card's little point, toward its target, its tip rounded.
class _Point extends CustomPainter {
  const _Point({required this.color, required this.up});
  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, mid = w / 2;
    // [f]: how far from the tip, as a share of the height.
    double y(double f) => up ? f * h : h - f * h;
    const round = .3;
    canvas.drawPath(
      Path()
        ..moveTo(0, y(1))
        ..lineTo(mid - mid * round, y(round))
        ..quadraticBezierTo(mid, y(0), mid + mid * round, y(round))
        ..lineTo(w, y(1))
        ..close(),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_Point old) => old.color != color || old.up != up;
}

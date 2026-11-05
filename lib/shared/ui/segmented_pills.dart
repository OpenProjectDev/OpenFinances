import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/group_fit.dart';

/// A choice: equal-width options in one track (a step above the box it
/// sits in), the selected one tinted with the primary color, the rest with
/// no fill of their own. One object, so a row of choices (tabs, modes)
/// never looks like a row of content tiles (chips, rows), which stand
/// apart, each on its own tile.
///
/// Only for options of which ONE is picked (the owner's rule): settings
/// that are each on or off by themselves are [ToggleChips].
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.verticalPadding = 10,
    this.radius = 999,
    this.icons = const {},
    this.attention,
    this.attentionOn,
    this.slide = true,
  });

  /// Its tint slides from option to option (false: the picked one just
  /// tints, e.g. the language, whose change flips the row).
  final bool slide;

  /// value → label, in display order.
  final Map<T, String> options;

  /// The picked option (null, when [T] allows it: none yet).
  final T? selected;

  bool _isOn(T v) => v == selected;

  /// 0..1: how red the options are (pulsed to say "pick one here").
  final Animation<double>? attention;

  /// Only this option turns red with [attention] (it's then red even when
  /// selected); null: every unselected one.
  final T? attentionOn;

  /// [base] reddened (or turned [to]) by [attention].
  static Color attentionColor(
    Color base,
    Animation<double>? attention, [
    Color to = kStrongRed,
  ]) => attention == null || attention.value == 0
      ? base
      : Color.lerp(base, to, attention.value * .9)!;
  final ValueChanged<T> onChanged;
  final double verticalPadding;

  /// Corner radius; the default is a full pill.
  final double radius;

  /// Optional icon per value, shown before the label.
  final Map<T, Widget> icons;

  /// Background of a selected option or a toggle that's on (the only thing
  /// that changes when selected: text and icons keep their color), over
  /// [base] (the track's tone; by default a tile's).
  static Color selectedColor(ColorScheme scheme, [Color? base]) =>
      Color.alphaBlend(
        scheme.primary.withValues(alpha: .32),
        base ?? scheme.surfaceContainerHigh,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = options.entries.toList();
    // The track: one step above whatever box the row sits in.
    final base = context.raised;
    // Options inside it, as far from its edge as from each other.
    const inset = 3.0;
    final inner = radius > inset ? radius - inset : radius;

    // The tint is one piece that slides to the option picked (or, without
    // [slide], the option tints itself).
    final single = slide;
    final at = single ? entries.indexWhere((e) => e.key == selected) : -1;

    // Built inside the animation's builder (when there is one), so the
    // attention color follows it.
    // The track around [child]: pulsed red as a whole ("pick one here"),
    // unless one option is.
    Widget track(Widget child) => Container(
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: attentionOn == null ? attentionColor(base, attention) : base,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    Widget content() =>
        // The sliding tint is painted at whatever width the row gets (no
        // LayoutBuilder: rows sized to their content, e.g. in Settings, ask
        // for intrinsic sizes, which it can't give).
        Builder(
          builder: (context) {
            return Stack(
              children: [
                if (at >= 0)
                  Positioned.fill(
                    // Its own layer: the slide repaints only the tint.
                    child: RepaintBoundary(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: at.toDouble()),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        builder: (context, p, _) => CustomPaint(
                          painter: _ThumbPainter(
                            at: p,
                            count: entries.length,
                            gap: inset,
                            radius: inner,
                            color: selectedColor(scheme, base),
                            rtl:
                                Directionality.of(context) == TextDirection.rtl,
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(width: inset),
                      Expanded(
                        child: Material(
                          color:
                              attentionOn != null &&
                                  entries[i].key == attentionOn
                              ? attentionColor(
                                  _isOn(entries[i].key)
                                      ? selectedColor(scheme, base)
                                      : base,
                                  attention,
                                )
                              : _isOn(entries[i].key) && !single
                              ? selectedColor(scheme, base)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(inner),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(inner),
                            onTap: () => onChanged(entries[i].key),
                            child: Padding(
                              // Text never reaches the rounded ends; as tall as a
                              // tile with [verticalPadding] (the track adds the rest).
                              padding: EdgeInsets.symmetric(
                                vertical: verticalPadding - inset,
                                horizontal: 12,
                              ),
                              child: IconTheme.merge(
                                data: IconThemeData(color: scheme.onSurface),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (icons[entries[i].key]
                                        case final icon?) ...[
                                      icon,
                                      const SizedBox(width: 8),
                                    ],
                                    // A label too long for its share shrinks a little
                                    // rather than losing its end or its margins.
                                    Flexible(
                                      child: GroupFit(
                                        child: InkText(
                                          entries[i].value,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        );
    // The labels shrink together (one size across the row).
    Widget row() => FitGroup(child: track(content()));

    final a = attention;
    return a == null
        ? row()
        // Only the track pulses: the options are built once.
        : attentionOn == null
        ? AnimatedBuilder(
            animation: a,
            builder: (_, child) => track(child!),
            child: content(),
          )
        : AnimatedBuilder(animation: a, builder: (_, _) => row());
  }
}

/// The selected option's tint, [at] options from the start (fractions: on
/// its way), as wide as one option.
class _ThumbPainter extends CustomPainter {
  const _ThumbPainter({
    required this.at,
    required this.count,
    required this.gap,
    required this.radius,
    required this.color,
    required this.rtl,
  });
  final double at, gap, radius;
  final int count;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = (size.width - gap * (count - 1)) / count;
    final start = at * (w + gap);
    final left = rtl ? size.width - start - w : start;
    canvas.drawRRect(
      RRect.fromLTRBR(left, 0, left + w, size.height, Radius.circular(radius)),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.at != at ||
      old.count != count ||
      old.color != color ||
      old.rtl != rtl ||
      old.radius != radius;
}

/// Settings that are each on or off by themselves (several can be on): a
/// row of equal chips standing apart, each on its own tile a step above the
/// box, tinted while on ([SegmentedPills.selectedColor]). Not one track: a
/// track is a choice of ONE ([SegmentedPills]), and these aren't.
class ToggleChips<T> extends StatelessWidget {
  const ToggleChips({
    super.key,
    required this.options,
    required this.on,
    required this.onTap,
    this.verticalPadding = 10,
    this.radius = 999,
    this.attention,
    this.attentionOn,
    this.attentionTo = kStrongRed,
  });

  /// value → label, in display order.
  final Map<T, String> options;

  /// The ones that are on.
  final Set<T> on;

  /// A chip was tapped (its value); the caller flips it.
  final ValueChanged<T> onTap;
  final double verticalPadding;
  final double radius;

  /// 0..1: how red the chips are (pulsed to say "this one").
  final Animation<double>? attention;

  /// Only this chip turns red with [attention]; null: every chip that's off.
  final T? attentionOn;

  /// The color [attention] turns it (red; green for "it worked").
  final Color attentionTo;

  /// Between two chips.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = context.raised;
    final entries = options.entries.toList();

    Widget chip(MapEntry<T, String> e) {
      final isOn = on.contains(e.key);
      final rest = isOn ? SegmentedPills.selectedColor(scheme, base) : base;
      final pulses =
          attention != null &&
          (attentionOn != null ? e.key == attentionOn : !isOn);
      // (While pulsing it follows the pulse frame by frame: no easing.)
      Widget box(Color color, {bool ease = true}) => AnimatedContainer(
        duration: ease ? const Duration(milliseconds: 200) : Duration.zero,
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        // A label too long for its share shrinks a little rather than
        // losing its end or its margins.
        child: GroupFit(
          child: InkText(
            e.value,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: scheme.onSurface,
            ),
          ),
        ),
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(e.key),
        child: pulses
            ? AnimatedBuilder(
                animation: attention!,
                builder: (_, _) => box(
                  SegmentedPills.attentionColor(rest, attention, attentionTo),
                  ease: false,
                ),
              )
            : box(rest),
      );
    }

    // The labels shrink together (one size across the row).
    return FitGroup(
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(child: chip(entries[i])),
          ],
        ],
      ),
    );
  }
}

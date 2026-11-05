// lib/shared/ui/surfaces.dart
// One ladder of background tones, so nested boxes always stand apart.
//
// Level 0 is the page (colorScheme.surface), level 1 a tile or pill on it
// (surfaceContainerHigh), and every level above that is one clear step
// further (lighter in dark mode, darker in light mode). The theme's
// surfaceContainerHighest is level 2 (see main.dart), so a pill inside a
// tile already stands out.
//
// A box that holds other tiles (a Settings section, the budget categories)
// is a [SurfaceBox]: it paints its own level and tells everything inside
// that they sit on it ([SurfaceDepth]), so their tiles and pills
// ([BuildContext.raised]) come out one step above it instead of blending in.

import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/ink_text.dart';

/// The tone at [level] (fractions sit between two levels).
Color surfaceTone(ColorScheme s, double level) {
  if (level <= 0) return s.surface;
  if (level <= 1) return Color.lerp(s.surface, s.surfaceContainerHigh, level)!;
  final step = s.brightness == Brightness.dark ? .06 : .05;
  return Color.alphaBlend(
    s.onSurface.withValues(alpha: (step * (level - 1)).clamp(0, 1)),
    s.surfaceContainerHigh,
  );
}

/// How deep in boxes this part of the tree sits (0: on the page).
class SurfaceDepth extends InheritedWidget {
  const SurfaceDepth({super.key, required this.depth, required super.child});
  final double depth;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SurfaceDepth>()?.depth ?? 0;

  @override
  bool updateShouldNotify(SurfaceDepth old) => old.depth != depth;
}

extension SurfaceTones on BuildContext {
  /// What this widget sits on.
  Color get surfaceHere =>
      surfaceTone(Theme.of(this).colorScheme, SurfaceDepth.of(this));

  /// For a tile, pill or chip placed here: one step above [surfaceHere].
  Color get raised => raisedBy(1);

  /// [steps] above [surfaceHere].
  Color raisedBy(double steps) =>
      surfaceTone(Theme.of(this).colorScheme, SurfaceDepth.of(this) + steps);
}

/// A box [steps] above where it sits (rounded, no border); its [child]
/// sits on it, so tiles inside come out one step higher still.
class SurfaceBox extends StatelessWidget {
  const SurfaceBox({
    super.key,
    required this.child,
    this.steps = 1,
    this.padding = EdgeInsets.zero,
    this.radius = 14,
  });

  final Widget child;
  final double steps;
  final EdgeInsetsGeometry padding;

  /// Corners; null: square (a part of a larger box).
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final level = SurfaceDepth.of(context) + steps;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceTone(Theme.of(context).colorScheme, level),
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      ),
      child: SurfaceDepth(depth: level, child: child),
    );
  }
}

/// A section's title on its own band, a step above the section it heads
/// (Settings, Budget and Statistics sections): bold, centered, with the
/// same air above and below it. A closed section is just this band.
class SectionTitleBand extends StatelessWidget {
  /// Just the title: never a count or anything after it (the owner's rule).
  const SectionTitleBand(this.title, {super.key, this.onTap});
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    // As tall in both languages (Persian, drawn by a fallback font, makes
    // a taller line: 65 against 63), its title in the middle; taller only
    // for large system text.
    child: Container(
      color: context.raised,
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: InkText(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
  );
}

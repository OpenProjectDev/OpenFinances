// lib/shared/ui/split_chip.dart
// A chip in parts (the owner, 2026-10-27): its parts a little apart, square
// where they meet and round only at the chip's own ends, so they read as
// parts of one chip, everywhere in the app. Progress bars aren't chips:
// their segments stand apart, each with rounded corners.

import 'package:flutter/material.dart';

/// The gap between a chip's parts.
const double kPartGap = 2;

/// [parts] side by side (each paints its own tone; sized by the caller:
/// Expanded, a width), [kPartGap] apart; the chip's outer corners round
/// ([radius]), the ones where parts meet square. Each part as tall as the
/// tallest, or [height].
class SplitChip extends StatelessWidget {
  const SplitChip({
    super.key,
    required this.parts,
    this.radius = 12,
    this.height,
  });

  final List<Widget> parts;
  final double radius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: kPartGap),
          parts[i],
        ],
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: height == null
          ? IntrinsicHeight(child: row)
          : SizedBox(height: height, child: row),
    );
  }
}

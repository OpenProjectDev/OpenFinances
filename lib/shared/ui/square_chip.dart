// lib/shared/ui/square_chip.dart
// A square button with an icon, and a row with one before what fills it
// (Settings' theme color and lock squares, the first page's theme color).

import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// [child] filling the row, with a square as tall as it before it.
class SquareRow extends StatelessWidget {
  const SquareRow({super.key, required this.child, required this.leading});
  final Widget child;
  final Widget leading;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: 1, child: leading),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    ),
  );
}

/// A square button with an icon: tinted when [selected] (like a chosen
/// pill), else a step above the section; [color] overrides both.
class SquareChip extends StatelessWidget {
  const SquareChip({
    super.key,
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.selected = false,
    this.color,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String tooltip;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = context.raised;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          // A quick fade between states (e.g. saved → idle).
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color:
                color ??
                (selected ? SegmentedPills.selectedColor(scheme, base) : base),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: IconTheme.merge(
            data: const IconThemeData(size: 24),
            child: child,
          ),
        ),
      ),
    );
  }
}

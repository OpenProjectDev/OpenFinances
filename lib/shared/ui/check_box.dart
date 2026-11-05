// lib/shared/ui/check_box.dart
// The app's checkbox (onboarding's privacy and tips rows, a due payment's
// Record chip).

import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/app_icons.dart';

/// A squircle: an outline while off, filled with [color] and its check
/// ([checkColor]) while on.
class CheckBoxMark extends StatelessWidget {
  const CheckBoxMark({
    super.key,
    required this.on,
    required this.color,
    required this.checkColor,
    required this.outline,
  });

  final bool on;
  final Color color, checkColor, outline;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: on ? color : Colors.transparent,
      border: on ? null : Border.all(color: outline, width: 2.5),
      borderRadius: BorderRadius.circular(7),
    ),
    child: on
        ? Center(child: ImageIcon(AppIcons.check, size: 13, color: checkColor))
        : null,
  );
}

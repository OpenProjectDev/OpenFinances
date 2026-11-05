// lib/shared/ui/tile_pill.dart
// The pill of a list row (History, Upcoming, Debts): a category, a date,
// a side; one height everywhere, so a row's parts line up.

import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/split_chip.dart';

class TilePill extends StatelessWidget {
  const TilePill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });
  final String text;
  final Color background;
  final Color foreground;

  static const _padding = 12.0;
  static const _style = TextStyle(fontSize: 12.5, height: 1.2);

  /// How wide a pill of [text] is (to choose what fits a row).
  static double widthOf(BuildContext context, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(_style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return tp.width + 2 * _padding;
  }

  @override
  Widget build(BuildContext context) => Container(
    // At least 28 tall; a long name takes a second line (never cut).
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    // Hugs its text (an aligned Container would fill the row).
    child: Center(
      widthFactor: 1,
      child: InkText(text, style: _style.copyWith(color: foreground)),
    ),
  );
}

/// A due date and how long is left, one pill of two tones (the owner,
/// 2026-10-29; they were two pills): the date on [dateTone], the days on
/// [leftTone] (a step lighter, or the status color once due). [fill]: the
/// row's whole width, each part half of it (a row of its own: no empty
/// room beside it).
class DuePill extends StatelessWidget {
  const DuePill({
    super.key,
    required this.date,
    required this.left,
    required this.dateTone,
    required this.leftTone,
    required this.dateInk,
    required this.leftInk,
    this.fill = false,
  });

  final String date, left;
  final Color dateTone, leftTone, dateInk, leftInk;
  final bool fill;

  /// How wide it is unfilled (to choose what fits a row).
  static double widthOf(BuildContext context, String date, String left) =>
      TilePill.widthOf(context, date) +
      kPartGap +
      TilePill.widthOf(context, left);

  @override
  Widget build(BuildContext context) {
    Widget part(String text, Color tone, Color ink) {
      final box = Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(
          horizontal: TilePill._padding,
          vertical: 4,
        ),
        color: tone,
        child: Center(
          widthFactor: fill ? null : 1,
          child: InkText(text, style: TilePill._style.copyWith(color: ink)),
        ),
      );
      return fill ? Expanded(child: box) : box;
    }

    final chip = SplitChip(
      radius: 8,
      parts: [part(date, dateTone, dateInk), part(left, leftTone, leftInk)],
    );
    return fill ? SizedBox(width: double.infinity, child: chip) : chip;
  }
}

// lib/shared/ui/dual_chip.dart
// Two values in one chip, a chip beside it saying what they are (Budget's
// tiles, partly paid debts): "Spent" with "4,778,000 / 14,000,000" and
// "Remaining" with "9,222,000 | 65.9%", two tones a little apart along a
// slanted or straight cut (square there: one chip; lib/shared/ui/split_chip.dart).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/split_chip.dart';

/// One row's content: its word ([label]) and its two values, the first on
/// the first tone, the second on the second; [slant]: the tones meet along
/// a "/" (a fraction), else a straight edge. [direction]: which way the
/// values run (a fraction: left to right in both languages).
class DualChipData {
  const DualChipData({
    required this.label,
    required this.first,
    required this.firstWidth,
    required this.second,
    required this.secondWidth,
    required this.slant,
    required this.direction,
  });

  final String label;
  final Widget first, second;

  /// The values' own widths (a value wider than [DualChipRow.widest] widens
  /// the chips, never cut).
  final double firstWidth, secondWidth;
  final bool slant;
  final TextDirection direction;
}

/// Rows under something (a bar), one a row (the owner, 2026-10-26): its
/// word on a chip of its own, centered, and its two values on a chip of two
/// tones. The value chips are one fixed width, sized for the biggest
/// numbers ([widest]), so they don't change from tile to tile; the word
/// chips take the rest of the row, so they're one width too, and one height
/// (a word too long for its room takes a second line on both). Every other
/// row the two swap ends, so the value chips don't sit right under each
/// other. Never shrunk, never cut.
class DualChipRow extends StatelessWidget {
  const DualChipRow({
    super.key,
    required this.chips,
    required this.firstTone,
    required this.secondTone,
    required this.labelStyle,
    required this.widest,
  });

  final List<DualChipData> chips;
  final Color firstTone, secondTone;
  final TextStyle labelStyle;

  /// The width of the biggest value the chips are sized for
  /// ([widestMinor], formatted as the values are).
  final double widest;

  /// The biggest amount the value chips are sized for, in minor units.
  static const int widestMinor = 999999999900;

  /// As tall as the edit square beside it.
  static const double height = 30;
  static const double _pad = 9, _slant = 8, _gap = 8, _vPad = 6;

  /// How far a "/" cut leans (to line other chips up with its ends).
  static const double slant = _slant;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(labelStyle);
    TextPainter painter(String t, [double max = double.infinity]) =>
        TextPainter(
          text: TextSpan(text: t, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: max);
    // Each value part: the widest value with the same air both sides, the
    // slant's half more where they meet; every part alike. A value a hair
    // wider than [widest] (another digit can be wider than 9) takes from its
    // air instead, so every tile's chips stay one width.
    final value = [
      widest,
      for (final c in chips) ...[c.firstWidth - _pad, c.secondWidth - _pad],
    ].reduce(math.max);
    final part = (_pad + value + _pad + _slant / 2).ceilToDouble();
    // The longest piece of a word that can't break.
    final piece = [
      for (final c in chips)
        for (final w in c.label.split(RegExp(r'\s+'))) painter(w).width,
    ].fold(0.0, math.max).ceilToDouble();

    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth;
        // No room for the words beside the values: each on a row of its
        // own, the values' two parts sharing the row.
        final beside = room - 2 * part - _gap >= piece + 2 * _pad;
        final wordWidth = beside ? room - 2 * part - _gap : room;
        final h = [
          height,
          for (final c in chips)
            painter(c.label, wordWidth - 2 * _pad).height + 2 * _vPad,
        ].reduce(math.max).ceilToDouble();
        Widget word(DualChipData c) => Container(
          width: wordWidth,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: _pad),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: firstTone,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkText(
            c.label,
            style: labelStyle,
            textAlign: TextAlign.center,
          ),
        );
        Widget values(DualChipData c) => _DualChip(
          data: c,
          part: beside ? part : room / 2,
          height: h,
          firstTone: firstTone,
          secondTone: secondTone,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              if (!beside) ...[
                word(chips[i]),
                const SizedBox(height: _gap),
                values(chips[i]),
              ] else
                Row(
                  children: i.isEven
                      ? [
                          word(chips[i]),
                          const SizedBox(width: _gap),
                          values(chips[i]),
                        ]
                      : [
                          values(chips[i]),
                          const SizedBox(width: _gap),
                          word(chips[i]),
                        ],
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One [DualChipData]'s two-tone chip alone, the width of its row (its
/// word, [DualChipData.label], isn't shown): Budget's tile (the owner,
/// 2026-10-28: only "spent / budget" is left under the bar).
class DualValueChip extends StatelessWidget {
  const DualValueChip({
    super.key,
    required this.data,
    required this.firstTone,
    required this.secondTone,
    this.radius = _kRadius,
  });

  final DualChipData data;
  final Color firstTone, secondTone;

  /// Its corners: square where it meets another chip (Debts' paid rows).
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _DualChip(
      data: data,
      part: box.maxWidth / 2,
      height: DualChipRow.height,
      firstTone: firstTone,
      secondTone: secondTone,
      radius: radius,
    ),
  );
}

const BorderRadius _kRadius = BorderRadius.all(Radius.circular(8));

class _DualChip extends StatelessWidget {
  const _DualChip({
    required this.data,
    required this.part,
    required this.height,
    required this.firstTone,
    required this.secondTone,
    this.radius = _kRadius,
  });

  final BorderRadius radius;

  final DualChipData data;

  /// Each of its two parts' width.
  final double part, height;
  final Color firstTone, secondTone;

  @override
  Widget build(BuildContext context) {
    final cut = data.slant ? DualChipRow._slant : 0.0;
    return Directionality(
      textDirection: data.direction,
      child: CustomPaint(
        painter: _DualPainter(
          split: part,
          cut: cut,
          rtl: data.direction == TextDirection.rtl,
          first: firstTone,
          second: secondTone,
          radius: radius,
        ),
        child: SizedBox(
          width: 2 * part,
          height: height,
          child: Row(
            children: [
              // Each value in the middle of its part, clear of the edge.
              SizedBox(
                width: part,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: cut / 2),
                  child: Center(child: data.first),
                ),
              ),
              SizedBox(
                width: part,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: cut / 2),
                  child: Center(child: data.second),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DualPainter extends CustomPainter {
  _DualPainter({
    required this.split,
    required this.cut,
    required this.rtl,
    required this.first,
    required this.second,
    required this.radius,
  });

  final BorderRadius radius;

  /// The first part's width, from the start side; [cut]: how far the edge
  /// leans (0: straight).
  final double split, cut;
  final bool rtl;
  final Color first, second;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRRect(radius.toRRect(Offset.zero & size));
    // The cut's middle, and a "/" through it (its top further right); the
    // parts [kPartGap] apart along it.
    final c = rtl ? size.width - split : split;
    final half = cut / 2, g = kPartGap / 2;
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(c + half - g, 0)
      ..lineTo(c - half - g, size.height)
      ..lineTo(0, size.height)
      ..close();
    final right = Path()
      ..moveTo(c + half + g, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(c - half + g, size.height)
      ..close();
    canvas.drawPath(left, Paint()..color = rtl ? second : first);
    canvas.drawPath(right, Paint()..color = rtl ? first : second);
  }

  @override
  bool shouldRepaint(_DualPainter old) =>
      old.split != split ||
      old.cut != cut ||
      old.rtl != rtl ||
      old.first != first ||
      old.second != second ||
      old.radius != radius;
}

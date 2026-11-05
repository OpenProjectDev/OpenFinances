// lib/shared/ui/percent_text.dart
// A percentage as the app shows it: its number and the percent icon (the
// owner's, not a font's % sign) after it.

import 'package:flutter/material.dart';

import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/ink_text.dart';

/// [tenths] as a number with one decimal ("57.1", «۵۷.۱»), none when it's
/// .0 ("57"). The decimal point is a dot on the baseline in both languages
/// (the owner, 2026-10-26: «٫» read as a slash); a Persian zero is a dot
/// too, but in the middle of the line, so the two don't meet.
String tenthsText(int tenths, bool fa) => uiDigits(
  tenths % 10 == 0 ? '${tenths ~/ 10}' : '${tenths ~/ 10}.${tenths % 10}',
  fa,
);

/// [tenths] of a percent and the percent icon after it, left to right in
/// both languages (as "57.1%" and «۵۷.۱٪» read): the icon as tall as the
/// digits' ink (all ten of the digits in use, so a Persian zero, a mere
/// dot, doesn't shrink it), so centered on the line it also stands on the
/// digits' bottom; a clear gap between them.
class PercentText extends StatelessWidget {
  const PercentText(this.tenths, {super.key, required this.style});

  final int tenths;
  final TextStyle style;

  static const double gap = 4;

  /// The icon's image is 95% ink (488 of 512 px).
  static const double _inkShare = 488 / 512;

  static double _iconSize(BuildContext context, TextStyle s) {
    final ink = InkMetrics.instance.inkHeight(
      uiDigits('0123456789', isFaUi(context)),
      s,
      MediaQuery.textScalerOf(context),
    );
    return ink == null ? (s.fontSize ?? 14) * .72 : ink / _inkShare;
  }

  /// How wide it is (to measure a row by).
  static double widthOf(BuildContext context, int tenths, TextStyle style) {
    final full = DefaultTextStyle.of(context).style.merge(style);
    final number = tenthsText(tenths, isFaUi(context));
    final tp = TextPainter(
      text: TextSpan(text: number, style: full),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return tp.width + gap + _iconSize(context, full);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Sized once the font's ink is measured (the first frame may not have
    // it).
    listenable: InkMetrics.instance,
    builder: (context, _) {
      final full = DefaultTextStyle.of(context).style.merge(style);
      final number = tenthsText(tenths, isFaUi(context));
      return Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          InkText(number, style: style),
          const SizedBox(width: gap),
          ImageIcon(
            AppIcons.percent,
            size: _iconSize(context, full),
            color: full.color,
          ),
        ],
      );
    },
  );
}

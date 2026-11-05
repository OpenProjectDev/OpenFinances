// lib/shared/digits.dart
// Which digits the app writes numbers in: English (0123), unless the user
// picks Persian (۰۱۲۳; Settings > Personalization, shown only in Persian: the
// owner, 2026-11-03; in English the digits are English, and the choice comes
// back with Persian).
// Every place that turns 0-9 into ۰-۹ asks [faDigitsFor], and
// the widgets that do depend on [DigitsScope] (through isFaUi) so they
// rewrite their numbers when the choice changes (the owner, 2026-10-28: the
// Upcoming total stayed in Persian digits until it was rebuilt by other
// means).

import 'package:flutter/widgets.dart';

/// The digits numbers are written in.
enum DigitStyle {
  /// ۰۱۲۳.
  persian,

  /// 0123 (the default).
  english,
}

/// The digits in effect (SettingsProvider keeps it in step with its pref and
/// the language).
DigitStyle appDigitStyle = DigitStyle.english;

/// The order of a date's parts (Settings > Personalization; the owner,
/// 2026-11-04). [standard], the default, is how the app always wrote them:
/// the day first in words (3 Nov 2026), the year first in numbers (2026/11/03).
/// The others hold for both.
enum DateOrder { standard, dmy, mdy, ymd }

/// The current choice (SettingsProvider keeps it in step with its pref).
DateOrder appDateOrder = DateOrder.standard;

/// Whether numbers are written in Persian digits ([faUi], the UI language,
/// no longer matters here: [appDigitStyle] has already taken it in).
bool faDigitsFor(bool faUi) => appDigitStyle == DigitStyle.persian;

/// The digit choice, for widgets to depend on: when it changes, whoever
/// called [watch] is rebuilt (a const subtree isn't, by its parent).
class DigitsScope extends InheritedWidget {
  const DigitsScope({
    super.key,
    required this.style,
    this.order = DateOrder.standard,
    required super.child,
  });
  final DigitStyle style;

  /// Dates are written by whoever writes digits: they're rebuilt for this too.
  final DateOrder order;

  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DigitsScope>();

  @override
  bool updateShouldNotify(DigitsScope old) =>
      old.style != style || old.order != order;
}

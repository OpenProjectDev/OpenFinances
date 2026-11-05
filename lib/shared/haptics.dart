// lib/shared/haptics.dart
// A touch felt (the owner, 2026-11-01): a light tap for the "000" and
// clear buttons, a firmer one when something's wrong (an error notice, a
// field to fill or a choice to make, shown in red). Settings >
// Personalization turns it off (on by default).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';

abstract final class Haptics {
  static bool _on(BuildContext context) =>
      Provider.of<SettingsProvider?>(context, listen: false)?.hapticsOn ?? true;

  /// A button that changes what's typed ("000", clear).
  static void tap(BuildContext context) {
    if (_on(context)) HapticFeedback.lightImpact();
  }

  /// Something's wrong or missing (shown in red).
  static void alert(BuildContext context) {
    if (_on(context)) HapticFeedback.heavyImpact();
  }
}

// lib/shared/sheet_drafts.dart
// What was entered in an add sheet that was closed without saving, kept for
// the next time it opens (Settings > History > "keep entries"; on by
// default). Kept in memory only: an app restart starts afresh.

import 'package:openfinances/data/settings_provider.dart';

abstract final class SheetDrafts {
  static final Map<String, Map<String, Object?>> _kept = {};

  /// The values left in add sheet [sheet] last time (null: none, or the
  /// setting is off).
  static Map<String, Object?>? of(SettingsProvider settings, String sheet) =>
      settings.rememberEntries ? _kept[sheet] : null;

  /// The add sheet [sheet] closed without saving: keeps [values] when
  /// something was entered ([changed]), else forgets the old draft.
  static void closed(
    SettingsProvider settings,
    String sheet, {
    required bool changed,
    required Map<String, Object?> values,
  }) {
    if (changed && settings.rememberEntries) {
      _kept[sheet] = values;
    } else {
      _kept.remove(sheet);
    }
  }

  /// Saved: the draft is done with.
  static void saved(String sheet) => _kept.remove(sheet);
}

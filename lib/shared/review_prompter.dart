import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPrompter {
  static const _kCountKey = 'xp_saves_count';
  static const _kLastPromptKey = 'xp_last_prompt_ms';
  static const _kMinDaysBetween = 7; // cool-down in days
  static const _thresholds = [5, 15, 30, 60, 120]; // ask at these milestones

  static Future<void> bumpAndMaybePrompt() async {
    if (!kReleaseMode) return; // never show in debug/profile
    final sp = await SharedPreferences.getInstance();

    final nextCount = (sp.getInt(_kCountKey) ?? 0) + 1;
    await sp.setInt(_kCountKey, nextCount);

    if (!_thresholds.contains(nextCount)) return;

    final lastMs = sp.getInt(_kLastPromptKey);
    if (lastMs != null) {
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
          .inDays;
      if (days < _kMinDaysBetween) return;
    }

    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await sp.setInt(_kLastPromptKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {
      // silently ignore any review errors
    }
  }

  /// Optional manual "Rate the app" action (e.g., Settings button)
  static Future<void> openStorePage() async {
    try {
      await InAppReview.instance.openStoreListing(); // Play Store
    } catch (_) {}
  }
}

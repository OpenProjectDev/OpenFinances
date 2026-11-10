// lib/shared/ui/privacy_sheet.dart
// The privacy policy, short: what the app keeps, where, and why it asks
// for notification access (the first page's "I've read the privacy
// policy" opens it in a sheet; Settings > About has it in a fold). Every
// line must stay true: the app has no INTERNET permission
// (AndroidManifest.xml), keeps everything in its own storage, and its
// notification listener (BankNotificationListener.kt) reads only messaging
// apps' notifications, keeping only bank transactions.

import 'package:flutter/material.dart';

import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/ink_text.dart';

/// Shows the privacy sheet, in [context]'s theme: true when it was closed
/// with its button ("Got it": read).
Future<bool> showPrivacySheet(BuildContext context) async {
  final theme = Theme.of(context);
  // The status bar's height, from here: a sheet doesn't see it.
  final top = MediaQuery.paddingOf(context).top;
  final read = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Theme(
      data: theme,
      child: _PrivacySheet(top: top),
    ),
  );
  return read == true;
}

/// The policy's parts, each a heading and its text (no title: the sheet
/// and the fold give it theirs).
class PrivacyPolicyText extends StatelessWidget {
  const PrivacyPolicyText({super.key, this.english = false});

  /// In English whatever the app's language (About is all English).
  final bool english;

  @override
  Widget build(BuildContext context) {
    final l = english
        ? lookupAppLocalizations(const Locale('en'))
        : AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      (l.privacyOfflineTitle, l.privacyOffline),
      (l.privacyDataTitle, l.privacyData),
      (l.privacyBackupsTitle, l.privacyBackups),
      (l.privacyBankTitle, l.privacyBank),
      (l.privacyUpdatesTitle, l.privacyUpdates),
      (l.privacyLockTitle, l.privacyLock),
      (l.privacyRatingTitle, l.privacyRating),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (head, body)) in parts.indexed) ...[
          if (i > 0) const SizedBox(height: 18),
          InkText(
            head,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet({required this.top});

  /// The status bar's height: the sheet stops under it.
  final double top;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    // As tall as its text, up to the whole screen under the status bar;
    // past that, its text scrolls (the button stays).
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height - top),
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkText(
                      l.privacyTitle,
                      style: const TextStyle(
                        fontSize: kSheetTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const PrivacyPolicyText(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + media.viewPadding.bottom,
              ),
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: InkText(l.privacyOk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

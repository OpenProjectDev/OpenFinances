// lib/features/settings/licenses_page.dart
// Settings > About > Open-source licenses: every package the app is built
// with, as chips in two columns; a chip opens its license text. English and
// the Manrope font throughout (the licenses are English).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';

/// The About section's font, whatever the app's language or font choice.
const kAboutFont = 'ManropeNum';

/// The licenses Flutter collected from the packages, by package. They're
/// in the app itself (Flutter bundles them at build time, ~1.4 MB of text;
/// nothing is fetched), read once per run: [preloadLicenses] starts it
/// before the page is opened.
Future<Map<String, List<LicenseEntry>>> preloadLicenses() =>
    _licensesOnce ??= _byPackage().then(
      (m) => _licensesRead = m,
      // Tried again next time.
      onError: (Object e) {
        _licensesOnce = null;
        throw e;
      },
    );
Future<Map<String, List<LicenseEntry>>>? _licensesOnce;

/// Once read: shown at once (no spinner frame).
Map<String, List<LicenseEntry>>? _licensesRead;

Future<Map<String, List<LicenseEntry>>> _byPackage() async {
  final out = <String, List<LicenseEntry>>{};
  var n = 0;
  await for (final e in LicenseRegistry.licenses) {
    for (final p in e.packages) {
      (out[p] ??= []).add(e);
    }
    // Let the app draw (the spinner, touches) between batches: reading
    // them all in one go froze it, worst in a debug build.
    if (++n % 25 == 0) await Future<void>.delayed(Duration.zero);
  }
  return out;
}

/// English, left to right, in [kAboutFont].
Widget aboutText(BuildContext context, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: DefaultTextStyle.merge(
    style: const TextStyle(fontFamily: kAboutFont),
    child: child,
  ),
);

class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key, required this.navIndex});
  final int navIndex;

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<Map<String, List<LicenseEntry>>> _licenses =
      preloadLicenses();

  Widget _reopen(BuildContext _) => LicensesPage(navIndex: widget.navIndex);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: InkText(
          'Licenses',
          style: text.titleLarge?.copyWith(fontFamily: kAboutFont),
        ),
        leading: IconButton(
          icon: const Icon(UIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        selected: widget.navIndex,
        onTab: (i) => goToMainTab(context, i, reopen: _reopen),
        onAdd: () => showAddEditTransactionSheet(context: context),
      ),
      body: FutureBuilder(
        future: _licenses,
        initialData: _licensesRead,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return Center(
              child: snap.hasError
                  ? InkText(
                      "The licenses couldn't be read",
                      style: TextStyle(
                        fontFamily: kAboutFont,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : const CircularProgressIndicator(),
            );
          }
          // The app's own first, then the rest by name.
          final names = data.keys.toList()
            ..sort((a, b) {
              if ((a == 'OpenFinances') != (b == 'OpenFinances')) {
                return a == 'OpenFinances' ? -1 : 1;
              }
              return a.toLowerCase().compareTo(b.toLowerCase());
            });
          return aboutText(
            context,
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  // Centered, one sentence a line (like About's).
                  child: InkText(
                    'OpenFinances is built with these packages\n'
                    'Tap one to read its license',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      fontFamily: kAboutFont,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Two columns of equal chips, one height a row (a long name
                // takes two lines: its neighbor grows with it, no gap under it;
                // the owner, 2026-11-03).
                for (var r = 0; r < names.length; r += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = r; c < r + 2; c++) ...[
                            if (c > r) const SizedBox(width: 8),
                            Expanded(
                              child: c < names.length
                                  ? _PackageChip(
                                      name: names[c],
                                      count: data[names[c]]!.length,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _LicenseTextPage(
                                            package: names[c],
                                            entries: data[names[c]]!,
                                            navIndex: widget.navIndex,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A package: its name, and how many license texts it has.
class _PackageChip extends StatelessWidget {
  const _PackageChip({
    required this.name,
    required this.count,
    required this.onTap,
  });
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkText(
              // A long name breaks after an underscore, not mid-word.
              name.replaceAll('_', '_\u200B'),
              style: TextStyle(
                fontFamily: kAboutFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            InkText(
              count == 1 ? '1 license' : '$count licenses',
              style: TextStyle(
                fontFamily: kAboutFont,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One package's license texts, each in its own box.
class _LicenseTextPage extends StatelessWidget {
  const _LicenseTextPage({
    required this.package,
    required this.entries,
    required this.navIndex,
  });
  final String package;
  final List<LicenseEntry> entries;
  final int navIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = TextStyle(
      fontFamily: kAboutFont,
      fontSize: 12.5,
      height: 1.5,
      color: scheme.onSurface,
    );
    return Scaffold(
      appBar: AppBar(
        title: InkText(
          package,
          style: text.titleLarge?.copyWith(fontFamily: kAboutFont),
        ),
        leading: IconButton(
          icon: const Icon(UIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        selected: navIndex,
        onTab: (i) => goToMainTab(
          context,
          i,
          reopen: (_) => _LicenseTextPage(
            package: package,
            entries: entries,
            navIndex: navIndex,
          ),
        ),
        onAdd: () => showAddEditTransactionSheet(context: context),
      ),
      // Built as it scrolls into view, one license at a time: some
      // packages have hundreds (icu: 558), and building them all at once
      // held the page up for seconds.
      body: aboutText(
        context,
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceBox(
                radius: 12,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final p in e.paragraphs)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 10,
                          left: p.indent == LicenseParagraph.centeredIndent
                              ? 0
                              : 12.0 * p.indent,
                        ),
                        child: InkText(
                          p.text,
                          textAlign: p.indent == LicenseParagraph.centeredIndent
                              ? TextAlign.center
                              : TextAlign.start,
                          style: p.indent == LicenseParagraph.centeredIndent
                              ? body.copyWith(fontWeight: FontWeight.w600)
                              : body,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

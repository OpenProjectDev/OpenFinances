// lib/features/sms/sms_view.dart
// The Expenses page's "SMS" tab: bank transaction messages caught from the
// messaging app's notifications (see bank_notifications.dart), newest
// first; missing permissions as red tiles on top. A message laid out like
// one the user defined opens the add sheet straight away; any other is an
// "unknown format" (no amount shown) and opens the define-format sheet.
// Under the chip row, two folding sections: New (not decided yet) and Seen
// (added, ignored, or swiped seen); the other swipe opens a message, like a
// tap.

import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/app/theme.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/sms/bank_notifications.dart';
import 'package:openfinances/features/sms/define_format_sheet.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/list_controls.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/swipe_row.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/tile_pill.dart';

/// The messages caught so far, always (e.g. restored from a backup on a
/// phone where nothing is allowed yet); above them, a red tile for each
/// permission missing (tap: ask for it).
class SmsView extends StatefulWidget {
  const SmsView({super.key, this.gutter = 12});
  final double gutter;

  @override
  State<SmsView> createState() => _SmsViewState();
}

class _SmsViewState extends State<SmsView> {
  bool? _canRead; // notification access (to catch the messages)
  bool? _canPost; // our own notifications
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Re-checked on coming back (e.g. from the settings screen).
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final read = await BankNotifications.hasAccess();
    final post = await BankNotifications.canPostNotifications();
    if (mounted) {
      setState(() {
        _canRead = read;
        _canPost = post;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final notify = context.select((SettingsProvider s) => s.bankNotify);
    final gutter = widget.gutter;
    // Our notifications off (the setting, or no permission for it): new
    // formats can then only be defined here.
    final notifyOff = _canPost != null && !(notify && _canPost == true);
    // One per row, not dismissible; a tap goes to Settings and flashes the
    // chip that fixes it.
    final notices = <(String, Color, VoidCallback)>[
      if (_canRead == false)
        (l.notifReadMissing, kStrongRed, () => showNotifySetting('read')),
      if (notifyOff)
        (l.notifyOffWarning, const Color(0xFFEF6C00), showNotifySetting),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (text, color, onTap) in notices)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkText(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: _MessageList(gutter: gutter, canRead: _canRead != false),
        ),
      ],
    );
  }
}

/// Centered in what's visible (the page extends under the bottom bar).
class _Centered extends StatelessWidget {
  const _Centered(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.paddingOf(context).bottom,
    ),
    child: Center(child: child),
  );
}

/// [g] as recorded, shown in the display [currency].
String _amountText(BuildContext context, BankGuess g, String currency) {
  final fa = isFaUi(context);
  final s = formatMinorWithCommas(g.shownMinor(currency));
  return faDigitsFor(fa) ? toFaDigits(s) : s;
}

/// Filter ids for the SMS tab's chips besides the formats.
const String kUnknown = '#unknown';
const String kIgnored = '#ignored';

/// A format-name chip's id: this, then the name (formats with the same name
/// share one chip).
const String _kNamed = '#name:';

/// Asks the Expenses page to show the SMS tab with this filter (e.g. from
/// Settings > SMS formats' "+": the unknown formats, to define one).
final ValueNotifier<String?> smsOpenRequest = ValueNotifier<String?>(null);

class _MessageList extends StatefulWidget {
  const _MessageList({required this.gutter, required this.canRead});
  final double gutter;

  /// Without notification access nothing new arrives: the empty list says
  /// what it's for instead.
  final bool canRead;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  // Kept across tab switches, so coming back shows the list (its chips'
  // names and what was added too) at once while it reloads.
  static List<BankMessage>? _cache;
  static Set<String> _addedCache = {};
  static Set<String> _seenCache = {};
  static Map<String, String> _namesCache = {};

  List<BankMessage>? _items = _cache;

  // Kept where it was left, while "keep place" is on.
  late final RememberedScroll _list;
  Set<String> _added = _addedCache;
  Set<String> _seen = _seenCache;

  /// The formats (skeletons) under each name chip, as last built.
  Map<String, Set<String>> _named = {};

  /// Formats' own names (skeleton → name), for their chips.
  Map<String, String> _formatNames = _namesCache;
  String? _error;
  // Messages that arrived while the app was in the background.
  late final AppLifecycleListener _lifecycle;

  bool get _isFa => isFaUi(context);
  String _digits(String s) => faDigitsFor(_isFa) ? toFaDigits(s) : s;

  @override
  void initState() {
    super.initState();
    _list = RememberedScroll('sms', context.read<SettingsProvider>());
    _lifecycle = AppLifecycleListener(onResume: _load);
    // Always live: any change to messages, formats or ignored senders (from
    // any page, or a message arriving) reloads the list.
    BankNotifications.changes.addListener(_load);
    _load();
    smsOpenRequest.addListener(_onRequest);
    _onRequest();
  }

  @override
  void dispose() {
    smsOpenRequest.removeListener(_onRequest);
    BankNotifications.changes.removeListener(_load);
    _lifecycle.dispose();
    _list.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final added = await BankNotifications.addedKeys();
      final seen = await BankNotifications.seenKeys();
      final items = await BankNotifications.read();
      final formats = await BankNotifications.formats();
      _cache = items;
      _addedCache = added;
      _seenCache = seen;
      _namesCache = {
        for (final f in formats)
          if (f.name.isNotEmpty) f.skeleton: f.name,
      };
      if (mounted) {
        setState(() {
          _formatNames = _namesCache;
          _added = added;
          _seen = seen;
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(BankMessage m) async {
    await openBankMessage(context, m);
    await _load(); // added, defined, or ignored (before the filter check)
    // Defined from the "unknown format" list: show everything again.
    if (_filter == kUnknown && mounted) {
      final now = _items?.where((x) => x.key == m.key).firstOrNull;
      if (now != null && now.status == BankReadStatus.learned) {
        setState(() => _filter = null);
      }
    }
  }

  /// The filter chip chosen: a format name ([_kNamed] + the name: its
  /// formats), [kUnknown], [kIgnored], or null (everything not ignored).
  String? _filter;

  void _onRequest() {
    final f = smsOpenRequest.value;
    if (f == null) return;
    smsOpenRequest.value = null;
    if (mounted) setState(() => _filter = f);
  }

  bool _shows(BankMessage m) => switch (_filter) {
    null => !m.isIgnored,
    kUnknown => !m.isIgnored && m.status == BankReadStatus.guess,
    kIgnored => m.isIgnored,
    final f => !m.isIgnored && (_named[f]?.contains(m.format) ?? false),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Only what the rows show: a period arrow elsewhere (a settings
    // change) built every message again.
    final (currencyCode, calendar) = context.select(
      (SettingsProvider s) => (s.currencyCode, s.calendar),
    );
    final gutter = widget.gutter;
    final all = _items;

    if (_error != null) {
      return _Centered(
        InkText(_error!, style: const TextStyle(color: kStrongRed)),
      );
    }
    if (all == null) {
      return const _Centered(CircularProgressIndicator());
    }

    // One chip per defined format (named after its sender, ranked by the
    // amounts read with it), then "unknown format" and "ignored".
    final perFormat = <String, (Map<String, int>, int)>{};
    var unknown = 0;
    var ignored = 0;
    for (final m in all) {
      if (m.isIgnored) {
        ignored++;
      } else if (m.status == BankReadStatus.guess) {
        unknown++;
      } else if (m.format != null) {
        final (senders, total) = perFormat[m.format!] ?? (<String, int>{}, 0);
        senders.update(m.sender, (n) => n + 1, ifAbsent: () => 1);
        perFormat[m.format!] = (
          senders,
          total + m.guesses.first.shownMinor(currencyCode),
        );
      }
    }
    // Formats with the same name share one chip (their totals added up).
    final perName = <String, (Set<String>, int)>{};
    for (final MapEntry(key: f, value: (senders, total)) in perFormat.entries) {
      final top = (senders.entries.toList()..sort((a, b) => b.value - a.value))
          .first
          .key;
      // Its own name, else the bank that sends it.
      final name =
          _formatNames[f] ?? (top.isEmpty ? l.bankMessageFallback : top);
      final (formats, sum) = perName[name] ?? (<String>{}, 0);
      perName[name] = (formats..add(f), sum + total);
    }
    _named = {
      for (final MapEntry(key: name, value: (formats, _)) in perName.entries)
        '$_kNamed$name': formats,
    };
    final formatChips = [
      for (final MapEntry(key: name, value: (_, total)) in perName.entries)
        TotalChip(id: '$_kNamed$name', label: name, total: total),
    ];
    if (_filter != null &&
        _filter != kUnknown &&
        _filter != kIgnored &&
        !_named.containsKey(_filter)) {
      _filter = null; // that name is gone
    }
    final items = all.where(_shows).toList();

    Widget emptyText(String text) => _Centered(
      InkText(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );

    // Decided: added to the ledger, ignored, or swiped seen. The rest is new.
    bool decided(BankMessage m) =>
        m.isIgnored || _added.contains(m.key) || _seen.contains(m.key);
    final fresh = [
      for (final m in items)
        if (!decided(m)) m,
    ];
    final done = [
      for (final m in items)
        if (decided(m)) m,
    ];

    Widget row(BankMessage m) {
      final added = _added.contains(m.key);
      final seen = _seen.contains(m.key);
      final g = m.guesses.firstOrNull;
      // Like every list's rows: end→start opens it like a tap; start→end
      // moves it to Seen (or, swiped seen, back to New). Added and ignored
      // ones are decided already: they only open.
      return SwipeRow(
        dismissKey: ValueKey('sms_${m.key}'),
        radius: 14,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            await BankNotifications.markSeen(m.key, seen: !seen);
          } else {
            _open(m);
          }
          return false;
        },
        startAction: added || m.isIgnored
            ? null
            : SwipeAction(
                icon: ImageIcon(seen ? AppIcons.hide : AppIcons.show),
                label: seen ? l.smsMarkUnseen : l.smsMarkSeen,
                color: scheme.surfaceContainerHighest,
                onColor: scheme.onSurface,
              ),
        endAction: SwipeAction(
          icon: const ImageIcon(AppIcons.edit),
          label: l.smsOpen,
          color: scheme.secondaryContainer,
          onColor: scheme.onSecondaryContainer,
        ),
        child: _SmsTile(
          message: m,
          added: added,
          // Only a defined format's reading is shown.
          amountText:
              g != null && m.status == BankReadStatus.learned && !m.isIgnored
              ? _amountText(context, g, currencyCode)
              : '',
          dateText:
              '${dayTitle(m.date, calendar, _isFa)}  '
              '${_digits('${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}')}',
          onTap: () => _open(m),
        ),
      );
    }

    // A section of messages (or a faint line when it has none): its rows
    // built as they scroll into view (hundreds were built at once, and
    // again on every swipe).
    Widget section(
      String id,
      String title,
      List<BankMessage> list,
      String none, {
      bool open = false,
    }) => FoldSection.sliver(
      id: id,
      title: title,
      initiallyOpen: open,
      itemCount: list.isEmpty ? 1 : list.length,
      itemBuilder: (_, i) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkText(
                none,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: .7),
                ),
              ),
            )
          : row(list[i]),
    );

    // A row of fewer than two chips has nothing to choose between; "unknown"
    // and "ignored" only when something is under them. A chosen chip
    // doesn't show a total here (counts of messages, not amounts).
    final trailingChips = [
      if (unknown > 0)
        TotalChip(id: kUnknown, label: l.formatUnknown, total: unknown),
      if (ignored > 0)
        TotalChip(id: kIgnored, label: l.ignoredTitles, total: ignored),
    ];
    final hasChips = formatChips.length + trailingChips.length >= 2;

    return all.isEmpty
        ? emptyText(widget.canRead ? l.smsTabEmpty : l.smsTabExplain)
        : CustomScrollView(
            controller: _list,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  MediaQuery.paddingOf(context).bottom + 16,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (hasChips)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TotalChipsRow(
                            selected: _filter,
                            onSelect: (f) => setState(() => _filter = f),
                            showTotal: false,
                            chips: formatChips,
                            trailing: trailingChips,
                          ),
                        ),
                      ),
                    section(
                      'sms.new',
                      l.smsNewSection,
                      fresh,
                      l.smsNothingNew,
                      open: true,
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    section(
                      'sms.seen',
                      l.smsSeenSection,
                      done,
                      l.smsNothingSeen,
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}

/// Like a History row: sender | amount, then kind (or "added", or
/// "unknown format") | date pills.
class _SmsTile extends StatelessWidget {
  const _SmsTile({
    required this.message,
    required this.added,
    required this.amountText,
    required this.dateText,
    required this.onTap,
  });
  final BankMessage message;
  final bool added;
  final String amountText;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // An ignored sender's message may have no reading at all.
    final g = message.guesses.firstOrNull;
    final income = g?.kind == TransactionKind.income;
    final sure = message.status == BankReadStatus.learned;
    final kindText = income ? l.incomeTitle : l.expenseShort;

    // The pills: a step up from the tile (inside its section).
    final pill = context.raisedBy(2);
    // Inside its section: a step up from it.
    return Material(
      color: context.raised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkText(
                      message.sender.isEmpty
                          ? l.bankMessageFallback
                          : message.sender,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkText(
                    amountText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TilePill(
                        text: message.isIgnored
                            ? l.ignoredOne
                            : added
                            ? l.smsAdded
                            : sure
                            ? kindText
                            : l.formatUnknown,
                        background: pill,
                        foreground: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TilePill(
                    text: dateText,
                    background: pill,
                    foreground: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

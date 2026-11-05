// lib/features/sms/bank_notifications.dart
// Bank messages come from the messaging app's notifications (Android
// BankNotificationListener), not from the SMS inbox: no SMS permission, just
// notification access the user grants in system settings.
//
// Reading them happens natively (BankMessageReader.kt), because our own
// notification has to work while the app is closed. A message laid out like
// one the user defined before is read exactly; any other is an "unknown
// format" until the user defines it here (define_format_sheet.dart: pick
// the amount in the message), ignores the format, or ignores the sender.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/data/currency_units.dart';
import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart';
import 'package:openfinances/features/sms/define_format_sheet.dart';
import 'package:openfinances/shared/transaction_kind.dart';

enum BankReadStatus { learned, guess, ignored, none }

/// One way to read a message: [amount] went out (expense) or came in, in
/// the message's own [unit] ('IRR' rial or 'IRT' toman: banks differ).
class BankGuess {
  final int amount;
  final String unit;
  final TransactionKind kind;
  final int runIndex;

  /// Where the number is in the message text.
  final int start;
  final int end;

  const BankGuess(
    this.amount,
    this.unit,
    this.kind,
    this.runIndex,
    this.start,
    this.end,
  );

  /// What gets recorded: rounded in its own unit (toman to the nearest
  /// 1,000, rial to the nearest 10,000), in minor units.
  int get recordedMinor => roundInUnit(amount, unit) * 100;

  /// [recordedMinor] in the display currency [display].
  int shownMinor(String display) => amountInUnit(recordedMinor, unit, display);
}

/// A captured bank message and how it reads.
class BankMessage {
  final String key;
  final String text;
  final String sender;
  final DateTime date;
  final BankReadStatus status;

  /// Best first (a learned format's reading, then the guesses).
  final List<BankGuess> guesses;

  /// The defined (or ignored) format it matches: its skeleton.
  final String? format;

  /// Its sender is ignored (kept, but never read or notified).
  final bool senderIgnored;

  const BankMessage({
    required this.key,
    required this.text,
    required this.sender,
    required this.date,
    required this.status,
    required this.guesses,
    this.format,
    this.senderIgnored = false,
  });

  /// Its format or its sender is ignored.
  bool get isIgnored => senderIgnored || status == BankReadStatus.ignored;
}

/// A defined format, as Settings > SMS formats lists it.
class BankFormatInfo {
  /// The layout (the message with each number as `#`): its id.
  final String skeleton;

  /// The user's name for it ('' if none: the sender stands in).
  final String name;

  /// 'expense', 'income', 'sign' (from the number's own +/-) or 'ignore'.
  final String kind;

  /// 'IRT' or 'IRR'.
  final String unit;

  /// Captured messages laid out like it, the newest one's sender and text.
  final int count;
  final String? sender;
  final String? example;

  const BankFormatInfo({
    required this.skeleton,
    this.name = '',
    required this.kind,
    required this.unit,
    required this.count,
    this.sender,
    this.example,
  });
}

/// Bumped to open Settings on one of the notification chips and flash it
/// (the SMS tab's notices). Settings listens.
final ValueNotifier<int> notifySettingRequest = ValueNotifier<int>(0);

/// The chip [notifySettingRequest] points at: 'read' or 'show'.
String notifySettingTarget = 'show';

/// Goes to Settings and points at [which] ('show': show notifications,
/// 'read': read notifications).
void showNotifySetting([String which = 'show']) {
  notifySettingTarget = which;
  notifySettingRequest.value++;
  mainTab.value = 3;
}

/// Pref key: messages already added to the ledger ([BankMessage.key]s).
const String kSmsAddedPrefsKey = 'smsAddedV1';

/// Pref key: messages marked seen (swiped; greyed like added ones). Prefs
/// ride along with backups.
const String kSmsSeenPrefsKey = 'smsSeenV1';

/// Rounds a bank amount in its own [unit]: toman to the nearest 1,000
/// (5,450 → 5,000; 25,890 → 26,000), rial to the nearest 10,000; anything
/// else as is. Whole units. (BankTxnNotifier.kt rounds the same way.)
int roundInUnit(int amount, String unit) => switch (unit) {
  'IRT' => (amount / 1000).round() * 1000,
  'IRR' => (amount / 10000).round() * 10000,
  _ => amount,
};

class BankNotifications {
  const BankNotifications._();

  static const _channel = MethodChannel('openfinances/bank_notifications');

  /// Bumped whenever messages, formats or ignored senders change (here, or
  /// natively when a new bank message arrives): the SMS page and the formats
  /// page follow it, so they're always live.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static bool _listening = false;

  /// Hears the native side's "changed" (a message captured while the app
  /// is open). Called once at startup.
  static void listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') changes.value++;
      return null;
    });
  }

  static void _changed() => changes.value++;

  /// Whether the user has granted notification access.
  static Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen where access is granted or taken back.
  static Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod('openAccessSettings');
    } catch (_) {}
  }

  /// Whether our own notifications can be shown.
  static Future<bool> canPostNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('canPostNotifications') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// This app's notification settings (when asking again does nothing).
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Asks for permission to post our own notifications (Android 13+);
  /// true if they can be shown.
  static Future<bool> requestPostNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('requestPostNotifications') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Captured messages, newest first: those that read as transactions,
  /// and the ignored ones (by format or sender).
  static Future<List<BankMessage>> read() async {
    await _takeNativeSeen();
    final raw = await _channel.invokeListMethod<Map>('readLog') ?? const [];
    final out = <BankMessage>[];
    for (final m in raw) {
      final status = BankReadStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => BankReadStatus.none,
      );
      final senderIgnored = m['senderIgnored'] == true;
      if (status == BankReadStatus.none && !senderIgnored) continue;
      out.add(
        BankMessage(
          key: '${m['key']}',
          text: '${m['text'] ?? ''}',
          sender: '${m['sender'] ?? ''}',
          date: DateTime.fromMillisecondsSinceEpoch(
            (m['postedAt'] as int?) ?? 0,
          ),
          status: status,
          format: m['format'] as String?,
          senderIgnored: senderIgnored,
          guesses: [
            for (final g in (m['guesses'] as List?) ?? const [])
              BankGuess(
                (g['amount'] as num).toInt(),
                '${g['unit'] ?? 'IRR'}',
                g['kind'] == 'income'
                    ? TransactionKind.income
                    : TransactionKind.expense,
                (g['runIndex'] as num).toInt(),
                (g['start'] as num).toInt(),
                (g['end'] as num).toInt(),
              ),
          ],
        ),
      );
    }
    return out;
  }

  /// [g] is the right reading of [m]: remember the layout (as [name]).
  static Future<void> confirm(
    BankMessage m,
    BankGuess g, {
    String name = '',
  }) async {
    try {
      await _channel.invokeMethod('confirm', {
        'key': m.key,
        'name': name,
        'runIndex': g.runIndex,
        'kind': g.kind == TransactionKind.income ? 'income' : 'expense',
        'unit': g.unit,
      });
      _changed();
    } catch (_) {}
  }

  /// Messages laid out like [m] aren't transactions.
  static Future<void> ignore(BankMessage m) async {
    try {
      await _channel.invokeMethod('ignore', {'key': m.key});
      _changed();
    } catch (_) {}
  }

  /// The defined formats (ignored layouts too), oldest first.
  static Future<List<BankFormatInfo>> formats() async {
    final raw = await _channel.invokeListMethod<Map>('listFormats') ?? const [];
    return [
      for (final f in raw)
        BankFormatInfo(
          skeleton: '${f['skeleton']}',
          name: '${f['name'] ?? ''}',
          kind: '${f['kind']}',
          unit: '${f['unit'] ?? 'IRR'}',
          count: (f['count'] as num?)?.toInt() ?? 0,
          sender: f['sender'] as String?,
          example: f['example'] as String?,
        ),
    ];
  }

  /// Changes [skeleton]'s [name], which way its amounts go ([kind]) and
  /// their [unit].
  static Future<void> updateFormat(
    String skeleton, {
    required String name,
    required String kind,
    required String unit,
  }) async {
    try {
      await _channel.invokeMethod('updateFormat', {
        'skeleton': skeleton,
        'name': name,
        'kind': kind,
        'unit': unit,
      });
      _changed();
    } catch (_) {}
  }

  /// Forgets a format: its messages are unknown again (or, for an ignored
  /// layout, read again).
  static Future<void> deleteFormat(String skeleton) async {
    try {
      await _channel.invokeMethod('deleteFormat', {'skeleton': skeleton});
      _changed();
    } catch (_) {}
  }

  /// Never read [sender]'s messages (or, with [ignored] false, again).
  static Future<void> setSenderIgnored(String sender, bool ignored) async {
    try {
      await _channel.invokeMethod('setSenderIgnored', {
        'sender': sender,
        'ignored': ignored,
      });
      _changed();
    } catch (_) {}
  }

  /// An "Add" tapped on our notification, if one is waiting.
  static Future<Map?> takePendingAdd() async {
    try {
      return await _channel.invokeMethod<Map>('takePendingAdd');
    } catch (_) {
      return null;
    }
  }

  /// Defined formats, captured messages and ignored senders, for backups.
  /// Throws if they can't be read: a backup never goes without them
  /// silently.
  static Future<Map<String, Object?>> exportData() async {
    final m = await _channel.invokeMapMethod<String, String>('exportData');
    if (m == null) throw StateError('the bank data could not be read');
    return {
      'formats': jsonDecode(m['formats'] ?? '[]'),
      'messages': jsonDecode(m['messages'] ?? '[]'),
      'ignoredSenders': jsonDecode(m['ignoredSenders'] ?? '[]'),
    };
  }

  /// Writes a backup's bank data (each part it has); throws if it can't.
  static Future<void> importData(Map<String, Object?> data) async {
    await _channel.invokeMethod('importData', {
      if (data['formats'] is List) 'formats': jsonEncode(data['formats']),
      if (data['messages'] is List) 'messages': jsonEncode(data['messages']),
      if (data['ignoredSenders'] is List)
        'ignoredSenders': jsonEncode(data['ignoredSenders']),
    });
    _changed();
  }

  // ---------------- Adding to the ledger ----------------

  /// Opens the add sheet prefilled with [recordedMinor] in [unit] (shown
  /// in the display currency; kept as the bank sent it if not changed),
  /// [kind] and [date]; if saved, the message counts as added. Resolves to
  /// whether it was saved.
  static Future<bool> addToLedger(
    BuildContext context, {
    required String key,
    required int recordedMinor,
    required String unit,
    required TransactionKind kind,
    required DateTime date,
  }) async {
    final saved = await showAddEditTransactionSheet(
      context: context,
      kind: kind,
      prefillAmountMinor: recordedMinor,
      prefillCurrency: unit,
      prefillDate: date,
    );
    if (saved) await markAdded(key);
    return saved;
  }

  static Future<Set<String>> addedKeys() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getStringList(kSmsAddedPrefsKey) ?? const []).toSet();
  }

  static Future<void> markAdded(String key) =>
      _remember(kSmsAddedPrefsKey, key);

  static Future<Set<String>> seenKeys() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getStringList(kSmsSeenPrefsKey) ?? const []).toSet();
  }

  /// Messages marked seen from their notification (its Seen button, while
  /// the app wasn't looking) join the seen list.
  static Future<void> _takeNativeSeen() async {
    List<String> keys;
    try {
      keys = await _channel.invokeListMethod<String>('takeSeen') ?? const [];
    } on MissingPluginException {
      return;
    }
    if (keys.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final old = sp.getStringList(kSmsSeenPrefsKey) ?? const [];
    await sp.setStringList(kSmsSeenPrefsKey, [
      ...keys,
      ...old.where((k) => !keys.contains(k)),
    ].take(500).toList());
    _changed();
  }

  /// Marks the message [key] seen, or (with [seen] false) not seen again.
  static Future<void> markSeen(String key, {bool seen = true}) =>
      _remember(kSmsSeenPrefsKey, key, keep: seen);

  /// Puts [key] first in the pref list [pref] (or, [keep] false, takes it
  /// out).
  static Future<void> _remember(
    String pref,
    String key, {
    bool keep = true,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getStringList(pref) ?? const [];
    // The native log keeps the latest 500 messages; so do we.
    final next = [
      if (keep) key,
      ...keys.where((k) => k != key),
    ].take(500).toList();
    await sp.setStringList(pref, next);
    _changed();
  }
}

/// Acts on a tap on our bank-message notification (on launch, or when the
/// app comes back to the front): "Add" opens the add sheet, "Define format"
/// (or the notification itself) the define-format sheet.
class BankPendingAdd extends StatefulWidget {
  const BankPendingAdd({super.key, required this.child});
  final Widget child;

  @override
  State<BankPendingAdd> createState() => _BankPendingAddState();
}

class _BankPendingAddState extends State<BankPendingAdd> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _take);
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    final p = await BankNotifications.takePendingAdd();
    if (p == null || !mounted) return;
    // Its notification was tapped: it's been seen, whether it's recorded
    // or the sheet is cancelled (the owner, 2026-10-27).
    await BankNotifications.markSeen('${p['key']}');
    if (!mounted) return;
    if (p['action'] == 'define') {
      final key = '${p['key']}';
      final all = await BankNotifications.read();
      final m = all.where((m) => m.key == key).firstOrNull;
      if (m != null && mounted) await openBankMessage(context, m);
      return;
    }
    final posted = (p['postedAt'] as num?)?.toInt() ?? 0;
    await BankNotifications.addToLedger(
      context,
      key: '${p['key']}',
      // Already rounded natively, in the message's own unit.
      recordedMinor: (p['amount'] as num).toInt() * 100,
      unit: '${p['unit'] ?? 'IRR'}',
      kind: p['kind'] == 'income'
          ? TransactionKind.income
          : TransactionKind.expense,
      date: posted > 0
          ? DateTime.fromMillisecondsSinceEpoch(posted)
          : DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

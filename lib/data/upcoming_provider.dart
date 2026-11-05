import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backup_values.dart';
import 'db.dart';
import 'expense_provider.dart';
import 'upcoming_repository.dart';

/// Planned payments ("I owe 10M to X in 5 days"). Kept apart from the
/// expense ledger: an item only turns into an expense when paid with "Pay &
/// add". Paid items stay (see [paid]) so a payment can be undone.
class UpcomingProvider extends ChangeNotifier {
  final UpcomingRepository _repo;

  UpcomingProvider({UpcomingRepository? repo})
    : _repo = repo ?? UpcomingRepository();

  // ----------------- State -----------------

  // Recorded rows (exactly as stored) and their shown versions (amounts in
  // the display unit, toman/rial converted). Backups use the recorded ones.
  List<UpcomingDto> _recorded = [];
  List<UpcomingSuggestion> _recordedHistory = [];

  List<UpcomingDto> _items = [];
  List<UpcomingDto> _paid = [];

  /// Pending items, soonest due first, as shown.
  List<UpcomingDto> get items => _items;

  /// Paid items, most recently paid first, as shown.
  List<UpcomingDto> get paid => _paid;

  List<UpcomingSuggestion> _history = [];
  List<UpcomingSuggestion> get history => _history;

  String _displayCurrency = 'IRT';

  /// Called when the currency setting changes; nothing stored changes.
  void setDisplayCurrency(String code) {
    if (code == _displayCurrency) return;
    _displayCurrency = code;
    _derive();
    scheduleMicrotask(notifyListeners);
  }

  void _derive() {
    _items = [
      for (final e in _recorded)
        if (!e.isPaid) e.inUnit(_displayCurrency),
    ];
    _paid = [
      for (final e in _recorded)
        if (e.isPaid) e.inUnit(_displayCurrency),
    ]..sort((a, b) => b.paidAtUtc!.compareTo(a.paidAtUtc!));
    _history = [for (final h in _recordedHistory) h.inUnit(_displayCurrency)];
  }

  int get totalMinor => _items.fold(0, (sum, e) => sum + e.amountMinor);

  bool get hasOverdue {
    final today = _todayLocal();
    return _items.any((e) => e.dueAtUtc.toLocal().isBefore(today));
  }

  // ----------------- Lifecycle -----------------

  Future<void> init() => load();

  Future<void> load() async {
    try {
      _recorded = await _repo.list();
      _recordedHistory = await _repo.listHistory();
      _derive();
    } catch (e) {
      debugPrint('[UpcomingProvider] load failed: $e');
    }
    notifyListeners();
  }

  // ----------------- CRUD -----------------

  /// Adds an item; its gid.
  Future<String> add({
    required String title,
    required int amountMinor,
    required DateTime dueLocal,
    String? note,
    String? categoryGid,
    String currency = 'IRR',
  }) async {
    final gid = await _repo.create(
      title: title,
      amountMinor: amountMinor,
      dueLocal: dueLocal,
      note: note,
      categoryGid: categoryGid,
      currency: currency,
    );
    await _repo.rememberTitle(
      title: title,
      amountMinor: amountMinor,
      categoryGid: categoryGid,
      currency: currency,
    );
    await load();
    return gid;
  }

  /// [amountMinor] is in the display unit. It's written only if it differs
  /// from what was shown, so editing e.g. the title never rewrites how the
  /// amount was recorded.
  Future<void> update(
    String gid, {
    required String title,
    required int amountMinor,
    required DateTime dueLocal,
    String? note,
    String? categoryGid,
  }) async {
    final shown = _items.where((e) => e.gid == gid).firstOrNull;
    await _repo.update(gid, {
      'title': title,
      if (shown == null || shown.amountMinor != amountMinor) ...{
        'amountMinor': amountMinor,
        'currency': _displayCurrency,
      },
      'dueAtUtc': dueLocal.toUtc().toIso8601String(),
      'note': note,
      'categoryGid': categoryGid,
    });
    await _repo.rememberTitle(
      title: title,
      amountMinor: amountMinor,
      categoryGid: categoryGid,
      currency: _displayCurrency,
    );
    await load();
  }

  Future<void> delete(String gid) async {
    await _repo.softDelete(gid);
    await load();
  }

  /// Marks [item] paid today; with [expenses], it's also added there as an
  /// expense (dated today). [nextGid]: the item scheduled after it ("Pay &
  /// reschedule"). [amountMinor] (display unit): paid this much instead
  /// (its sheet's quick edit). It stays in the list, paid, until deleted.
  Future<void> markPaid(
    UpcomingDto item,
    ExpenseProvider? expenses, {
    String? nextGid,
    int? amountMinor,
  }) async {
    final changed = amountMinor != null && amountMinor != item.amountMinor;
    // Unchanged, the expense takes the amount exactly as it was recorded.
    final recorded = _recorded.where((e) => e.gid == item.gid).firstOrNull;
    if (recorded != null) item = recorded;
    final today = _todayLocal();
    final ledgerGid = await expenses?.addExpense(
      title: item.title,
      amountMinor: changed ? amountMinor : item.amountMinor,
      occurredLocal: today,
      note: item.note,
      categoryGid: item.categoryGid,
      accountGid: null,
      currency: changed ? _displayCurrency : item.currency,
    );
    await _repo.update(item.gid, {
      if (changed) ...{'amountMinor': amountMinor, 'currency': _displayCurrency},
      'paidAtUtc': DateTime.now().toUtc().toIso8601String(),
      'ledgerGid': ledgerGid,
      'nextGid': nextGid,
    });
    await load();
  }

  /// The expense paid [item] added, if it's still in History.
  Future<String?> ledgerEntryOf(UpcomingDto item) async {
    final g = item.ledgerGid;
    if (g == null) return null;
    return await AppDb.instance.isLive('expenses', g) ? g : null;
  }

  /// Takes paid [item]'s payment back: it's due again, the expense it added
  /// goes, and so does the item "Pay & reschedule" scheduled after it
  /// (unless that one was paid too).
  Future<void> undoPaid(UpcomingDto item, ExpenseProvider expenses) async {
    final entry = await ledgerEntryOf(item);
    if (entry != null) await expenses.deleteExpense(entry);
    final next = item.nextGid == null
        ? null
        : _recorded.where((e) => e.gid == item.nextGid).firstOrNull;
    if (next != null && !next.isPaid) await _repo.softDelete(next.gid);
    await _repo.update(item.gid, {
      'paidAtUtc': null,
      'ledgerGid': null,
      'nextGid': null,
    });
    await load();
  }

  /// Paid [item], now [amountMinor] (display unit) paid on [paidLocal], in
  /// History: the expense it added changes with it, or one is added.
  Future<void> recordPaid(
    UpcomingDto item, {
    required int amountMinor,
    required DateTime paidLocal,
    required ExpenseProvider expenses,
  }) async {
    final entry = await ledgerEntryOf(item);
    final old = item.paidAtUtc!.toLocal();
    final dayChanged =
        DateTime(old.year, old.month, old.day) !=
        DateTime(paidLocal.year, paidLocal.month, paidLocal.day);
    final amountChanged = amountMinor != item.amountMinor;
    final moved = {'amountMinor': amountMinor, 'currency': _displayCurrency};
    String? ledgerGid = entry;
    if (entry == null) {
      // As recorded unless changed here.
      final recorded = _recorded.where((e) => e.gid == item.gid).firstOrNull;
      final keep = !amountChanged && recorded != null;
      ledgerGid = await expenses.addExpense(
        title: item.title,
        amountMinor: keep ? recorded.amountMinor : amountMinor,
        occurredLocal: paidLocal,
        note: item.note,
        categoryGid: item.categoryGid,
        currency: keep ? recorded.currency : _displayCurrency,
      );
    } else if (amountChanged || dayChanged) {
      await expenses.updateExpense(entry, {
        if (amountChanged) ...moved,
        'occurredAtUtc': paidLocal.toUtc().toIso8601String(),
      });
    }
    await _repo.update(item.gid, {
      if (amountChanged) ...moved,
      if (dayChanged) 'paidAtUtc': paidLocal.toUtc().toIso8601String(),
      'ledgerGid': ledgerGid,
    });
    await load();
  }

  // ----------------- History (suggestions) -----------------

  /// History entries matching [query] (substring, case-insensitive);
  /// an empty query returns the most recent ones.
  List<UpcomingSuggestion> suggestionsFor(String query, {int limit = 5}) {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? _history
        : _history.where((h) => h.title.toLowerCase().contains(q));
    return matches.take(limit).toList();
  }

  Future<void> removeSuggestion(String title) async {
    await _repo.forgetTitle(title);
    _recordedHistory = _recordedHistory.where((h) => h.title != title).toList();
    _history = _history.where((h) => h.title != title).toList();
    notifyListeners();
  }

  // ----------------- Backup / Restore -----------------

  /// Pending items (with their own gids/timestamps) + title history.
  Future<Map<String, dynamic>> exportForBackup() async {
    await load();
    return {
      // Exactly as recorded, never the converted view.
      'upcoming': [
        for (final e in _recorded)
          {
            'gid': e.gid,
            'title': e.title,
            'amountMinor': e.amountMinor,
            'currency': e.currency,
            'dueAtUtc': e.dueAtUtc.toIso8601String(),
            'note': e.note,
            'categoryGid': e.categoryGid,
            'paidAtUtc': e.paidAtUtc?.toIso8601String(),
            'ledgerGid': e.ledgerGid,
            'nextGid': e.nextGid,
            'version': e.version,
            'createdAtUtc': e.createdAtUtc.toIso8601String(),
            'updatedAtUtc': e.updatedAtUtc.toIso8601String(),
          },
      ],
      'upcomingHistory': [for (final h in _recordedHistory) h.toMap()],
    };
  }

  /// Replaces current upcoming items with the backup's (original gids
  /// kept), and merges the title history.
  Future<void> importFromBackup({
    required List<Map<String, dynamic>> upcomingJson,
    required List<Map<String, dynamic>> historyJson,
  }) async {
    final now = DateTime.now().toUtc();
    final rows = <UpcomingDto>[];
    for (final e in upcomingJson) {
      final title = backupString(e['title']) ?? '';
      final amount = backupInt(e['amountMinor']);
      final due = backupDateUtc(e['dueAtUtc']);
      if (title.isEmpty || amount == null || due == null) continue;
      final created = backupDateUtc(e['createdAtUtc']) ?? now;
      rows.add(
        UpcomingDto(
          gid: backupString(e['gid']) ?? _repo.newGid(),
          title: title,
          amountMinor: amount,
          currency: backupString(e['currency']) ?? 'IRR',
          dueAtUtc: due,
          note: backupString(e['note']),
          categoryGid: backupString(e['categoryGid']),
          paidAtUtc: backupDateUtc(e['paidAtUtc']),
          ledgerGid: backupString(e['ledgerGid']),
          nextGid: backupString(e['nextGid']),
          version: backupInt(e['version']) ?? 1,
          createdAtUtc: created,
          updatedAtUtc: backupDateUtc(e['updatedAtUtc']) ?? created,
        ),
      );
    }
    await _repo.replaceAll(rows);

    for (final h in historyJson) {
      try {
        final title = backupString(h['title']);
        final amount = backupInt(h['amountMinor']);
        if (title == null || amount == null) continue;
        await _repo.rememberTitle(
          title: title,
          amountMinor: amount,
          categoryGid: backupString(h['categoryGid']),
          usedAtUtc: backupDateUtc(h['lastUsedAtUtc']),
          currency: backupString(h['currency']),
        );
      } catch (_) {}
    }

    await load();
  }

  // ----------------- Helpers -----------------

  static DateTime _todayLocal() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}

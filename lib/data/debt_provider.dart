import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backup_values.dart';
import 'debt_repository.dart';
import 'expense_provider.dart';
import 'income_provider.dart';
import 'settings_provider.dart' show SuggestSource;

/// Each side of debts has its own suggestions (and ignore lists) for
/// titles and for people.
extension DebtSuggestSources on DebtDirection {
  SuggestSource get titleSource => this == DebtDirection.owe
      ? SuggestSource.oweTitle
      : SuggestSource.owedTitle;
  SuggestSource get personSource => this == DebtDirection.owe
      ? SuggestSource.owePerson
      : SuggestSource.owedPerson;
}

/// A debt as shown: amounts in the display unit, with what's been paid
/// back so far.
class DebtView {
  final DebtDto debt;

  /// Oldest first.
  final List<DebtPaymentDto> payments;

  const DebtView(this.debt, this.payments);

  int get paidMinor => payments.fold(0, (s, p) => s + p.amountMinor);
  int get remainingMinor {
    final r = debt.amountMinor - paidMinor;
    return r < 0 ? 0 : r;
  }

  bool get isSettled => remainingMinor == 0;
}

/// Debts both ways (I owe / owed to me), paid off in parts. Kept apart from
/// the ledger: a payment only becomes an expense/income if the user asks.
class DebtProvider extends ChangeNotifier {
  final DebtRepository _repo;

  DebtProvider({DebtRepository? repo}) : _repo = repo ?? DebtRepository();

  // Recorded rows (exactly as stored); the views are derived in the
  // display unit. Backups use the recorded ones.
  List<DebtDto> _recorded = [];
  List<DebtPaymentDto> _recordedPayments = [];

  List<DebtView> _open = [];
  List<DebtView> _settled = [];

  /// Unsettled: those with a due date first (soonest first), then the
  /// rest, newest first.
  List<DebtView> get open => _open;

  /// Paid off, most recently settled first.
  List<DebtView> get settled => _settled;

  String _displayCurrency = 'IRT';

  /// Called when the currency setting changes; nothing stored changes.
  void setDisplayCurrency(String code) {
    if (code == _displayCurrency) return;
    _displayCurrency = code;
    _derive();
    scheduleMicrotask(notifyListeners);
  }

  void _derive() {
    final byDebt = <String, List<DebtPaymentDto>>{};
    for (final p in _recordedPayments) {
      (byDebt[p.debtGid] ??= []).add(p.inUnit(_displayCurrency));
    }
    final views = [
      for (final d in _recorded)
        DebtView(d.inUnit(_displayCurrency), byDebt[d.gid] ?? const []),
    ];
    _open = views.where((v) => !v.isSettled).toList()
      ..sort((a, b) {
        final da = a.debt.dueAtUtc, db = b.debt.dueAtUtc;
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return b.debt.startedAtUtc.compareTo(a.debt.startedAtUtc);
      });
    DateTime settledAt(DebtView v) =>
        v.payments.isEmpty ? v.debt.startedAtUtc : v.payments.last.paidAtUtc;
    _settled = views.where((v) => v.isSettled).toList()
      ..sort((a, b) => settledAt(b).compareTo(settledAt(a)));
  }

  /// What's left to pay / to get back, over the open debts.
  int totalFor(DebtDirection d) => _open
      .where((v) => v.debt.direction == d)
      .fold(0, (s, v) => s + v.remainingMinor);

  /// Names used before, most recent first; with [direction], only from
  /// that side (people one borrows from and lends to rarely overlap).
  List<String> people([DebtDirection? direction]) =>
      _distinct([for (final d in _byRecent(direction)) d.person]);

  /// Titles used before, most recent first (that side only, if given).
  List<String> titles([DebtDirection? direction]) => _distinct([
    for (final d in _byRecent(direction))
      if ((d.title ?? '').trim().isNotEmpty) d.title!.trim(),
  ]);

  /// Shown debts (display unit), newest first, optionally one side.
  List<DebtDto> _byRecent(DebtDirection? direction) => [
    for (final v in [..._open, ..._settled])
      if (direction == null || v.debt.direction == direction) v.debt,
  ]..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));

  static List<String> _distinct(List<String> items) {
    final seen = <String>{};
    return [
      for (final s in items)
        if (seen.add(s)) s,
    ];
  }

  DebtView? viewOf(String gid) {
    for (final v in [..._open, ..._settled]) {
      if (v.debt.gid == gid) return v;
    }
    return null;
  }

  // ----------------- Lifecycle -----------------

  Future<void> init() => load();

  Future<void> load() async {
    try {
      _recorded = await _repo.list();
      _recordedPayments = await _repo.listPayments();
      _derive();
    } catch (e) {
      debugPrint('[DebtProvider] load failed: $e');
    }
    notifyListeners();
  }

  // ----------------- CRUD -----------------

  /// [amountMinor] is in the display unit and recorded in it.
  Future<void> add({
    required DebtDirection direction,
    required String person,
    String? title,
    required int amountMinor,
    required DateTime startedLocal,
    DateTime? dueLocal,
    String? note,
  }) async {
    await _repo.create(
      direction: direction,
      person: person,
      title: title,
      amountMinor: amountMinor,
      startedLocal: startedLocal,
      dueLocal: dueLocal,
      note: note,
      currency: _displayCurrency,
    );
    await load();
  }

  /// [amountMinor] is in the display unit. It's written only if it differs
  /// from what was shown, so editing e.g. the name never rewrites how the
  /// amount was recorded.
  Future<void> update(
    String gid, {
    required DebtDirection direction,
    required String person,
    String? title,
    required int amountMinor,
    required DateTime startedLocal,
    DateTime? dueLocal,
    String? note,
  }) async {
    final shown = viewOf(gid)?.debt;
    await _repo.update(gid, {
      'direction': direction.name,
      'person': person,
      'title': title,
      if (shown == null || shown.amountMinor != amountMinor) ...{
        'amountMinor': amountMinor,
        'currency': _displayCurrency,
      },
      'startedAtUtc': startedLocal.toUtc().toIso8601String(),
      'dueAtUtc': dueLocal?.toUtc().toIso8601String(),
      'note': note,
    });
    await load();
  }

  Future<void> delete(String gid) async {
    await _repo.softDelete(gid);
    await load();
  }

  /// Records a part paid back. With [ledgerTitle], it's also added to the
  /// ledger: an expense when I paid, an income when I got paid.
  Future<void> pay(
    DebtView view, {
    required int amountMinor,
    required DateTime paidLocal,
    String? ledgerTitle,
    String? ledgerCategoryGid,
    ExpenseProvider? expenses,
    IncomeProvider? incomes,
  }) async {
    final ledgerGid = ledgerTitle == null
        ? null
        : await _addLedger(
            view,
            title: ledgerTitle,
            amountMinor: amountMinor,
            paidLocal: paidLocal,
            categoryGid: ledgerCategoryGid,
            expenses: expenses,
            incomes: incomes,
          );
    await _repo.addPayment(
      debtGid: view.debt.gid,
      amountMinor: amountMinor,
      paidLocal: paidLocal,
      currency: _displayCurrency,
      ledgerGid: ledgerGid,
    );
    await load();
  }

  /// An expense when I paid, an income when I got paid; its gid.
  Future<String?> _addLedger(
    DebtView view, {
    required String title,
    required int amountMinor,
    required DateTime paidLocal,
    String? categoryGid,
    ExpenseProvider? expenses,
    IncomeProvider? incomes,
  }) {
    if (view.debt.direction == DebtDirection.owe) {
      return expenses?.addExpense(
            title: title,
            amountMinor: amountMinor,
            occurredLocal: paidLocal,
            categoryGid: categoryGid,
            currency: _displayCurrency,
          ) ??
          Future.value();
    }
    return incomes?.addIncome(
          title: title,
          amountMinor: amountMinor,
          occurredLocal: paidLocal,
          categoryGid: categoryGid,
          currency: _displayCurrency,
        ) ??
        Future.value();
  }

  String _ledgerTable(DebtView view) =>
      view.debt.direction == DebtDirection.owe ? 'expenses' : 'incomes';

  /// The History entry [payment] added, if it's still there: its own link,
  /// else (recorded before payments kept theirs) the entry titled [title]
  /// of the same amount on the same day.
  Future<String?> ledgerEntryOf(
    DebtView view,
    DebtPaymentDto payment, {
    required String title,
  }) async {
    final table = _ledgerTable(view);
    final linked = payment.ledgerGid;
    if (linked != null) {
      return await _repo.isLiveEntry(table, linked) ? linked : null;
    }
    // As recorded (the view's copy may be in another unit).
    final p =
        _recordedPayments.where((r) => r.gid == payment.gid).firstOrNull ??
        payment;
    return _repo.findLedgerEntry(
      table: table,
      title: title,
      amountMinor: p.amountMinor,
      paidAtUtc: p.paidAtUtc,
    );
  }

  /// Takes [payment] back, and the History entry it added (if still
  /// there; [ledgerTitle]: see [ledgerEntryOf]).
  Future<void> undoPayment(
    DebtView view,
    DebtPaymentDto payment, {
    required String ledgerTitle,
    required ExpenseProvider expenses,
    required IncomeProvider incomes,
  }) async {
    final entry = await ledgerEntryOf(view, payment, title: ledgerTitle);
    await _repo.softDeletePayment(payment.gid);
    if (entry != null) {
      if (view.debt.direction == DebtDirection.owe) {
        await expenses.deleteExpense(entry);
      } else {
        await incomes.deleteIncome(entry);
      }
    }
    await load();
  }

  /// [payment], now [amountMinor] on [paidLocal], in History: the entry it
  /// added changes with it, or one is added.
  Future<void> recordPayment(
    DebtView view,
    DebtPaymentDto payment, {
    required int amountMinor,
    required DateTime paidLocal,
    required String ledgerTitle,
    String? ledgerCategoryGid,
    required ExpenseProvider expenses,
    required IncomeProvider incomes,
  }) async {
    final entry = await ledgerEntryOf(view, payment, title: ledgerTitle);
    final old = payment.paidAtUtc.toLocal();
    final changed =
        amountMinor != payment.amountMinor ||
        DateTime(old.year, old.month, old.day) !=
            DateTime(paidLocal.year, paidLocal.month, paidLocal.day);
    final moved = {'amountMinor': amountMinor, 'currency': _displayCurrency};
    String? ledgerGid = entry;
    if (entry == null) {
      ledgerGid = await _addLedger(
        view,
        title: ledgerTitle,
        amountMinor: amountMinor,
        paidLocal: paidLocal,
        categoryGid: ledgerCategoryGid,
        expenses: expenses,
        incomes: incomes,
      );
    } else if (changed) {
      final updates = {
        ...moved,
        'occurredAtUtc': paidLocal.toUtc().toIso8601String(),
      };
      if (view.debt.direction == DebtDirection.owe) {
        await expenses.updateExpense(entry, updates);
      } else {
        await incomes.updateIncome(entry, updates);
      }
    }
    await _repo.updatePayment(payment.gid, {
      if (changed) ...moved,
      if (changed) 'paidAtUtc': paidLocal.toUtc().toIso8601String(),
      'ledgerGid': ledgerGid,
    });
    await load();
  }

  /// Deletes [payment] and the History entry it added, if still there (a
  /// repayment that didn't happen leaves no expense or income behind);
  /// that entry's gid, for [restorePayment].
  Future<String?> deletePayment(
    DebtView view,
    DebtPaymentDto payment, {
    required String ledgerTitle,
    required ExpenseProvider expenses,
    required IncomeProvider incomes,
  }) async {
    final entry = await ledgerEntryOf(view, payment, title: ledgerTitle);
    await _repo.softDeletePayment(payment.gid);
    if (entry != null) {
      if (view.debt.direction == DebtDirection.owe) {
        await expenses.deleteExpense(entry);
      } else {
        await incomes.deleteIncome(entry);
      }
    }
    await load();
    return entry;
  }

  /// Undoes [deletePayment]: the payment and its History [entry] back.
  Future<void> restorePayment(
    DebtView view,
    String paymentGid,
    String? entry, {
    required ExpenseProvider expenses,
    required IncomeProvider incomes,
  }) async {
    await _repo.restorePayment(paymentGid);
    if (entry != null) {
      await _repo.restoreEntry(_ledgerTable(view), entry);
      if (view.debt.direction == DebtDirection.owe) {
        await expenses.loadExpenses();
      } else {
        await incomes.loadIncomes();
      }
    }
    await load();
  }

  // ----------------- Backup / Restore -----------------

  Future<Map<String, dynamic>> exportForBackup() async {
    await load();
    return {
      // Exactly as recorded, never the converted view.
      'debts': [
        for (final d in _recorded)
          {
            'gid': d.gid,
            'direction': d.direction.name,
            'person': d.person,
            'title': d.title,
            'amountMinor': d.amountMinor,
            'currency': d.currency,
            'startedAtUtc': d.startedAtUtc.toIso8601String(),
            'dueAtUtc': d.dueAtUtc?.toIso8601String(),
            'note': d.note,
            'version': d.version,
            'createdAtUtc': d.createdAtUtc.toIso8601String(),
            'updatedAtUtc': d.updatedAtUtc.toIso8601String(),
          },
      ],
      'debtPayments': [
        for (final p in _recordedPayments)
          {
            'gid': p.gid,
            'debtGid': p.debtGid,
            'amountMinor': p.amountMinor,
            'currency': p.currency,
            'paidAtUtc': p.paidAtUtc.toIso8601String(),
            'ledgerGid': p.ledgerGid,
            'version': p.version,
            'createdAtUtc': p.createdAtUtc.toIso8601String(),
            'updatedAtUtc': p.updatedAtUtc.toIso8601String(),
          },
      ],
    };
  }

  /// Replaces current debts and payments with the backup's (gids kept).
  Future<void> importFromBackup({
    required List<Map<String, dynamic>> debtsJson,
    required List<Map<String, dynamic>> paymentsJson,
  }) async {
    final now = DateTime.now().toUtc();
    final debts = <DebtDto>[];
    for (final e in debtsJson) {
      final person = backupString(e['person']) ?? '';
      final amount = backupInt(e['amountMinor']);
      final started = backupDateUtc(e['startedAtUtc']);
      if (person.isEmpty || amount == null || started == null) continue;
      final created = backupDateUtc(e['createdAtUtc']) ?? now;
      debts.add(
        DebtDto(
          gid: backupString(e['gid']) ?? _repo.newGid(),
          direction: debtDirectionOf(backupString(e['direction'])),
          person: person,
          title: backupString(e['title']),
          amountMinor: amount,
          currency: backupString(e['currency']) ?? 'IRR',
          startedAtUtc: started,
          dueAtUtc: backupDateUtc(e['dueAtUtc']),
          note: backupString(e['note']),
          version: backupInt(e['version']) ?? 1,
          createdAtUtc: created,
          updatedAtUtc: backupDateUtc(e['updatedAtUtc']) ?? created,
        ),
      );
    }
    final known = {for (final d in debts) d.gid};
    final payments = <DebtPaymentDto>[];
    for (final e in paymentsJson) {
      final debtGid = backupString(e['debtGid']);
      final amount = backupInt(e['amountMinor']);
      final paid = backupDateUtc(e['paidAtUtc']);
      if (debtGid == null || !known.contains(debtGid)) continue;
      if (amount == null || paid == null) continue;
      final created = backupDateUtc(e['createdAtUtc']) ?? now;
      payments.add(
        DebtPaymentDto(
          gid: backupString(e['gid']) ?? _repo.newGid(),
          debtGid: debtGid,
          amountMinor: amount,
          currency: backupString(e['currency']) ?? 'IRR',
          paidAtUtc: paid,
          ledgerGid: backupString(e['ledgerGid']),
          version: backupInt(e['version']) ?? 1,
          createdAtUtc: created,
          updatedAtUtc: backupDateUtc(e['updatedAtUtc']) ?? created,
        ),
      );
    }
    await _repo.replaceAll(debts, payments);
    await load();
  }
}

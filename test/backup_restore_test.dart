import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/backup_values.dart';
import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/data/currency_units.dart';
import 'package:openfinances/data/db.dart';
import 'package:openfinances/data/debt_provider.dart';
import 'package:openfinances/data/debt_repository.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/upcoming_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _row(String gid, String title, int minor, String cat) => {
  'gid': gid,
  'title': title,
  'amountMinor': minor,
  'currency': 'IRT',
  'occurredAtUtc': '2024-05-01T08:30:00.000Z',
  'categoryGid': cat,
  'createdAtUtc': '2024-05-01T09:00:00.000Z',
  'updatedAtUtc': '2024-05-02T09:00:00.000Z',
};

List<Map<String, dynamic>> _list(Object? v) =>
    List<Map<String, dynamic>>.from((v as List?) ?? const []);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
  });

  group('backup values', () {
    test('lenient readers', () {
      expect(backupInt('42'), 42);
      expect(backupInt(' 4.6 '), 5);
      expect(backupInt('x'), isNull);
      expect(backupBool('true'), isTrue);
      expect(backupBool(0), isFalse);
      expect(backupBool('maybe'), isNull);
      expect(backupString('  '), isNull);
      expect(
        backupDateUtc('2024-05-01T12:00:00+03:30'),
        DateTime.utc(2024, 5, 1, 8, 30),
      );
      expect(backupDateUtc('0'), DateTime.utc(1970));
    });
  });

  test(
    'restore keeps gids/timestamps and replaces instead of piling up',
    () async {
      final ep = ExpenseProvider();
      final cats = [
        {
          'gid': 'cat_food',
          'name': 'خوراک',
          'sort': 0,
          'iconCodePoint': 0xe59c,
          'color': 0xFF43A047,
        },
      ];
      final rows = [
        _row('e1', 'نان', 5000000, 'cat_food'),
        _row('e2', 'میوه', 25000000, 'cat_food'),
      ];

      await ep.importFromBackup(categoriesJson: cats, expensesJson: rows);
      await ep.importFromBackup(categoriesJson: cats, expensesJson: rows);

      expect(ep.raw.map((e) => e['gid']), unorderedEquals(['e1', 'e2']));
      final e1 = ep.raw.firstWhere((e) => e['gid'] == 'e1');
      expect(e1['createdAtUtc'], DateTime.utc(2024, 5, 1, 9));
      expect(e1['updatedAtUtc'], DateTime.utc(2024, 5, 2, 9));

      // The second restore replaced rows in place: no soft-deleted copies.
      final all = await AppDb.instance.db.query('expenses');
      expect(all.length, 2);

      final food = ep.categories.firstWhere((c) => c.gid == 'cat_food');
      expect(food.iconCodePoint, 0xe59c);
      expect(food.color, 0xFF43A047);
    },
  );

  test('toman/rial: shown converted, stored amounts never change', () async {
    final ep = ExpenseProvider();
    await ep.importFromBackup(
      categoriesJson: const [],
      expensesJson: [
        _row('t1', 'نان', 2500000, 'c1'), // recorded in toman
        {..._row('r1', 'آب', 2500000, 'c1'), 'currency': 'IRR'},
        {..._row('u1', 'book', 1999, 'c1'), 'currency': 'USD'},
      ],
    );
    Map<String, dynamic> row(String gid) =>
        ep.raw.firstWhere((e) => e['gid'] == gid);
    Future<int> stored(String gid) async =>
        (await AppDb.instance.db.query(
              'expenses',
              where: 'gid = ?',
              whereArgs: [gid],
            )).single['amountMinor']
            as int;

    // Shown in toman (the default unit): the rial row is divided by 10.
    expect(row('t1')['amountMinor'], 2500000);
    expect(row('r1')['amountMinor'], 250000);

    ep.setDisplayCurrency('IRR');
    expect(row('t1')['amountMinor'], 25000000);
    expect(row('r1')['amountMinor'], 2500000);
    expect(row('u1')['amountMinor'], 1999); // no fixed rate: as recorded

    // Nothing stored changed, and backups carry the recorded values.
    expect(await stored('t1'), 2500000);
    expect(await stored('r1'), 2500000);
    final exported = await ep.exportForBackup();
    final t1 = (exported['expenses'] as List).firstWhere(
      (e) => e['gid'] == 't1',
    );
    expect(t1['amountMinor'], 2500000);
    expect(t1['currency'], 'IRT');
    ep.setDisplayCurrency('IRT');
  });

  test('amountInUnit converts only toman/rial', () {
    expect(amountInUnit(100, 'IRT', 'IRR'), 1000);
    expect(amountInUnit(1000, 'IRR', 'IRT'), 100);
    expect(amountInUnit(100, 'USD', 'IRT'), 100);
    expect(amountInUnit(100, null, 'IRR'), 100);
  });

  test('one bad category row does not stop the rest', () async {
    final repo = CategoryRepository();
    await repo.restoreFromBackup([
      {'gid': 'c_a', 'name': 'الف', 'sort': 'not a number'},
      {'gid': null, 'name': 'بی‌شناسه'},
      {'gid': 'c_b', 'name': 'ب', 'sort': '7'},
    ]);
    final byGid = {for (final c in await repo.list()) c.gid: c};
    expect(byGid.keys, containsAll(['c_a', 'c_b']));
    expect(byGid['c_b']!.sort, 7);
  });

  test('upcoming items keep their gids', () async {
    final up = UpcomingProvider();
    await up.importFromBackup(
      upcomingJson: [
        {
          'gid': 'u1',
          'title': 'قسط وام',
          'amountMinor': 1200000000,
          'dueAtUtc': '2026-10-11T20:30:00.000Z',
        },
      ],
      historyJson: [
        {'title': 'قسط وام', 'amountMinor': 1200000000},
      ],
    );
    expect(up.items.single.gid, 'u1');
    expect(up.history.map((h) => h.title), contains('قسط وام'));
  });

  test('a paid upcoming item stays, and its payment can be undone', () async {
    final up = UpcomingProvider()..setDisplayCurrency('IRT');
    final ep = ExpenseProvider();
    await ep.init();
    await up.importFromBackup(upcomingJson: const [], historyJson: const []);
    int titled(String t) => ep.raw.where((e) => e['title'] == t).length;

    await up.add(
      title: 'اینترنت',
      amountMinor: 500000,
      dueLocal: DateTime(2026, 10, 30),
      currency: 'IRT',
    );
    var item = up.items.single;
    // Pay & reschedule: the next one, then this one paid and added.
    final next = await up.add(
      title: 'اینترنت',
      amountMinor: 500000,
      dueLocal: DateTime(2026, 11, 30),
      currency: 'IRT',
    );
    await up.markPaid(item, ep, nextGid: next);
    expect(up.items.single.gid, next);
    expect(up.paid.single.gid, item.gid);
    expect(up.totalMinor, 500000); // paid ones don't count
    expect(titled('اینترنت'), 1);
    item = up.paid.single;
    expect(await up.ledgerEntryOf(item), isNotNull);

    // Undo: due again, its expense and the next one gone.
    await up.undoPaid(item, ep);
    expect(up.paid, isEmpty);
    expect(up.items.single.gid, item.gid);
    expect(titled('اینترنت'), 0);

    // Paid only, then saved into History later with another amount.
    await up.markPaid(up.items.single, null);
    item = up.paid.single;
    expect(await up.ledgerEntryOf(item), isNull);
    await up.recordPaid(
      item,
      amountMinor: 450000,
      paidLocal: DateTime(2026, 10, 29),
      expenses: ep,
    );
    item = up.paid.single;
    expect(item.amountMinor, 450000);
    expect(item.paidAtUtc!.toLocal(), DateTime(2026, 10, 29));
    expect(
      ep.raw.where((e) => e['title'] == 'اینترنت').single['amountMinor'],
      450000,
    );

    // Backups carry the paid state.
    final out = await up.exportForBackup();
    final row = _list(out['upcoming']).single;
    expect(row['paidAtUtc'], isNotNull);
    expect(row['ledgerGid'], isNotNull);
  });

  group('debts', () {
    test('paid in parts, settled, and the ledger only when asked', () async {
      final dp = DebtProvider()..setDisplayCurrency('IRT');
      final ep = ExpenseProvider();
      await ep.init();
      await dp.importFromBackup(debtsJson: const [], paymentsJson: const []);
      final expensesBefore = ep.raw.length;

      await dp.add(
        direction: DebtDirection.owe,
        person: 'علی',
        amountMinor: 1000000,
        startedLocal: DateTime(2026, 10, 1),
      );
      final v = dp.open.single;
      expect(dp.totalFor(DebtDirection.owe), 1000000);
      expect(dp.totalFor(DebtDirection.owed), 0);

      // A part, not added to the ledger.
      await dp.pay(v, amountMinor: 400000, paidLocal: DateTime(2026, 10, 5));
      expect(dp.open.single.remainingMinor, 600000);
      expect(ep.raw.length, expensesBefore);

      // The rest, added as an expense: the debt is settled.
      await dp.pay(
        dp.open.single,
        amountMinor: 600000,
        paidLocal: DateTime(2026, 10, 9),
        ledgerTitle: 'بازپرداخت به علی',
        expenses: ep,
      );
      expect(dp.open, isEmpty);
      expect(dp.settled.single.paidMinor, 1000000);
      expect(ep.raw.length, expensesBefore + 1);
      expect(
        ep.raw
            .where((e) => e['title'] == 'بازپرداخت به علی')
            .single['amountMinor'],
        600000,
      );

      // Deleting the one added to History reopens it and takes its
      // expense with it; Undo brings both back.
      final ip = IncomeProvider();
      final settled = dp.settled.single;
      final added = settled.payments.firstWhere((p) => p.amountMinor == 600000);
      final entry = await dp.deletePayment(
        settled,
        added,
        ledgerTitle: 'بازپرداخت به علی',
        expenses: ep,
        incomes: ip,
      );
      expect(entry, isNotNull);
      expect(dp.open.single.remainingMinor, 600000);
      expect(ep.raw.length, expensesBefore);
      await dp.restorePayment(
        settled,
        added.gid,
        entry,
        expenses: ep,
        incomes: ip,
      );
      expect(dp.open, isEmpty);
      expect(ep.raw.length, expensesBefore + 1);
    });

    test('a payment takes its History entry back with it', () async {
      final dp = DebtProvider()..setDisplayCurrency('IRT');
      final ep = ExpenseProvider();
      final ip = IncomeProvider();
      await ep.init();
      await ip.init();
      await dp.importFromBackup(debtsJson: const [], paymentsJson: const []);
      int titled(String t) => ep.raw.where((e) => e['title'] == t).length;
      const title = 'بازپرداخت به رضا';

      await dp.add(
        direction: DebtDirection.owe,
        person: 'رضا',
        amountMinor: 300000,
        startedLocal: DateTime(2026, 10, 1),
      );
      // Paid and added: linked.
      await dp.pay(
        dp.open.single,
        amountMinor: 300000,
        paidLocal: DateTime(2026, 10, 3),
        ledgerTitle: title,
        expenses: ep,
      );
      var v = dp.settled.single;
      var p = v.payments.single;
      expect(p.ledgerGid, isNotNull);
      expect(await dp.ledgerEntryOf(v, p, title: title), p.ledgerGid);

      // Undo: open again, and the expense is gone too.
      await dp.undoPayment(
        v,
        p,
        ledgerTitle: title,
        expenses: ep,
        incomes: ip,
      );
      expect(dp.open.single.remainingMinor, 300000);
      expect(titled(title), 0);

      // Paid without adding, then saved into History later, with its date
      // changed: one expense, on the new date; saving again adds none.
      await dp.pay(
        dp.open.single,
        amountMinor: 300000,
        paidLocal: DateTime(2026, 10, 4),
      );
      v = dp.settled.single;
      p = v.payments.single;
      expect(await dp.ledgerEntryOf(v, p, title: title), isNull);
      await dp.recordPayment(
        v,
        p,
        amountMinor: 300000,
        paidLocal: DateTime(2026, 10, 6),
        ledgerTitle: title,
        expenses: ep,
        incomes: ip,
      );
      v = dp.settled.single;
      p = v.payments.single;
      expect(p.paidAtUtc.toLocal(), DateTime(2026, 10, 6));
      expect(titled(title), 1);
      await dp.recordPayment(
        v,
        p,
        amountMinor: 250000,
        paidLocal: DateTime(2026, 10, 6),
        ledgerTitle: title,
        expenses: ep,
        incomes: ip,
      );
      expect(titled(title), 1);
      expect(
        ep.raw.where((e) => e['title'] == title).single['amountMinor'],
        250000,
      );
      // Less than the debt now: open again.
      expect(dp.open.single.remainingMinor, 50000);
    });

    test('a payment from before links were kept finds its entry', () async {
      final dp = DebtProvider()..setDisplayCurrency('IRT');
      final ep = ExpenseProvider();
      final ip = IncomeProvider();
      await ep.init();
      await ip.init();
      await dp.importFromBackup(
        debtsJson: [
          {
            'gid': 'old1',
            'direction': 'owe',
            'person': 'مینا',
            'amountMinor': 70000,
            'currency': 'IRT',
            'startedAtUtc': '2026-09-01T00:00:00.000Z',
          },
        ],
        paymentsJson: [
          {
            'gid': 'oldp1',
            'debtGid': 'old1',
            'amountMinor': 70000,
            'currency': 'IRT',
            'paidAtUtc': DateTime(2026, 9, 9).toUtc().toIso8601String(),
          },
        ],
      );
      const title = 'بازپرداخت به مینا';
      await ep.addExpense(
        title: title,
        amountMinor: 70000,
        occurredLocal: DateTime(2026, 9, 9),
        currency: 'IRT',
      );
      final v = dp.settled.single;
      final p = v.payments.single;
      expect(p.ledgerGid, isNull);
      expect(await dp.ledgerEntryOf(v, p, title: title), isNotNull);
      expect(await dp.ledgerEntryOf(v, p, title: 'other'), isNull);
      await dp.undoPayment(
        v,
        p,
        ledgerTitle: title,
        expenses: ep,
        incomes: ip,
      );
      expect(ep.raw.where((e) => e['title'] == title), isEmpty);
    });

    test('rial view converts, stored amounts stay as recorded', () async {
      final dp = DebtProvider()..setDisplayCurrency('IRT');
      await dp.importFromBackup(
        debtsJson: [
          {
            'gid': 'd1',
            'direction': 'owed',
            'person': 'سارا',
            'amountMinor': 500000,
            'currency': 'IRT',
            'startedAtUtc': '2026-09-01T00:00:00.000Z',
            'dueAtUtc': '2026-12-01T00:00:00.000Z',
          },
        ],
        paymentsJson: [
          {
            'gid': 'p1',
            'debtGid': 'd1',
            'amountMinor': 1000000, // recorded in rial = 100,000 toman
            'currency': 'IRR',
            'paidAtUtc': '2026-09-10T00:00:00.000Z',
          },
          {'gid': 'p2', 'debtGid': 'gone', 'amountMinor': 1},
        ],
      );
      expect(dp.open.single.remainingMinor, 400000);
      expect(dp.totalFor(DebtDirection.owed), 400000);

      dp.setDisplayCurrency('IRR');
      expect(dp.open.single.debt.amountMinor, 5000000);
      expect(dp.open.single.remainingMinor, 4000000);

      // Export carries the recorded values; the orphan payment was dropped.
      final out = await dp.exportForBackup();
      final d = _list(out['debts']).single;
      expect(d['amountMinor'], 500000);
      expect(d['currency'], 'IRT');
      expect(d['dueAtUtc'], '2026-12-01T00:00:00.000Z');
      expect(_list(out['debtPayments']).map((p) => p['gid']), ['p1']);

      // Restoring the export twice gives the same, without copies.
      await dp.importFromBackup(
        debtsJson: _list(out['debts']),
        paymentsJson: _list(out['debtPayments']),
      );
      await dp.importFromBackup(
        debtsJson: _list(out['debts']),
        paymentsJson: _list(out['debtPayments']),
      );
      expect(dp.open.single.debt.gid, 'd1');
      expect(dp.open.single.payments.single.gid, 'p1');
      final rows = await AppDb.instance.db.query('debts');
      // d1 + the soft-deleted ones from the tests before.
      expect(rows.length, 4);
    });
  });

  // Full round trip of the generated sample (tool/make_sample_backup.py),
  // when it has been generated locally.
  final sample = Directory('build/sample_backup').existsSync()
      ? Directory('build/sample_backup')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .firstOrNull
      : null;
  test(
    'sample backup restores completely',
    skip: sample == null ? 'run tool/make_sample_backup.py first' : false,
    () async {
      final data =
          jsonDecode(await sample!.readAsString()) as Map<String, dynamic>;
      final ep = ExpenseProvider();
      final ip = IncomeProvider();
      final up = UpcomingProvider();

      await ep.importFromBackup(
        categoriesJson: _list(data['categories']),
        expensesJson: _list(data['expenses']),
      );
      await ip.importFromBackup(
        categoriesJson: _list(data['incomeCategories']),
        incomesJson: _list(data['incomes']),
      );
      await up.importFromBackup(
        upcomingJson: _list(data['upcoming']),
        historyJson: _list(data['upcomingHistory']),
      );

      expect(ep.raw.length, (data['expenses'] as List).length);
      expect(ip.raw.length, (data['incomes'] as List).length);
      expect(up.items.length, (data['upcoming'] as List).length);
      final dp = DebtProvider();
      await dp.importFromBackup(
        debtsJson: _list(data['debts']),
        paymentsJson: _list(data['debtPayments']),
      );
      expect(
        dp.open.length + dp.settled.length,
        (data['debts'] as List).length,
      );
      expect(dp.settled, isNotEmpty);
      expect(dp.titles(DebtDirection.owe), isNotEmpty);
      final again2 = await dp.exportForBackup();
      expect(
        _list(again2['debtPayments']).length,
        (data['debtPayments'] as List).length,
      );
      final catGids = ep.categories.map((c) => c.gid).toSet();
      for (final c in _list(data['categories'])) {
        expect(catGids, contains(c['gid']));
      }
      // Every expense points at a restored category (or none).
      for (final e in ep.raw) {
        final g = e['categoryGid'];
        if (g != null) expect(catGids, contains(g));
      }

      // Export -> restore again gives the same data back.
      final again = await ep.exportForBackup();
      await ep.importFromBackup(
        categoriesJson: _list(again['categories']),
        expensesJson: _list(again['expenses']),
      );
      expect(ep.raw.length, (data['expenses'] as List).length);
    },
  );
}

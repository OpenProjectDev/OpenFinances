// Backups (lib/data/backup.dart): every format gives back exactly what was
// backed up, "expenses only" carries its categories, replace and merge do
// what they say, old backups still read.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/backup.dart';
import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/data/currency_units.dart';
import 'package:openfinances/data/db.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Database get _db => AppDb.instance.db;

const _tables = [
  'categories',
  'income_categories',
  'expenses',
  'incomes',
  'upcoming_payments',
  'upcoming_history',
  'debts',
  'debt_payments',
];

Future<void> _wipe() async {
  await CategoryRepository().ensureColumns();
  await CategoryRepository(table: 'income_categories').ensureColumns();
  for (final t in _tables) {
    await _db.delete(t);
  }
}

Map<String, Object?> _cat(
  String gid,
  String name, {
  String upd = '2024-01-01T00:00:00.000Z',
}) => {
  'gid': gid,
  'name': name,
  'sort': 100,
  'color': 0xFF43A047,
  'iconCodePoint': 0xe59c,
  'iconFontFamily': 'UIconsSR',
  'createdAtUtc': '2024-01-01T00:00:00.000Z',
  'updatedAtUtc': upd,
  'isDeleted': 0,
  'isDirty': 0,
};

Map<String, Object?> _entry(
  String gid,
  String title,
  int minor, {
  String cat = 'c1',
  String upd = '2024-05-02T09:00:00.000Z',
}) => {
  'gid': gid,
  'title': title,
  'amountMinor': minor,
  'currency': 'IRT',
  'occurredAtUtc': '2024-05-01T08:30:00.000Z',
  'note': 'یادداشت',
  'categoryGid': cat,
  'accountGid': null,
  'version': 3,
  'createdAtUtc': '2024-05-01T09:00:00.000Z',
  'updatedAtUtc': upd,
  'isDeleted': 0,
  'isDirty': 0,
};

/// A phone with one of everything.
Future<void> _seed() async {
  await _wipe();
  await _db.insert('categories', _cat('c1', 'خوراک'));
  await _db.insert('income_categories', _cat('i1', 'حقوق'));
  await _db.insert('expenses', _entry('e1', 'نان', 5000000));
  await _db.insert('expenses', _entry('e2', 'میوه', 25000000));
  await _db.insert('incomes', _entry('n1', 'حقوق', 900000000, cat: 'i1'));
  await _db.insert('upcoming_payments', {
    'gid': 'u1',
    'title': 'اجاره',
    'amountMinor': 1500000000,
    'currency': 'IRR',
    'dueAtUtc': '2024-06-01T00:00:00.000Z',
    'note': null,
    'categoryGid': 'c1',
    'version': 2,
    'createdAtUtc': '2024-05-01T09:00:00.000Z',
    'updatedAtUtc': '2024-05-03T09:00:00.000Z',
    'isDeleted': 0,
    'isDirty': 0,
  });
  await _db.insert('upcoming_history', {
    'title': 'اجاره',
    'amountMinor': 1500000000,
    'categoryGid': 'c1',
    'lastUsedAtUtc': '2024-05-01T09:00:00.000Z',
    'currency': 'IRR',
  });
  await _db.insert('debts', {
    'gid': 'd1',
    'direction': 'owed',
    'person': 'سارا',
    'title': 'وام',
    'amountMinor': 300000000,
    'currency': 'IRT',
    'startedAtUtc': '2024-04-01T00:00:00.000Z',
    'dueAtUtc': null,
    'note': 'قسطی',
    'version': 1,
    'createdAtUtc': '2024-04-01T00:00:00.000Z',
    'updatedAtUtc': '2024-04-02T00:00:00.000Z',
    'isDeleted': 0,
    'isDirty': 0,
  });
  await _db.insert('debt_payments', {
    'gid': 'p1',
    'debtGid': 'd1',
    'amountMinor': 100000000,
    'currency': 'IRT',
    'paidAtUtc': '2024-04-15T00:00:00.000Z',
    'version': 1,
    'createdAtUtc': '2024-04-15T00:00:00.000Z',
    'updatedAtUtc': '2024-04-15T00:00:00.000Z',
    'isDeleted': 0,
    'isDirty': 0,
  });
}

const _prefs = <String, Object>{
  'locale': 'fa',
  'seedColor': 4278221012,
  'biometric': true,
  'smsSeenV1': ['k1', 'k2'],
  kBudgetsPrefsKey: '{"c1":2000000000}',
  kBudgetsUnitPrefsKey: 'IRT',
};

final _bank = <String, Object?>{
  'formats': [
    {
      'skeleton': 'برداشت #',
      'runIndex': 1,
      'kind': 'expense',
      'rialPerUnit': 1,
      'createdAt': 1714550000000,
      'name': 'ملی',
    },
  ],
  'messages': [
    {
      'key': 'k1',
      'text': 'برداشت 120,000',
      'sender': 'Melli',
      'postedAt': 1714550000000,
      'package': 'com.x',
    },
  ],
  'ignoredSenders': ['Spam'],
};

/// Every live row of every table, without the internal id, by key.
Future<Map<String, List<Map<String, Object?>>>> _dump() async => {
  for (final t in _tables)
    t: [
      for (final r in await _db.query(
        t,
        where: t == 'upcoming_history' ? null : 'isDeleted = 0',
        orderBy: t == 'upcoming_history' ? 'title' : 'gid',
      ))
        {
          for (final e in r.entries)
            if (e.key != 'id' && e.key != 'isDirty' && e.key != 'ruleGid')
              e.key: e.value,
        },
    ],
};

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
  });

  for (final excel in [false, true]) {
    test(
      'a full ${excel ? 'Excel' : 'JSON'} backup restores exactly',
      () async {
        await _seed();
        SharedPreferences.setMockInitialValues(_prefs);
        final before = await _dump();
        final b = await BackupData.collect(full: true, bank: () async => _bank);
        final back = excel
            ? BackupData.fromXlsx(b.toXlsx())
            : BackupData.fromJson(jsonDecode(utf8.decode(b.toJsonBytes())));

        await _wipe();
        SharedPreferences.setMockInitialValues({});
        Map<String, Object?>? imported;
        final report = await back.restore(
          merge: false,
          importBank: (d) async => imported = d,
        );

        expect(report.skipped, 0);
        expect(await _dump(), before);
        final sp = await SharedPreferences.getInstance();
        expect(sp.getString('locale'), 'fa');
        expect(sp.getInt('seedColor'), 4278221012);
        expect(sp.getBool('biometric'), isTrue);
        expect(sp.getStringList('smsSeenV1'), ['k1', 'k2']);
        expect(jsonDecode(sp.getString(kBudgetsPrefsKey)!), {'c1': 2000000000});
        expect(sp.getString(kBudgetsUnitPrefsKey), 'IRT');
        expect(jsonEncode(imported), jsonEncode(_bank));
      },
    );
  }

  test('"expenses only" carries its categories and budgets', () async {
    await _seed();
    SharedPreferences.setMockInitialValues(_prefs);
    final b = await BackupData.collect(full: false);
    expect(b.tables.keys, unorderedEquals(['categories', 'expenses']));
    expect(b.budgets, {'c1': 2000000000});
    expect(b.prefs, isNull);
    expect(b.bank, isNull);
  });

  test('a full backup carries the backups\' folder, and restores it', () async {
    SharedPreferences.setMockInitialValues({
      'backupFolder': 'content://x/tree/primary%3ABackups',
      'backupFolderName': 'Backups',
    });
    final full = await BackupData.collect(
      full: true,
      settings: const {},
      bank: () async => _bank,
    );
    final text = utf8.decode(full.toJsonBytes());
    expect(text, contains('backupFolderName'));
    SharedPreferences.setMockInitialValues({});
    await BackupData.fromJson(jsonDecode(text)).restore(merge: false);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('backupFolder'), 'content://x/tree/primary%3ABackups');
    expect(sp.getString('backupFolderName'), 'Backups');
  });

  test('replacing leaves the parts the backup lacks', () async {
    await _seed();
    SharedPreferences.setMockInitialValues(_prefs);
    final b = await BackupData.collect(full: false);
    await _db.delete('expenses');
    await _db.insert('expenses', _entry('x9', 'new', 1));
    await BackupData.fromJson(
      jsonDecode(utf8.decode(b.toJsonBytes())),
    ).restore(merge: false);
    final d = await _dump();
    expect(d['expenses']!.map((e) => e['gid']), ['e1', 'e2']);
    expect(d['incomes']!.length, 1, reason: 'not in the backup: kept');
    expect(d['debts']!.length, 1);
  });

  test('merging: newer copies win, same-named categories join', () async {
    await _seed();
    SharedPreferences.setMockInitialValues(_prefs);
    // The backup: e1 changed later than the phone's, e2 older, a new e3 in
    // a category named like the phone's "خوراک" but with its own gid.
    final backup = BackupData.fromJson({
      'version': 4,
      'categories': [_cat('cX', 'خوراک')],
      'expenses': [
        _entry('e1', 'نان تازه', 6000000, upd: '2024-06-01T00:00:00.000Z'),
        _entry('e2', 'میوه کهنه', 1, upd: '2024-01-01T00:00:00.000Z'),
        _entry('e3', 'پنیر', 7000000, cat: 'cX'),
      ],
      'budgets': {'cX': 50000, 'c1': 1},
      'budgetsUnit': 'IRR',
      'prefsDump': {
        'locale': 'en',
        'smsSeenV1': ['k2', 'k3'],
        'tabSms': true,
      },
      'prefTypes': {'locale': 'string', 'smsSeenV1': 'list', 'tabSms': 'bool'},
    });
    await backup.restore(merge: true);

    final d = await _dump();
    final byGid = {for (final e in d['expenses']!) e['gid']: e};
    expect(byGid['e1']!['title'], 'نان تازه', reason: 'backup newer');
    expect(byGid['e2']!['title'], 'میوه', reason: 'phone newer');
    expect(byGid['e3']!['categoryGid'], 'c1', reason: 'joined by name');
    expect(d['categories']!.map((c) => c['gid']), ['c1']);
    expect(d['incomes']!.length, 1);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('locale'), 'fa', reason: 'the app’s settings stay');
    expect(sp.getBool('tabSms'), isTrue, reason: 'missing: filled in');
    expect(sp.getStringList('smsSeenV1'), ['k1', 'k2', 'k3']);
    // The phone's budget stays; nothing new (cX became c1, budgeted).
    expect(jsonDecode(sp.getString(kBudgetsPrefsKey)!), {'c1': 2000000000});
  });

  test('replacing: the backup’s categories are the ones left', () async {
    await _seed();
    SharedPreferences.setMockInitialValues(_prefs);
    await _db.insert('categories', _cat('c2', 'سفر'));
    await BackupData.fromJson({
      'version': 4,
      'categories': [_cat('cX', 'خوراک')],
      'expenses': [_entry('e3', 'پنیر', 7000000, cat: 'cX')],
    }).restore(merge: false);
    final d = await _dump();
    expect(d['categories']!.map((c) => c['gid']), ['cX']);
    expect(d['expenses']!.map((e) => e['gid']), ['e3']);
  });

  test(
    'unreadable rows and orphan payments are counted, not written',
    () async {
      await _seed();
      SharedPreferences.setMockInitialValues({});
      final r = await BackupData.fromJson({
        'version': 4,
        'expenses': [
          _entry('e7', '', 5),
          _entry('e8', 'ok', 5),
          {'gid': 'e9', 'title': 'no amount', 'occurredAtUtc': '2024-01-01'},
        ],
        'debts': <Object>[],
        'debtPayments': [
          {
            'gid': 'pX',
            'debtGid': 'nope',
            'amountMinor': 1,
            'paidAtUtc': '2024-01-01',
          },
        ],
      }).restore(merge: false);
      expect(r.skipped, 3);
      expect((await _dump())['expenses']!.map((e) => e['gid']), ['e8']);
    },
  );

  test('backups from before format 3 come back in minor units', () async {
    await _wipe();
    SharedPreferences.setMockInitialValues({});
    await BackupData.fromJson({
      'version': 2,
      'expenses': [_entry('e1', 'نان', 50000)],
      'budgets': {'c1': 2000},
    }).restore(merge: false);
    expect((await _dump())['expenses']!.single['amountMinor'], 5000000);
    final sp = await SharedPreferences.getInstance();
    expect(jsonDecode(sp.getString(kBudgetsPrefsKey)!), {'c1': 200000});
  });

  test('an older JSON backup (no pref types) keeps each pref’s type', () async {
    await _wipe();
    SharedPreferences.setMockInitialValues({'startDay': 1});
    await BackupData.fromJson({
      'version': 3,
      'expenses': [_entry('e1', 'نان', 5)],
      'prefsDump': {'startDay': '15', 'tabSms': 'true', 'locale': 'en'},
    }).restore(merge: false);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getInt('startDay'), 15);
    expect(sp.getBool('tabSms'), isTrue);
    expect(sp.getString('locale'), 'en');
  });

  // Shapes the app wrote before format 4, back to jibyar's first build
  // (from git history: 230e910 on).
  test('jibyar\'s first JSON: budgets in its own currency', () async {
    await _wipe();
    // This phone's budgets are in toman; the backup's app was in rial.
    SharedPreferences.setMockInitialValues({kBudgetsUnitPrefsKey: 'IRT'});
    await BackupData.fromJson({
      'version': 3,
      'updatedAt': '2025-09-26T10:00:00.000Z',
      'expenses': [_entry('e1', 'نان', 5000000)..remove('currency')],
      'categories': [_cat('c1', 'خوراک')],
      'settings': {'currencyCode': 'IRR', 'startDay': 1},
      'budgets': {'c1': 9000000},
      'prefsDump': {'currency': 'IRR', '_budget_migrated_v3': 'true'},
    }).restore(merge: false);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString(kBudgetsUnitPrefsKey), 'IRR');
    expect(jsonDecode(sp.getString(kBudgetsPrefsKey)!), {'c1': 9000000});
    // A row without its currency was in the app's.
    expect((await _dump())['expenses']!.single['currency'], 'IRR');
  });

  test('budgets the old Budget page never converted come back x100', () async {
    await _wipe();
    SharedPreferences.setMockInitialValues({});
    await BackupData.fromJson({
      'version': 3,
      'expenses': [_entry('e1', 'نان', 5)],
      'budgets': {'c1': 2000},
      'prefsDump': {'currency': 'IRT'},
    }).restore(merge: false);
    final sp = await SharedPreferences.getInstance();
    expect(jsonDecode(sp.getString(kBudgetsPrefsKey)!), {'c1': 200000});
  });

  test('the oldest "amount" is whole units, scaled once', () async {
    for (final version in [2, 3]) {
      await _wipe();
      SharedPreferences.setMockInitialValues({});
      await BackupData.fromJson({
        'version': version,
        'expenses': [
          {
            'gid': 'e1',
            'title': 'نان',
            'amount': 12.5,
            'occurredAt': '2025-01-01T08:00:00.000Z',
          },
        ],
      }).restore(merge: false);
      expect((await _dump())['expenses']!.single['amountMinor'], 1250);
    }
  });

  test('upcoming history without a currency keeps none', () async {
    await _wipe();
    SharedPreferences.setMockInitialValues({});
    await BackupData.fromJson({
      'version': 3,
      'expenses': [_entry('e1', 'نان', 5)],
      'upcomingHistory': [
        {
          'title': 'اجاره',
          'amountMinor': 100,
          'categoryGid': 'c1',
          'lastUsedAtUtc': '2025-01-01T00:00:00.000Z',
        },
      ],
    }).restore(merge: false);
    expect((await _dump())['upcoming_history']!.single['currency'], isNull);
  });

  test(
    'old Excel rows without times or icons: the app\'s copy stays',
    () async {
      await _seed();
      SharedPreferences.setMockInitialValues(_prefs);
      final appCat = (await _dump())['categories']!.single;
      // As old EXPENSES / CATEGORIES sheets had them: no times, no icons.
      final old = BackupData.fromJson({
        'version': 3,
        'categories': [
          {'gid': 'c1', 'name': 'خوراک', 'color': "'4282557941", 'sort': 5},
        ],
        'expenses': [
          {
            'gid': 'e1',
            'title': 'old title',
            'amountMinor': 1,
            'currency': 'IRT',
            'occurredAtUtc': '2024-05-01T08:30:00.000Z',
            'categoryGid': 'c1',
          },
        ],
      });
      await old.restore(merge: true);
      final after = await _dump();
      expect(
        after['expenses']!.firstWhere((e) => e['gid'] == 'e1')['title'],
        'نان',
      );
      // Replacing: its own name and color, the app's icon.
      await old.restore(merge: false);
      final cat = (await _dump())['categories']!.single;
      expect(cat['color'], 4282557941);
      expect(cat['iconCodePoint'], appCat['iconCodePoint']);
      expect(cat['iconFontFamily'], appCat['iconFontFamily']);
    },
  );

  test('entries of a category the app lacks go to the fallback', () async {
    await _seed();
    SharedPreferences.setMockInitialValues(_prefs);
    await BackupData.fromJson({
      'version': 4,
      'expenses': [_entry('e7', 'x', 1, cat: 'gone')],
    }).restore(merge: true);
    final e = (await _dump())['expenses']!.firstWhere((e) => e['gid'] == 'e7');
    expect(e['categoryGid'], 'c1');
  });

  test('bank data merges by layout and message', () {
    final m = mergeBank(
      {
        'formats': [
          {'skeleton': 'a', 'name': 'mine'},
        ],
        'messages': [
          {'key': 'k1', 'postedAt': 1},
        ],
        'ignoredSenders': ['x'],
      },
      {
        'formats': [
          {'skeleton': 'a', 'name': 'theirs'},
          {'skeleton': 'b'},
        ],
        'messages': [
          {'key': 'k1', 'postedAt': 1},
          {'key': 'k2', 'postedAt': 2},
        ],
        'ignoredSenders': ['x', 'y'],
      },
    );
    expect((m['formats'] as List).map((f) => (f as Map)['name']), [
      'mine',
      null,
    ]);
    expect((m['messages'] as List).map((f) => (f as Map)['key']), ['k2', 'k1']);
    expect(m['ignoredSenders'], ['x', 'y']);
  });

  test('a file that isn’t a backup is refused', () {
    expect(() => BackupData.fromJson([1, 2]), throwsFormatException);
    expect(() => BackupData.fromJson({'hello': 1}), throwsFormatException);
  });
}

// lib/data/backup.dart
// Backups and restores, in one place.
//
// A backup is every live row of the user's tables (all their columns), the
// budgets, the settings and every other pref (with its type), and the bank
// message data (formats, caught messages, ignored senders). It's written as
// JSON or Excel (a sheet per part, a row per item) and read back from
// either, or from the old CSV.
//
// A restore reads and checks the whole file first (nothing is touched if it
// can't be read), then writes every table in ONE transaction, either
// replacing what the app has (each part the backup has; a part it doesn't
// have stays as it is) or merging into it (of two copies of an item the
// newer wins; a backup category named like one of the app's joins it).
// Then the budgets, the prefs and the bank data. Rows that can't be read
// are counted, not lost silently.

import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart' show Color, Icons;
import 'package:flutter/services.dart' show Uint8List;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:openfinances/data/backup_values.dart';
import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/data/currency_units.dart';
import 'package:openfinances/data/db.dart';

/// The format written now: 4 = every table column, pref types, bank data
/// as rows in Excel. (3: the format since the repo's start; below 3,
/// amounts were whole units, not minor.)
const int kBackupVersion = 4;

enum ColKind { text, int, date }

/// One table of the user's data, as it goes into a backup.
class BackupTable {
  const BackupTable({
    required this.table,
    required this.key,
    required this.sheet,
    required this.columns,
    required this.required,
    this.keyColumn = 'gid',
    this.newerColumn = 'updatedAtUtc',
    this.categoryTable,
    this.inExpensesOnly = false,
  });

  /// The DB table, the JSON key and the Excel sheet.
  final String table, key, sheet;

  /// Every column backed up, in order, with how to read it back.
  final Map<String, ColKind> columns;

  /// Columns a row can't do without (else it's skipped and counted).
  final List<String> required;

  /// What tells two copies of an item apart, and which is newer (merge).
  final String keyColumn, newerColumn;

  /// The category table its `categoryGid` points into (if any).
  final String? categoryTable;

  /// Also in "expenses only" backups.
  final bool inExpensesOnly;

  /// Live rows only; deleting flags them (`isDeleted`).
  bool get softDeletes => keyColumn == 'gid';

  bool get isCategories =>
      table == 'categories' || table == 'income_categories';
}

const _entry = {
  'gid': ColKind.text,
  'title': ColKind.text,
  'amountMinor': ColKind.int,
  'currency': ColKind.text,
  'occurredAtUtc': ColKind.date,
  'note': ColKind.text,
  'categoryGid': ColKind.text,
  'accountGid': ColKind.text,
  'version': ColKind.int,
  'createdAtUtc': ColKind.date,
  'updatedAtUtc': ColKind.date,
};
const _category = {
  'gid': ColKind.text,
  'name': ColKind.text,
  'sort': ColKind.int,
  'color': ColKind.int,
  'iconCodePoint': ColKind.int,
  'iconFontFamily': ColKind.text,
  'createdAtUtc': ColKind.date,
  'updatedAtUtc': ColKind.date,
};

/// Every table, in the order a restore writes them (categories first: the
/// rest point into them; debts before their payments).
const List<BackupTable> kBackupTables = [
  BackupTable(
    table: 'categories',
    key: 'categories',
    sheet: 'CATEGORIES',
    columns: _category,
    required: ['gid', 'name'],
    inExpensesOnly: true,
  ),
  BackupTable(
    table: 'income_categories',
    key: 'incomeCategories',
    sheet: 'INCOME_CATEGORIES',
    columns: _category,
    required: ['gid', 'name'],
  ),
  BackupTable(
    table: 'expenses',
    key: 'expenses',
    sheet: 'EXPENSES',
    columns: _entry,
    required: ['title', 'amountMinor', 'occurredAtUtc'],
    categoryTable: 'categories',
    inExpensesOnly: true,
  ),
  BackupTable(
    table: 'incomes',
    key: 'incomes',
    sheet: 'INCOMES',
    columns: _entry,
    required: ['title', 'amountMinor', 'occurredAtUtc'],
    categoryTable: 'income_categories',
  ),
  BackupTable(
    table: 'upcoming_payments',
    key: 'upcoming',
    sheet: 'UPCOMING',
    columns: {
      'gid': ColKind.text,
      'title': ColKind.text,
      'amountMinor': ColKind.int,
      'currency': ColKind.text,
      'dueAtUtc': ColKind.date,
      'note': ColKind.text,
      'categoryGid': ColKind.text,
      'paidAtUtc': ColKind.date,
      'ledgerGid': ColKind.text,
      'nextGid': ColKind.text,
      'version': ColKind.int,
      'createdAtUtc': ColKind.date,
      'updatedAtUtc': ColKind.date,
    },
    required: ['title', 'amountMinor', 'dueAtUtc'],
    categoryTable: 'categories',
  ),
  BackupTable(
    table: 'upcoming_history',
    key: 'upcomingHistory',
    sheet: 'UPCOMING_HISTORY',
    columns: {
      'title': ColKind.text,
      'amountMinor': ColKind.int,
      'categoryGid': ColKind.text,
      'lastUsedAtUtc': ColKind.date,
      'currency': ColKind.text,
    },
    required: ['title', 'amountMinor'],
    keyColumn: 'title',
    newerColumn: 'lastUsedAtUtc',
    categoryTable: 'categories',
  ),
  BackupTable(
    table: 'debts',
    key: 'debts',
    sheet: 'DEBTS',
    columns: {
      'gid': ColKind.text,
      'direction': ColKind.text,
      'person': ColKind.text,
      'title': ColKind.text,
      'amountMinor': ColKind.int,
      'currency': ColKind.text,
      'startedAtUtc': ColKind.date,
      'dueAtUtc': ColKind.date,
      'note': ColKind.text,
      'version': ColKind.int,
      'createdAtUtc': ColKind.date,
      'updatedAtUtc': ColKind.date,
    },
    required: ['person', 'amountMinor', 'startedAtUtc'],
  ),
  BackupTable(
    table: 'debt_payments',
    key: 'debtPayments',
    sheet: 'DEBT_PAYMENTS',
    columns: {
      'gid': ColKind.text,
      'debtGid': ColKind.text,
      'amountMinor': ColKind.int,
      'currency': ColKind.text,
      'paidAtUtc': ColKind.date,
      'ledgerGid': ColKind.text,
      'version': ColKind.int,
      'createdAtUtc': ColKind.date,
      'updatedAtUtc': ColKind.date,
    },
    required: ['debtGid', 'amountMinor', 'paidAtUtc'],
  ),
];

/// Prefs a restore handles itself (the budgets and their unit).
const _budgetPrefs = {kBudgetsPrefsKey, kBudgetsUnitPrefsKey};
const _budgetsMigratedKey = '_budget_migrated_v3';

/// What a restore did.
class RestoreReport {
  const RestoreReport({required this.restored, required this.skipped});

  /// Rows written (or kept as the newer copy, merging).
  final int restored;

  /// Rows the backup had that couldn't be read (no title, no amount…).
  final int skipped;
}

/// A backup, read or about to be written.
class BackupData {
  BackupData({
    this.version,
    required this.tables,
    this.budgets,
    this.budgetsUnit,
    this.settings,
    this.prefs,
    this.prefTypes = const {},
    this.bank,
    this.unreadable = 0,
  });

  /// The last restore's report, for the app to tell after it restarts.
  static RestoreReport? lastRestore;

  /// The file's format version (null: not stated, e.g. CSV).
  final int? version;

  /// By [BackupTable.key]: the parts the backup has (an empty list is a
  /// part with nothing in it; a missing key, a part it doesn't have).
  final Map<String, List<Map<String, Object?>>> tables;

  /// Category gid → budget (minor units, in [budgetsUnit]).
  final Map<String, int>? budgets;
  final String? budgetsUnit;

  /// The old settings block (older backups had no prefs).
  final Map<String, Object?>? settings;

  /// Every pref, and its type ('bool', 'int', 'double', 'string', 'list').
  final Map<String, Object?>? prefs;
  final Map<String, String> prefTypes;

  /// The bank data: 'formats' and 'messages' (lists of maps) and
  /// 'ignoredSenders' (a list of names).
  final Map<String, Object?>? bank;

  /// Parts of the file that couldn't be read while reading it (an old
  /// Excel cell cut short), counted with the rows a restore leaves out.
  final int unreadable;

  /// The currency the backup's app was set to (older rows without their
  /// own were in it).
  String get _currency =>
      backupString(prefs?['currency']) ??
      backupString(settings?['currencyCode']) ??
      'IRR';

  // ---------------- Collecting ----------------

  /// Everything there is to back up, read straight from the DB and prefs:
  /// any part that can't be read fails the backup (never a backup that
  /// says saved but lacks a part). [full] false: expenses, their
  /// categories and the budgets. [settings]: the old settings block (for
  /// older app versions); [bank]: reads the bank data (full backups).
  static Future<BackupData> collect({
    required bool full,
    Map<String, Object?>? settings,
    Future<Map<String, Object?>> Function()? bank,
  }) async {
    final db = AppDb.instance.db;
    await _ensureCategoryColumns();
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in kBackupTables) {
      if (!full && !t.inExpensesOnly) continue;
      final rows = await db.query(
        t.table,
        where: t.softDeletes ? 'isDeleted = 0' : null,
      );
      tables[t.key] = [
        for (final r in rows) {for (final c in t.columns.keys) c: r[c]},
      ];
    }
    final sp = await SharedPreferences.getInstance();
    final budgets = _readBudgets(sp.getString(kBudgetsPrefsKey));
    if (budgets == null) {
      throw const FormatException('the budgets could not be read');
    }
    Map<String, Object?>? prefs;
    if (full) {
      prefs = {for (final k in sp.getKeys()) k: sp.get(k)};
    }
    return BackupData(
      version: kBackupVersion,
      tables: tables,
      budgets: budgets,
      budgetsUnit: sp.getString(kBudgetsUnitPrefsKey),
      settings: full ? settings : null,
      prefs: prefs,
      prefTypes: {
        if (prefs != null)
          for (final e in prefs.entries) e.key: _typeOf(e.value),
      },
      bank: full && bank != null ? await bank() : null,
    );
  }

  /// Whether the app holds any data of the user's (entries, upcoming
  /// payments, debts): a restore then asks what to do with it.
  static Future<bool> appHasData() async {
    final db = AppDb.instance.db;
    for (final t in const [
      'expenses',
      'incomes',
      'upcoming_payments',
      'debts',
    ]) {
      final n = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $t WHERE isDeleted = 0'),
      );
      if ((n ?? 0) > 0) return true;
    }
    return false;
  }

  // ---------------- JSON ----------------

  Map<String, Object?> toJson() => {
    'version': kBackupVersion,
    'updatedAt': DateTime.now().toIso8601String(),
    ...tables,
    if (budgets != null) 'budgets': budgets,
    if (budgetsUnit != null) 'budgetsUnit': budgetsUnit,
    if (settings != null) 'settings': settings,
    if (prefs != null) 'prefsDump': prefs,
    if (prefs != null) 'prefTypes': prefTypes,
    if (bank != null) 'bankData': bank,
  };

  Uint8List toJsonBytes() => Uint8List.fromList(
    utf8.encode(
      JsonEncoder(
        (o) => o is DateTime ? o.toIso8601String() : '$o',
      ).convert(toJson()),
    ),
  );

  /// From a JSON backup (any version); throws [FormatException] if it isn't
  /// one.
  static BackupData fromJson(Object? data) {
    if (data is! Map) throw const FormatException('not a backup');
    List<Map<String, Object?>> rows(Object? v) => [
      for (final r in (v as List))
        if (r is Map) Map<String, Object?>.from(r),
    ];
    final tables = <String, List<Map<String, Object?>>>{
      for (final t in kBackupTables)
        if (data[t.key] is List) t.key: rows(data[t.key]),
    };
    if (tables.isEmpty) throw const FormatException('no data in it');
    final b = data['budgets'];
    final prefs = data['prefsDump'];
    final types = data['prefTypes'];
    return BackupData(
      version: backupInt(data['version']),
      tables: tables,
      budgets: b is Map
          ? {for (final e in b.entries) '${e.key}': backupInt(e.value) ?? 0}
          : null,
      budgetsUnit: backupString(data['budgetsUnit']),
      settings: data['settings'] is Map
          ? Map<String, Object?>.from(data['settings'] as Map)
          : null,
      prefs: prefs is Map ? Map<String, Object?>.from(prefs) : null,
      prefTypes: types is Map
          ? {for (final e in types.entries) '${e.key}': '${e.value}'}
          : const {},
      bank: data['bankData'] is Map
          ? Map<String, Object?>.from(data['bankData'] as Map)
          : null,
    );
  }

  // ---------------- Excel ----------------

  /// A sheet per part, a row per item (bank messages too: no cell near
  /// Excel's 32,767-character limit), numbers as numbers.
  Uint8List toXlsx() {
    final excel = xls.Excel.createExcel();
    final def = excel.getDefaultSheet();

    xls.CellValue cell(Object? v) => switch (v) {
      null => xls.TextCellValue(''),
      final int n => xls.IntCellValue(n),
      final double d => xls.DoubleCellValue(d),
      final bool b => xls.BoolCellValue(b),
      _ => xls.TextCellValue('$v'),
    };
    void sheet(String name, List<String> columns, List<List<Object?>> rows) {
      final sh = excel[name];
      sh.appendRow([for (final c in columns) xls.TextCellValue(c)]);
      for (final r in rows) {
        sh.appendRow([for (final v in r) cell(v)]);
      }
    }

    sheet(
      'META',
      const ['key', 'value'],
      [
        ['version', kBackupVersion],
        ['updatedAt', DateTime.now().toIso8601String()],
        if (budgetsUnit != null) ['budgetsUnit', budgetsUnit],
      ],
    );
    for (final t in kBackupTables) {
      final rows = tables[t.key];
      if (rows == null) continue;
      final cols = t.columns.keys.toList();
      sheet(t.sheet, cols, [
        for (final r in rows)
          [
            for (final c in cols)
              t.columns[c] == ColKind.int ? backupInt(r[c]) : r[c]?.toString(),
          ],
      ]);
    }
    if (budgets != null) {
      sheet(
        'BUDGETS',
        const ['categoryGid', 'budgetMinor'],
        [
          for (final e in budgets!.entries) [e.key, e.value],
        ],
      );
    }
    if (settings != null) {
      sheet(
        'SETTINGS',
        const ['key', 'value'],
        [
          for (final e in settings!.entries) [e.key, e.value?.toString()],
        ],
      );
    }
    if (prefs != null) {
      sheet(
        'PREFS',
        const ['key', 'value', 'type'],
        [
          for (final e in prefs!.entries)
            [
              e.key,
              e.value is List ? jsonEncode(e.value) : e.value?.toString(),
              prefTypes[e.key] ?? _typeOf(e.value),
            ],
        ],
      );
    }
    if (bank != null) {
      void items(String name, Object? list) {
        final rows = [
          for (final r in (list is List ? list : const []))
            if (r is Map) r,
        ];
        final cols = <String>{
          for (final r in rows)
            for (final k in r.keys) '$k',
        }.toList();
        sheet(name, cols, [
          for (final r in rows) [for (final c in cols) r[c]],
        ]);
      }

      items('BANK_FORMATS', bank!['formats']);
      items('BANK_MESSAGES', bank!['messages']);
      sheet(
        'BANK_IGNORED_SENDERS',
        const ['sender'],
        [
          for (final s in (bank!['ignoredSenders'] as List? ?? const [])) [s],
        ],
      );
    }
    if (def != null && excel.tables[def]?.maxRows == 0) excel.delete(def);
    return Uint8List.fromList(excel.save()!);
  }

  /// From an Excel backup (this format or the older ones: sheets are read
  /// by their column names).
  static BackupData fromXlsx(List<int> bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    var unreadable = 0;

    Object? value(xls.Data? c) => switch (c?.value) {
      null => null,
      xls.TextCellValue(:final value) =>
        value.toString().isEmpty ? null : value.toString(),
      xls.IntCellValue(:final value) => value,
      xls.DoubleCellValue(:final value) =>
        value == value.roundToDouble() && value.abs() < 9e15
            ? value.toInt()
            : value,
      xls.BoolCellValue(:final value) => value,
      final xls.DateCellValue d => d.asDateTimeLocal().toIso8601String(),
      final xls.DateTimeCellValue d => d.asDateTimeLocal().toIso8601String(),
      final v => v.toString(),
    };
    List<Map<String, Object?>>? read(String name) {
      final sh = excel.tables[name];
      if (sh == null) return null;
      final rows = sh.rows;
      if (rows.isEmpty) return [];
      final head = [for (final c in rows.first) value(c)?.toString() ?? ''];
      return [
        for (final r in rows.skip(1))
          if (r.any((c) => value(c) != null))
            {
              for (var i = 0; i < head.length; i++)
                if (head[i].isNotEmpty)
                  head[i]: i < r.length ? value(r[i]) : null,
            },
      ];
    }

    final tables = <String, List<Map<String, Object?>>>{
      for (final t in kBackupTables) t.key: ?read(t.sheet),
    };
    if (tables.isEmpty) throw const FormatException('no data in it');
    final meta = {
      for (final r in read('META') ?? const <Map<String, Object?>>[])
        '${r['key']}': r['value'],
    };
    final prefsRows = read('PREFS');
    final prefs = prefsRows == null
        ? null
        : {
            for (final r in prefsRows)
              if (r['key'] != null) '${r['key']}': r['value']?.toString(),
          };
    final budgetRows = read('BUDGETS');
    Map<String, Object?>? bank;
    final formats = read('BANK_FORMATS');
    final messages = read('BANK_MESSAGES');
    final senders = read('BANK_IGNORED_SENDERS');
    if (formats != null || messages != null || senders != null) {
      bank = {
        'formats': formats ?? const [],
        'messages': messages ?? const [],
        'ignoredSenders': [
          for (final r in senders ?? const <Map<String, Object?>>[])
            if (r['sender'] != null) '${r['sender']}',
        ],
      };
    } else if (read('BANK_DATA') case final parts?) {
      // A cell Excel cut short (at 32,767 characters) loses that part
      // only; it's counted with the rows left out.
      // Older Excel backups: each part as one JSON cell.
      bank = {};
      for (final r in parts) {
        try {
          bank['${r['part']}'] = jsonDecode('${r['json']}');
        } catch (_) {
          unreadable++;
        }
      }
    }
    return BackupData(
      unreadable: unreadable,
      version: backupInt(meta['version']),
      tables: tables,
      budgets: budgetRows == null
          ? null
          : {
              for (final r in budgetRows)
                if (backupString(r['categoryGid']) != null)
                  '${r['categoryGid']}': backupInt(r['budgetMinor']) ?? 0,
            },
      budgetsUnit:
          backupString(meta['budgetsUnit']) ??
          backupString(prefs?[kBudgetsUnitPrefsKey]),
      settings: {
        for (final r in read('SETTINGS') ?? const <Map<String, Object?>>[])
          if (r['key'] != null) '${r['key']}': r['value']?.toString(),
      },
      prefs: prefs,
      prefTypes: {
        for (final r in prefsRows ?? const <Map<String, Object?>>[])
          if (r['key'] != null && r['type'] != null)
            '${r['key']}': '${r['type']}',
      },
      bank: bank,
    );
  }

  // ---------------- CSV (the oldest backups; read only) ----------------

  static BackupData fromCsv(String text) {
    if (text.startsWith('﻿')) text = text.substring(1);
    final lines = const LineSplitter().convert(text);
    String? sep;
    for (final l in lines) {
      if (l.trimRight().startsWith('sep=')) {
        final s = l.trimRight().substring(4);
        sep = s == r'\t' ? '\t' : (s.isNotEmpty ? s[0] : ',');
        break;
      }
    }
    List<String> split(String l) {
      final d = sep ?? ((l.contains('\t') && !l.contains(',')) ? '\t' : ',');
      final out = <String>[];
      final buf = StringBuffer();
      var quoted = false;
      for (var i = 0; i < l.length; i++) {
        final ch = l[i];
        if (ch == '"') {
          if (quoted && i + 1 < l.length && l[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            quoted = !quoted;
          }
        } else if (ch == d && !quoted) {
          out.add(buf.toString());
          buf.clear();
        } else {
          buf.write(ch);
        }
      }
      out.add(buf.toString());
      return out;
    }

    var section = '';
    var header = false;
    final expenses = <Map<String, Object?>>[];
    final categories = <Map<String, Object?>>[];
    final settings = <String, Object?>{};
    final budgets = <String, int>{};
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty || line.startsWith('sep=')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line;
        header = true;
        continue;
      }
      if (header) {
        header = false;
        continue;
      }
      final p = split(line);
      switch (section) {
        case '[EXPENSES]' when p.length >= 7:
          expenses.add({
            'gid': p[0],
            'title': p[1],
            'amountMinor': p[2],
            'currency': p[3],
            'occurredAtUtc': p[4],
            'categoryGid': p[5],
            'note': p[6],
          });
        case '[CATEGORIES]' when p.length >= 4:
          categories.add({
            'gid': p[0],
            'name': p[1],
            'color': p[2],
            'sort': p[3],
          });
        case '[SETTINGS]' when p.length >= 2:
          settings[p[0]] = p[1];
        case '[BUDGETS]' when p.length >= 2:
          budgets[p[0]] = int.tryParse(p[1]) ?? 0;
      }
    }
    if (expenses.isEmpty && categories.isEmpty) {
      throw const FormatException('no data in it');
    }
    return BackupData(
      tables: {'expenses': expenses, 'categories': categories},
      budgets: budgets.isEmpty ? null : budgets,
      settings: settings.isEmpty ? null : settings,
    );
  }

  // ---------------- Restoring ----------------

  /// Writes this backup into the app: [merge] false replaces each part the
  /// backup has (parts it lacks stay); true merges (the newer copy of an
  /// item wins, same-named categories join, lists combine, the app's own
  /// settings stay). [currentBank] / [importBank]: the bank data's read and
  /// write (tests pass none).
  Future<RestoreReport> restore({
    required bool merge,
    Future<Map<String, Object?>> Function()? currentBank,
    Future<void> Function(Map<String, Object?> data)? importBank,
  }) async {
    final db = AppDb.instance.db;
    await _ensureCategoryColumns();
    final now = DateTime.now().toUtc();
    // Before format 3 amounts were whole units (the DB's v3 migration made
    // them minor units the same way).
    final scale = version != null && version! < 3;
    var skipped = unreadable;
    var restored = 0;

    // 1. Read every part first: nothing is written if this throws.
    final parts = <BackupTable, List<Map<String, Object?>>>{};
    for (final t in kBackupTables) {
      final rows = tables[t.key];
      if (rows == null) continue;
      var sort = 0;
      final byKey = <Object?, Map<String, Object?>>{};
      for (final r in rows) {
        final n = _normalize(t, r, () => sort += 100, currency: _currency);
        if (n == null) {
          skipped++;
          continue;
        }
        // Read from an old whole-unit `amount`: scaled already.
        final whole = n.remove(_wholeUnits) != null;
        if (scale && !whole && t.table == 'expenses') {
          final a = n['amountMinor'] as int;
          if (a < 1000000000) n['amountMinor'] = a * 100;
        }
        byKey[n[t.keyColumn]] = n; // a repeated item: the last copy
      }
      parts[t] = byKey.values.toList();
    }

    // 2. Every table in one transaction: all of it, or none of it.
    final remaps = <String, Map<String, String>>{};
    await db.transaction((txn) async {
      final iso = now.toIso8601String();
      for (final t in kBackupTables) {
        var rows = parts[t];
        if (rows == null) continue;
        if (t.isCategories) {
          final (remap, written) = await _writeCategories(
            txn,
            t,
            rows,
            merge: merge,
            nowIso: iso,
          );
          remaps[t.table] = remap;
          restored += written;
          continue;
        }
        final remap = t.categoryTable == null ? null : remaps[t.categoryTable];
        if (remap != null && remap.isNotEmpty) {
          for (final r in rows) {
            final to = remap[r['categoryGid']];
            if (to != null) r['categoryGid'] = to;
          }
        }
        if (t.table == 'debt_payments') {
          // Only payments of a debt the app will have.
          final debts = {
            for (final d in parts.entries)
              if (d.key.table == 'debts')
                for (final r in d.value) r['gid'],
            if (merge)
              for (final r in await txn.query(
                'debts',
                columns: ['gid'],
                where: 'isDeleted = 0',
              ))
                r['gid'],
          };
          final kept = [
            for (final r in rows)
              if (debts.contains(r['debtGid'])) r,
          ];
          skipped += rows.length - kept.length;
          rows = kept;
        }
        if (!merge) {
          if (t.softDeletes) {
            await txn.update(t.table, {
              'isDeleted': 1,
              'isDirty': 1,
              'updatedAtUtc': iso,
            }, where: 'isDeleted = 0');
          } else {
            await txn.delete(t.table);
          }
        }
        final batch = txn.batch();
        for (final r in rows) {
          if (merge) {
            final have = await txn.query(
              t.table,
              columns: [t.newerColumn],
              where: '${t.keyColumn} = ?',
              whereArgs: [r[t.keyColumn]],
            );
            // The app's copy is as new or newer: it stays.
            if (have.isNotEmpty &&
                !_newer(r[t.newerColumn], have.first[t.newerColumn])) {
              restored++;
              continue;
            }
          }
          batch.insert(
            t.table,
            r,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          restored++;
        }
        await batch.commit(noResult: true);
      }

      // Entries whose category the app doesn't have (an expenses-only
      // backup restored without its categories, an old file) go to the
      // fallback one, as a deleted category's do.
      for (final t in kBackupTables) {
        final cats = t.categoryTable;
        if (cats == null || parts[t] == null) continue;
        final live = [
          for (final c in await txn.query(
            cats,
            columns: ['gid'],
            where: 'isDeleted = 0',
            orderBy: 'sort',
          ))
            c['gid'] as String,
        ];
        if (live.isEmpty) continue;
        final general = cats == 'categories' ? 'cat_general' : 'inccat_general';
        final heir = live.contains(general) ? general : live.first;
        await txn.rawUpdate(
          'UPDATE ${t.table} SET categoryGid = ? '
          'WHERE categoryGid IS NOT NULL '
          'AND categoryGid NOT IN '
          '(SELECT gid FROM $cats WHERE isDeleted = 0)'
          '${t.softDeletes ? ' AND isDeleted = 0' : ''}',
          [heir],
        );
      }
    });

    // 3. Budgets, prefs, bank data (each after the tables it points into).
    final sp = await SharedPreferences.getInstance();
    if (prefs != null) {
      await _applyPrefs(sp, prefs!, prefTypes, merge: merge);
    } else if (settings != null && !merge) {
      await _applySettingsBlock(sp, settings!);
    }
    if (budgets != null) {
      await _applyBudgets(
        sp,
        remap: remaps['categories'] ?? const {},
        merge: merge,
        // Whole units: before format 3, or (an older backup) from a device
        // whose Budget page hadn't made them minor units yet (it would
        // have, on opening). Format 4 backups are always minor units.
        scale:
            scale ||
            ((version ?? 0) < 4 &&
                prefs != null &&
                backupBool(prefs![_budgetsMigratedKey]) != true),
      );
    }
    if (bank != null && importBank != null) {
      if (merge && currentBank != null) {
        await importBank(mergeBank(await currentBank(), bank!));
      } else {
        await importBank(bank!);
      }
    }
    return RestoreReport(restored: restored, skipped: skipped);
  }

  Future<void> _applyBudgets(
    SharedPreferences sp, {
    required Map<String, String> remap,
    required bool merge,
    required bool scale,
  }) async {
    final unitNow = sp.getString(kBudgetsUnitPrefsKey);
    // Older backups recorded no unit: their budgets were in the backup's
    // currency setting.
    final fromUnit =
        budgetsUnit ??
        backupString(prefs?[kBudgetsUnitPrefsKey]) ??
        backupString(prefs?['currency']) ??
        backupString(settings?['currencyCode']) ??
        unitNow ??
        sp.getString('currency') ??
        'IRT';
    final incoming = {
      for (final e in budgets!.entries)
        remap[e.key] ?? e.key: scale ? e.value * 100 : e.value,
    };
    if (!merge) {
      await sp.setString(kBudgetsPrefsKey, jsonEncode(incoming));
      await sp.setString(kBudgetsUnitPrefsKey, fromUnit);
    } else {
      // The app's budgets stay; the backup's fill in categories without
      // one, in the app's unit.
      final mine = _readBudgets(sp.getString(kBudgetsPrefsKey)) ?? {};
      final unit = unitNow ?? fromUnit;
      for (final e in incoming.entries) {
        mine.putIfAbsent(e.key, () => amountInUnit(e.value, fromUnit, unit));
      }
      await sp.setString(kBudgetsPrefsKey, jsonEncode(mine));
      await sp.setString(kBudgetsUnitPrefsKey, unit);
    }
    // Minor units already: the Budget page's one-time v3 step must not
    // multiply them again.
    await sp.setBool(_budgetsMigratedKey, true);
  }
}

// ---------------- Helpers ----------------

final _uuid = const Uuid();

/// A time older than anything the app wrote.
final _oldest = DateTime.utc(2000).toIso8601String();

/// Fills in a category row's icon and color where the backup had none:
/// those of the app's category with its gid ([mine]), else the default.
void _fillLook(Map<String, Object?> r, Map<String, Object?>? mine) {
  r['iconCodePoint'] ??= mine?['iconCodePoint'] ?? Icons.category.codePoint;
  r['iconFontFamily'] ??= r['iconCodePoint'] == mine?['iconCodePoint']
      ? (mine?['iconFontFamily'] ?? 'MaterialIcons')
      : 'MaterialIcons';
  r['color'] ??= mine?['color'] ?? const Color(0xFF607D8B).toARGB32();
}

Future<void> _ensureCategoryColumns() async {
  await CategoryRepository().ensureColumns();
  await CategoryRepository(table: 'income_categories').ensureColumns();
}

/// A pref value's type, as backups record it.
String _typeOf(Object? v) => v is bool
    ? 'bool'
    : v is int
    ? 'int'
    : v is double
    ? 'double'
    : v is List
    ? 'list'
    : 'string';

/// Budgets as stored (gid → minor units); null when they can't be read.
Map<String, int>? _readBudgets(String? text) {
  if (text == null || text.trim().isEmpty) return {};
  try {
    final m = jsonDecode(text) as Map<String, dynamic>;
    return {for (final e in m.entries) e.key: backupInt(e.value) ?? 0};
  } catch (_) {
    return null;
  }
}

/// Whether [a] is a later time than [b] (ISO text; unreadable: not newer).
bool _newer(Object? a, Object? b) {
  final x = backupDateUtc(a);
  final y = backupDateUtc(b);
  if (x == null) return false;
  if (y == null) return true;
  return x.isAfter(y);
}

/// Marks a row whose amount came from an old whole-unit `amount` (already
/// made minor units); taken off before it's written.
const _wholeUnits = '_wholeUnits';

/// [raw] as a row of [t] (its columns, read by their kind, defaults filled
/// in), or null if it lacks what it can't do without. [currency]: the
/// backup's currency setting, for rows that don't say theirs.
Map<String, Object?>? _normalize(
  BackupTable t,
  Map<String, Object?> raw,
  int Function() nextSort, {
  required String currency,
}) {
  final row = <String, Object?>{};
  for (final MapEntry(key: c, value: kind) in t.columns.entries) {
    final v = raw[c];
    row[c] = switch (kind) {
      // Older Excel backups wrote some numbers as text with a leading '.
      ColKind.int => backupInt(v is String ? v.replaceFirst("'", '') : v),
      ColKind.date => backupDateUtc(v)?.toIso8601String(),
      ColKind.text => backupString(v),
    };
  }
  if (t.table.endsWith('expenses') || t.table == 'incomes') {
    // The oldest backups: `amount`, in whole units.
    if (row['amountMinor'] == null && raw['amount'] != null) {
      final a = num.tryParse('${raw['amount']}'.replaceAll(',', ''));
      if (a != null) {
        row['amountMinor'] = (a * 100).round();
        row[_wholeUnits] = true;
      }
    }
    row['occurredAtUtc'] ??= backupDateUtc(
      raw['occurredAt'],
    )?.toIso8601String();
  }
  for (final c in t.required) {
    if (row[c] == null) return null;
  }
  if (t.columns.containsKey('gid')) row['gid'] ??= _uuid.v7();
  // Upcoming history without one means "as shown" (kept as null).
  if (t.columns.containsKey('currency') && t.table != 'upcoming_history') {
    row['currency'] ??= currency;
  }
  if (t.columns.containsKey('version')) row['version'] ??= 1;
  if (t.columns.containsKey('createdAtUtc')) {
    // Older Excel sheets had no times: the row's own date, else the
    // oldest there is, so merging never prefers it to the app's copy.
    row['createdAtUtc'] ??=
        row['occurredAtUtc'] ??
        row['dueAtUtc'] ??
        row['paidAtUtc'] ??
        row['startedAtUtc'] ??
        _oldest;
    row['updatedAtUtc'] ??= row['createdAtUtc'];
  }
  if (t.columns.containsKey('lastUsedAtUtc')) row['lastUsedAtUtc'] ??= _oldest;
  if (t.isCategories) {
    row['sort'] ??= nextSort();
    // A missing icon or color is filled in when written (the app's own
    // for a category it has: _writeCategories).
  }
  if (t.table == 'debts') {
    row['direction'] = row['direction'] == 'owed' ? 'owed' : 'owe';
  }
  if (t.softDeletes) {
    row['isDeleted'] = 0;
    row['isDirty'] = 1;
  }
  return row;
}

/// Writes a category table's rows. Replacing: the backup's categories are
/// the ones left (when it has any). Merging: a backup category with the
/// name of one of the app's joins it (its entries move to the app's; the
/// name is unique). Returns backup gid → app gid for those, and how many
/// rows were written or kept.
Future<(Map<String, String>, int)> _writeCategories(
  Transaction txn,
  BackupTable t,
  List<Map<String, Object?>> rows, {
  required bool merge,
  required String nowIso,
}) async {
  final remap = <String, String>{};
  final all = await txn.query(t.table);
  final byGid = {for (final c in all) c['gid'] as String: c};
  for (final r in rows) {
    _fillLook(r, byGid[r['gid']]);
  }
  if (!merge) {
    if (rows.isEmpty) return (remap, 0); // none in the backup: keep the app's
    await txn.update(t.table, {
      'isDeleted': 1,
      'isDirty': 1,
      'updatedAtUtc': nowIso,
    }, where: 'isDeleted = 0');
    final batch = txn.batch();
    for (final r in rows) {
      // A row of the app's with the same gid or name gives way.
      batch.insert(t.table, r, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return (remap, rows.length);
  }
  final byName = {for (final c in all) c['name'] as String: c};
  var written = 0;
  for (final r in rows) {
    final gid = r['gid'] as String;
    final name = r['name'] as String;
    final same = byGid[gid];
    if (same != null) {
      final clash = byName[name];
      final nameFree = clash == null || clash['gid'] == gid;
      if (nameFree && _newer(r['updatedAtUtc'], same['updatedAtUtc'])) {
        await txn.insert(
          t.table,
          r,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        byName[name] = r;
      }
      written++;
      continue;
    }
    final named = byName[name];
    if (named != null) {
      remap[gid] = named['gid'] as String;
      // Its entries are coming back to it: it's in use again.
      if (named['isDeleted'] == 1) {
        await txn.update(
          t.table,
          {'isDeleted': 0, 'isDirty': 1, 'updatedAtUtc': nowIso},
          where: 'gid = ?',
          whereArgs: [named['gid']],
        );
      }
      written++;
      continue;
    }
    await txn.insert(t.table, r, conflictAlgorithm: ConflictAlgorithm.replace);
    byGid[gid] = r;
    byName[name] = r;
    written++;
  }
  return (remap, written);
}

/// Writes prefs back with their own types. Merging: lists combine, any
/// other pref the app already has stays. The budgets are left to
/// [BackupData._applyBudgets].
Future<void> _applyPrefs(
  SharedPreferences sp,
  Map<String, Object?> prefs,
  Map<String, String> types, {
  required bool merge,
}) async {
  for (final e in prefs.entries) {
    final k = e.key;
    final v = e.value;
    if (v == null || _budgetPrefs.contains(k) || k == _budgetsMigratedKey) {
      continue;
    }
    try {
      final current = sp.get(k);
      var type = types[k] ?? (v is String ? null : _typeOf(v));
      if (type == null) {
        // Older backups: every value as text. The type of the value on the
        // device, else the one the text plainly is.
        final text = v as String;
        type = current != null
            ? _typeOf(current)
            : (backupBool(text) != null && !RegExp(r'^\d$').hasMatch(text))
            ? 'bool'
            : int.tryParse(text) != null
            ? 'int'
            : 'string';
      }
      if (merge && type != 'list' && current != null) continue;
      switch (type) {
        case 'bool':
          final b = backupBool(v);
          if (b != null) await sp.setBool(k, b);
        case 'int':
          final n = backupInt(v);
          if (n != null) await sp.setInt(k, n);
        case 'double':
          final d = v is num ? v.toDouble() : double.tryParse('$v');
          if (d != null) await sp.setDouble(k, d);
        case 'list':
          final list = [
            for (final x in (v is List ? v : jsonDecode('$v') as List)) '$x',
          ];
          if (merge && current is List) {
            final mine = [for (final x in current) '$x'];
            await sp.setStringList(k, [
              ...mine,
              for (final x in list)
                if (!mine.contains(x)) x,
            ]);
          } else {
            await sp.setStringList(k, list);
          }
        default:
          await sp.setString(k, '$v');
      }
    } catch (_) {
      // A pref that can't be read back is left as it is.
    }
  }
}

/// The old settings block (backups from before prefs were backed up).
Future<void> _applySettingsBlock(
  SharedPreferences sp,
  Map<String, Object?> s,
) async {
  final tm = backupString(s['themeMode']);
  if (tm == 'light' || tm == 'dark' || tm == 'system') {
    await sp.setString('themeMode', tm!);
  }
  final seed = backupInt(s['seedColor']);
  if (seed != null) await sp.setInt('seedColor', seed);
  final cc = backupString(s['currencyCode']);
  if (cc != null) await sp.setString('currency', cc == 'IRTK' ? 'IRT' : cc);
  final sd = backupInt(s['startDay']);
  if (sd != null && sd >= 1 && sd <= 28) await sp.setInt('startDay', sd);
  final bio = backupBool(s['biometricEnabled']);
  if (bio != null) await sp.setBool('biometric', bio);
  final lc = backupString(s['localeCode']);
  if (lc == 'fa' || lc == 'en') await sp.setString('locale', lc!);
  final cal = backupString(s['calendar']);
  if (cal == 'jalali' || cal == 'gregorian') {
    await sp.setString('calendar', cal!);
  }
}

/// The app's bank data with a backup's merged in: formats by their layout
/// (the app's stay), messages by their key (the newest 500, as the log
/// keeps), ignored senders combined.
Map<String, Object?> mergeBank(
  Map<String, Object?> mine,
  Map<String, Object?> theirs,
) {
  List<Map> maps(Object? v) => [
    for (final x in (v is List ? v : const []))
      if (x is Map) x,
  ];
  List<Map> union(Object? a, Object? b, String key) {
    final seen = <Object?>{};
    return [
      for (final x in [...maps(a), ...maps(b)])
        if (seen.add(x[key])) x,
    ];
  }

  final messages = union(mine['messages'], theirs['messages'], 'key')
    ..sort(
      (a, b) => (backupInt(b['postedAt']) ?? 0).compareTo(
        backupInt(a['postedAt']) ?? 0,
      ),
    );
  return {
    'formats': union(mine['formats'], theirs['formats'], 'skeleton'),
    'messages': messages.take(500).toList(),
    'ignoredSenders': {
      for (final x in [
        ...(mine['ignoredSenders'] as List? ?? const []),
        ...(theirs['ignoredSenders'] as List? ?? const []),
      ])
        '$x',
    }.toList(),
  };
}

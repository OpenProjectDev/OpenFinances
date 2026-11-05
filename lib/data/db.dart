import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final instance = AppDb._();

  Database? _db;

  /// The database file. It was named after the app's old name (jibyar.db):
  /// an existing one is renamed once, so nothing recorded is left behind.
  static Future<String> _filePath() async {
    final dir = (await getApplicationDocumentsDirectory()).path;
    final file = File(p.join(dir, 'openfinances.db'));
    final old = File(p.join(dir, 'jibyar.db'));
    if (!file.existsSync() && old.existsSync()) {
      old.renameSync(file.path);
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final f = File('${old.path}$suffix');
        if (f.existsSync()) f.renameSync('${file.path}$suffix');
      }
    }
    return file.path;
  }

  /// [path] overrides the on-device file (tests pass an in-memory path).
  Future<void> open({String? path}) async {
    if (_db != null) return;

    final dbPath = path ?? await _filePath();

    _db = await openDatabase(
      dbPath,
      version: 6, // 👈 v6: debts
      onCreate: (db, _) async {
        // v1 schema
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            gid TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            amountMinor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            occurredAtUtc TEXT NOT NULL, -- ISO8601 (UTC)
            note TEXT,
            categoryGid TEXT,
            accountGid TEXT,
            ruleGid TEXT, -- 👈 added in v2
            version INTEGER NOT NULL,
            createdAtUtc TEXT NOT NULL,
            updatedAtUtc TEXT NOT NULL,
            isDeleted INTEGER NOT NULL,
            isDirty INTEGER NOT NULL
          );
        ''');

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_expenses_occurredAtUtc ON expenses(occurredAtUtc);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_expenses_categoryGid ON expenses(categoryGid);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_expenses_ruleGid ON expenses(ruleGid);',
        );

        // categories schema + seed
        await _ensureCategoryTableSchema(
          db,
          table: 'categories',
          seedGid: 'cat_general',
        );

        // income + income categories (v4)
        await _ensureIncomeSchema(db);
        await _ensureCategoryTableSchema(
          db,
          table: 'income_categories',
          seedGid: 'inccat_general',
        );

        // upcoming payments (v5)
        await _ensureUpcomingSchema(db);

        // debts (v6)
        await _ensureDebtSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 👇 migration to v2
          try {
            await db.execute('ALTER TABLE expenses ADD COLUMN ruleGid TEXT;');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_expenses_ruleGid ON expenses(ruleGid);',
            );
          } catch (_) {
            // ignore if already exists
          }
        }

        if (oldVersion < 3) {
          // 👇 migration to v3: Convert amounts to minor units (multiply by 100)
          // This handles the change from storing whole numbers to storing cents
          try {
            await db.execute(
              'UPDATE expenses SET amountMinor = amountMinor * 100 WHERE amountMinor < 1000000000;',
            );
          } catch (e) {
            debugPrint('[DB Migration v3] Error converting amounts: $e');
          }
        }

        if (oldVersion < 4) {
          // 👇 migration to v4: income tracking, kept as a separate system
          // from expenses (no balance/subtraction — just its own table).
          await _ensureIncomeSchema(db);
          await _ensureCategoryTableSchema(
            db,
            table: 'income_categories',
            seedGid: 'inccat_general',
          );
        }

        if (oldVersion < 5) {
          // 👇 migration to v5: upcoming (planned) payments + title history
          await _ensureUpcomingSchema(db);
        }

        if (oldVersion < 6) {
          // 👇 migration to v6: debts + their payments
          await _ensureDebtSchema(db);
        }
      },
    );

    // Ensure categories schema exists for older DBs too
    await _ensureCategoryTableSchema(
      db,
      table: 'categories',
      seedGid: 'cat_general',
    );
    await _ensureIncomeSchema(db);
    await _ensureCategoryTableSchema(
      db,
      table: 'income_categories',
      seedGid: 'inccat_general',
    );
    await _ensureUpcomingSchema(db);
    await _ensureDebtSchema(db);
  }

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('DB not opened — call AppDb.instance.open() first.');
    }
    return d;
  }

  // ---------- Category-shaped tables (expense + income categories share
  // this exact schema; `table` picks which one) ----------
  Future<void> _ensureCategoryTableSchema(
    Database db, {
    required String table,
    required String seedGid,
  }) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        gid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        createdAtUtc TEXT NOT NULL,
        updatedAtUtc TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isDirty INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_name ON $table(name);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_sort ON $table(sort);',
    );

    if (table == 'categories') {
      // In case older DBs missed this column. Check first: a failed ALTER is
      // caught, but SQLite still logs it as an error on every launch.
      final cols = await db.rawQuery('PRAGMA table_info(expenses)');
      if (!cols.any((c) => c['name'] == 'categoryGid')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN categoryGid TEXT;');
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_categoryGid ON expenses(categoryGid);',
      );
    }

    // At least one category always exists (entries without one fall back to
    // it). Older versions could delete them all: then General comes back
    // (undeleted, or created if it's gone).
    final cntRaw = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE isDeleted = 0',
    );
    if ((Sqflite.firstIntValue(cntRaw) ?? 0) > 0) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(table, {
      'gid': seedGid,
      'name': 'عمومی',
      'sort': 90,
      'createdAtUtc': now,
      'updatedAtUtc': now,
      'isDeleted': 0,
      'isDirty': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update(
      table,
      {'isDeleted': 0, 'isDirty': 1, 'updatedAtUtc': now},
      where: 'gid = ? AND isDeleted = 1',
      whereArgs: [seedGid],
    );
  }

  // ---------- Income schema (kept fully separate from expenses — no
  // balance/subtraction, just its own table for later statistical use) ----------
  Future<void> _ensureIncomeSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        amountMinor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        occurredAtUtc TEXT NOT NULL, -- ISO8601 (UTC)
        note TEXT,
        categoryGid TEXT,
        accountGid TEXT,
        version INTEGER NOT NULL,
        createdAtUtc TEXT NOT NULL,
        updatedAtUtc TEXT NOT NULL,
        isDeleted INTEGER NOT NULL,
        isDirty INTEGER NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_incomes_occurredAtUtc ON incomes(occurredAtUtc);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_incomes_categoryGid ON incomes(categoryGid);',
    );
  }

  // ---------- Upcoming payments (v5) — planned spending that hasn't
  // happened yet. Not an expense until marked paid. ----------
  Future<void> _ensureUpcomingSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS upcoming_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        amountMinor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        dueAtUtc TEXT NOT NULL, -- ISO8601 (UTC)
        note TEXT,
        categoryGid TEXT,
        version INTEGER NOT NULL,
        createdAtUtc TEXT NOT NULL,
        updatedAtUtc TEXT NOT NULL,
        isDeleted INTEGER NOT NULL,
        isDirty INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_upcoming_dueAtUtc ON upcoming_payments(dueAtUtc);',
    );

    // Title history for add-time suggestions (one row per title).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS upcoming_history (
        title TEXT PRIMARY KEY,
        amountMinor INTEGER NOT NULL,
        categoryGid TEXT,
        lastUsedAtUtc TEXT NOT NULL
      );
    ''');
    // Unit the remembered amount was recorded in (added later; checked
    // first so an existing column isn't re-added on every launch).
    final cols = await db.rawQuery('PRAGMA table_info(upcoming_history)');
    if (!cols.any((c) => c['name'] == 'currency')) {
      await db.execute(
        'ALTER TABLE upcoming_history ADD COLUMN currency TEXT;',
      );
    }
    // Paid items stay (faded, undoable) instead of going: when, the expense
    // it added and the next one "Pay & reschedule" scheduled (added later,
    // like the currency).
    final itemCols = await db.rawQuery('PRAGMA table_info(upcoming_payments)');
    for (final c in const ['paidAtUtc', 'ledgerGid', 'nextGid']) {
      if (!itemCols.any((r) => r['name'] == c)) {
        await db.execute('ALTER TABLE upcoming_payments ADD COLUMN $c TEXT;');
      }
    }
  }

  /// Whether row [gid] of [table] is there and not deleted (e.g. the
  /// History entry a payment added, still in History).
  Future<bool> isLive(String table, String gid) async {
    final rows = await db.query(
      table,
      columns: ['gid'],
      where: 'gid = ? AND isDeleted = 0',
      whereArgs: [gid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---------- Debts (v6): money lent or borrowed, paid off in parts. A
  // payment is its own row; it only reaches the ledger if the user asks. ----------
  Future<void> _ensureDebtSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gid TEXT NOT NULL UNIQUE,
        direction TEXT NOT NULL, -- 'owe' (I owe them) | 'owed' (they owe me)
        person TEXT NOT NULL,
        amountMinor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        startedAtUtc TEXT NOT NULL, -- ISO8601 (UTC)
        dueAtUtc TEXT, -- optional "pay by" date
        note TEXT,
        version INTEGER NOT NULL,
        createdAtUtc TEXT NOT NULL,
        updatedAtUtc TEXT NOT NULL,
        isDeleted INTEGER NOT NULL,
        isDirty INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gid TEXT NOT NULL UNIQUE,
        debtGid TEXT NOT NULL,
        amountMinor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        paidAtUtc TEXT NOT NULL, -- ISO8601 (UTC)
        version INTEGER NOT NULL,
        createdAtUtc TEXT NOT NULL,
        updatedAtUtc TEXT NOT NULL,
        isDeleted INTEGER NOT NULL,
        isDirty INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_debt_payments_debtGid ON debt_payments(debtGid);',
    );
    // What it was for (added later; checked first so an existing column
    // isn't re-added on every launch).
    final cols = await db.rawQuery('PRAGMA table_info(debts)');
    if (!cols.any((c) => c['name'] == 'title')) {
      await db.execute('ALTER TABLE debts ADD COLUMN title TEXT;');
    }
    // The History entry (expense or income gid) a payment added, so taking
    // the payment back takes it too (added later, like the title).
    final paymentCols = await db.rawQuery('PRAGMA table_info(debt_payments)');
    if (!paymentCols.any((c) => c['name'] == 'ledgerGid')) {
      await db.execute('ALTER TABLE debt_payments ADD COLUMN ledgerGid TEXT;');
    }
  }
}

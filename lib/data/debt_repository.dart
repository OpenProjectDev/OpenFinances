import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';

import 'currency_units.dart';
import 'db.dart';

/// Which way the money goes.
enum DebtDirection {
  /// I owe them (paying it back is an expense).
  owe,

  /// They owe me (getting it back is an income).
  owed,
}

DebtDirection debtDirectionOf(String? s) =>
    s == 'owed' ? DebtDirection.owed : DebtDirection.owe;

/// Money lent or borrowed. It's paid off in parts ([DebtPaymentDto]); it
/// never touches the ledger by itself.
class DebtDto {
  final String gid;
  final DebtDirection direction;
  final String person;

  /// What it was for (optional).
  final String? title;
  final int amountMinor;
  final String currency;
  final DateTime startedAtUtc;
  final DateTime? dueAtUtc;
  final String? note;
  final int version;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final bool isDeleted;
  final bool isDirty;

  DebtDto({
    required this.gid,
    required this.direction,
    required this.person,
    this.title,
    required this.amountMinor,
    this.currency = 'IRR',
    required this.startedAtUtc,
    this.dueAtUtc,
    this.note,
    this.version = 1,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.isDeleted = false,
    this.isDirty = true,
  });

  Map<String, Object?> toMap() => {
    'gid': gid,
    'direction': direction.name,
    'person': person,
    'title': title,
    'amountMinor': amountMinor,
    'currency': currency,
    'startedAtUtc': startedAtUtc.toIso8601String(),
    'dueAtUtc': dueAtUtc?.toIso8601String(),
    'note': note,
    'version': version,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'isDirty': isDirty ? 1 : 0,
  };

  static DebtDto fromMap(Map<String, Object?> m) => DebtDto(
    gid: (m['gid'] ?? '') as String,
    direction: debtDirectionOf(m['direction'] as String?),
    person: (m['person'] ?? '') as String,
    title: m['title'] as String?,
    amountMinor: (m['amountMinor'] as int?) ?? 0,
    currency: (m['currency'] as String?) ?? 'IRR',
    startedAtUtc: DateTime.parse((m['startedAtUtc'] ?? '') as String).toUtc(),
    dueAtUtc: DateTime.tryParse((m['dueAtUtc'] ?? '') as String)?.toUtc(),
    note: m['note'] as String?,
    version: (m['version'] as int?) ?? 1,
    createdAtUtc: DateTime.parse((m['createdAtUtc'] ?? '') as String).toUtc(),
    updatedAtUtc: DateTime.parse((m['updatedAtUtc'] ?? '') as String).toUtc(),
    isDeleted: ((m['isDeleted'] as int?) ?? 0) == 1,
    isDirty: ((m['isDirty'] as int?) ?? 0) == 1,
  );

  /// This debt as shown in [unit] (toman/rial converted; display only).
  DebtDto inUnit(String unit) {
    final shown = amountInUnit(amountMinor, currency, unit);
    if (shown == amountMinor) return this;
    return DebtDto(
      gid: gid,
      direction: direction,
      person: person,
      title: title,
      amountMinor: shown,
      currency: unit,
      startedAtUtc: startedAtUtc,
      dueAtUtc: dueAtUtc,
      note: note,
      version: version,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      isDeleted: isDeleted,
      isDirty: isDirty,
    );
  }
}

/// One part paid back on a debt.
class DebtPaymentDto {
  final String gid;
  final String debtGid;
  final int amountMinor;
  final String currency;
  final DateTime paidAtUtc;

  /// The History entry it added (an expense when I paid, an income when I
  /// got paid); null: none (or recorded before this was kept).
  final String? ledgerGid;
  final int version;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final bool isDeleted;
  final bool isDirty;

  DebtPaymentDto({
    required this.gid,
    required this.debtGid,
    required this.amountMinor,
    this.currency = 'IRR',
    required this.paidAtUtc,
    this.ledgerGid,
    this.version = 1,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.isDeleted = false,
    this.isDirty = true,
  });

  Map<String, Object?> toMap() => {
    'gid': gid,
    'debtGid': debtGid,
    'amountMinor': amountMinor,
    'currency': currency,
    'paidAtUtc': paidAtUtc.toIso8601String(),
    'ledgerGid': ledgerGid,
    'version': version,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'isDirty': isDirty ? 1 : 0,
  };

  static DebtPaymentDto fromMap(Map<String, Object?> m) => DebtPaymentDto(
    gid: (m['gid'] ?? '') as String,
    debtGid: (m['debtGid'] ?? '') as String,
    amountMinor: (m['amountMinor'] as int?) ?? 0,
    currency: (m['currency'] as String?) ?? 'IRR',
    paidAtUtc: DateTime.parse((m['paidAtUtc'] ?? '') as String).toUtc(),
    ledgerGid: m['ledgerGid'] as String?,
    version: (m['version'] as int?) ?? 1,
    createdAtUtc: DateTime.parse((m['createdAtUtc'] ?? '') as String).toUtc(),
    updatedAtUtc: DateTime.parse((m['updatedAtUtc'] ?? '') as String).toUtc(),
    isDeleted: ((m['isDeleted'] as int?) ?? 0) == 1,
    isDirty: ((m['isDirty'] as int?) ?? 0) == 1,
  );

  /// This payment as shown in [unit] (display only).
  DebtPaymentDto inUnit(String unit) {
    final shown = amountInUnit(amountMinor, currency, unit);
    if (shown == amountMinor) return this;
    return DebtPaymentDto(
      gid: gid,
      debtGid: debtGid,
      amountMinor: shown,
      currency: unit,
      paidAtUtc: paidAtUtc,
      ledgerGid: ledgerGid,
      version: version,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      isDeleted: isDeleted,
      isDirty: isDirty,
    );
  }
}

class DebtRepository {
  final _uuid = const Uuid();

  static const _debts = 'debts';
  static const _payments = 'debt_payments';

  /// A fresh gid for rows that arrive without one (e.g. old backups).
  String newGid() => _uuid.v7();

  Future<void> create({
    required DebtDirection direction,
    required String person,
    String? title,
    required int amountMinor,
    required DateTime startedLocal,
    DateTime? dueLocal,
    String? note,
    String currency = 'IRR',
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final row = DebtDto(
      gid: newGid(),
      direction: direction,
      person: person,
      title: title,
      amountMinor: amountMinor,
      currency: currency,
      startedAtUtc: startedLocal.toUtc(),
      dueAtUtc: dueLocal?.toUtc(),
      note: note,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );
    await AppDb.instance.db.insert(
      _debts,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> addPayment({
    required String debtGid,
    required int amountMinor,
    required DateTime paidLocal,
    String currency = 'IRR',
    String? ledgerGid,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final row = DebtPaymentDto(
      gid: newGid(),
      debtGid: debtGid,
      amountMinor: amountMinor,
      currency: currency,
      paidAtUtc: paidLocal.toUtc(),
      ledgerGid: ledgerGid,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );
    await AppDb.instance.db.insert(
      _payments,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<DebtDto>> list() async {
    final rows = await AppDb.instance.db.query(
      _debts,
      where: 'isDeleted = 0',
      orderBy: 'startedAtUtc DESC',
    );
    return rows.map(DebtDto.fromMap).toList();
  }

  /// Oldest first.
  Future<List<DebtPaymentDto>> listPayments() async {
    final rows = await AppDb.instance.db.query(
      _payments,
      where: 'isDeleted = 0',
      orderBy: 'paidAtUtc ASC',
    );
    return rows.map(DebtPaymentDto.fromMap).toList();
  }

  Future<int> update(String gid, Map<String, Object?> updates) async {
    if (updates.isEmpty) return 0;
    final db = AppDb.instance.db;
    final current = await db.query(
      _debts,
      columns: ['version'],
      where: 'gid = ?',
      whereArgs: [gid],
      limit: 1,
    );
    final version = current.isEmpty ? 1 : (current.first['version'] as int);
    return db.update(
      _debts,
      {
        ...updates,
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'isDirty': 1,
        'version': version + 1,
      },
      where: 'gid = ?',
      whereArgs: [gid],
    );
  }

  /// Soft-deletes the debt and all its payments.
  Future<void> softDelete(String gid) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final gone = {'isDeleted': 1, 'isDirty': 1, 'updatedAtUtc': now};
    await AppDb.instance.db.transaction((txn) async {
      await txn.update(_debts, gone, where: 'gid = ?', whereArgs: [gid]);
      await txn.update(
        _payments,
        gone,
        where: 'debtGid = ? AND isDeleted = 0',
        whereArgs: [gid],
      );
    });
  }

  /// Changes a payment ([updates]: its columns).
  Future<void> updatePayment(String gid, Map<String, Object?> updates) async {
    final db = AppDb.instance.db;
    final current = await db.query(
      _payments,
      columns: ['version'],
      where: 'gid = ?',
      whereArgs: [gid],
      limit: 1,
    );
    final version = current.isEmpty ? 1 : (current.first['version'] as int);
    await db.update(
      _payments,
      {
        ...updates,
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'isDirty': 1,
        'version': version + 1,
      },
      where: 'gid = ?',
      whereArgs: [gid],
    );
  }

  /// The live History entry in [table] titled [title], of [amountMinor],
  /// on [paidAtUtc]'s day: a payment's, from before payments kept theirs.
  Future<String?> findLedgerEntry({
    required String table,
    required String title,
    required int amountMinor,
    required DateTime paidAtUtc,
  }) async {
    final day = paidAtUtc.toLocal();
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    final rows = await AppDb.instance.db.query(
      table,
      columns: ['gid'],
      where:
          'isDeleted = 0 AND title = ? AND amountMinor = ? '
          'AND occurredAtUtc >= ? AND occurredAtUtc < ?',
      whereArgs: [
        title,
        amountMinor,
        from.toUtc().toIso8601String(),
        to.toUtc().toIso8601String(),
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['gid'] as String?;
  }

  /// Whether History entry [gid] in [table] is still there.
  Future<bool> isLiveEntry(String table, String gid) =>
      AppDb.instance.isLive(table, gid);

  Future<void> softDeletePayment(String gid) async {
    await AppDb.instance.db.update(
      _payments,
      {
        'isDeleted': 1,
        'isDirty': 1,
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'gid = ?',
      whereArgs: [gid],
    );
  }

  /// A payment back from [softDeletePayment] (an undo).
  Future<void> restorePayment(String gid) => _undelete(_payments, gid);

  /// A History entry (in [table]) back from its soft delete (an undo).
  Future<void> restoreEntry(String table, String gid) => _undelete(table, gid);

  Future<void> _undelete(String table, String gid) async {
    await AppDb.instance.db.update(
      table,
      {
        'isDeleted': 0,
        'isDirty': 1,
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'gid = ?',
      whereArgs: [gid],
    );
  }

  /// Restore: soft-deletes every current debt and payment, then writes the
  /// backup's rows with their own gids and timestamps, in one transaction
  /// (rows already in the DB are replaced in place).
  Future<void> replaceAll(
    List<DebtDto> debts,
    List<DebtPaymentDto> payments,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final gone = {'isDeleted': 1, 'isDirty': 1, 'updatedAtUtc': now};
    await AppDb.instance.db.transaction((txn) async {
      await txn.update(_debts, gone, where: 'isDeleted = 0');
      await txn.update(_payments, gone, where: 'isDeleted = 0');
      final batch = txn.batch();
      for (final d in debts) {
        batch.insert(
          _debts,
          d.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final p in payments) {
        batch.insert(
          _payments,
          p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';

import 'db.dart';

/// Income is tracked as its own system, deliberately not netted against
/// expenses anywhere in the data layer — no running balance is computed.
/// Correlating the two is left to a dedicated statistics view later.
class IncomeDto {
  final String gid;
  final String title;
  final int amountMinor;
  final String currency;
  final DateTime occurredAtUtc;
  final String? note;
  final String? categoryGid;
  final String? accountGid;
  final int version;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final bool isDeleted;
  final bool isDirty;

  IncomeDto({
    required this.gid,
    required this.title,
    required this.amountMinor,
    this.currency = 'IRR',
    required this.occurredAtUtc,
    this.note,
    this.categoryGid,
    this.accountGid,
    this.version = 1,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.isDeleted = false,
    this.isDirty = true,
  });

  Map<String, Object?> toMap() => {
    'gid': gid,
    'title': title,
    'amountMinor': amountMinor,
    'currency': currency,
    'occurredAtUtc': occurredAtUtc.toIso8601String(),
    'note': note,
    'categoryGid': categoryGid,
    'accountGid': accountGid,
    'version': version,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'isDirty': isDirty ? 1 : 0,
  };

  static IncomeDto fromMap(Map<String, Object?> m) => IncomeDto(
    gid: (m['gid'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    amountMinor: (m['amountMinor'] as int?) ?? 0,
    currency: (m['currency'] as String?) ?? 'IRR',
    occurredAtUtc: DateTime.parse((m['occurredAtUtc'] ?? '') as String).toUtc(),
    note: m['note'] as String?,
    categoryGid: m['categoryGid'] as String?,
    accountGid: m['accountGid'] as String?,
    version: (m['version'] as int?) ?? 1,
    createdAtUtc: DateTime.parse((m['createdAtUtc'] ?? '') as String).toUtc(),
    updatedAtUtc: DateTime.parse((m['updatedAtUtc'] ?? '') as String).toUtc(),
    isDeleted: ((m['isDeleted'] as int?) ?? 0) == 1,
    isDirty: ((m['isDirty'] as int?) ?? 0) == 1,
  );
}

class IncomeRepository {
  final _uuid = const Uuid();

  /// Saves a new income entry; its gid.
  Future<String> create({
    required String title,
    required int amountMinor,
    required DateTime occurredLocal,
    String? note,
    String? categoryGid,
    String? accountGid,
    String currency = 'IRR',
  }) async {
    final db = AppDb.instance.db;
    final nowUtc = DateTime.now().toUtc();

    final row = IncomeDto(
      gid: _uuid.v7(),
      title: title,
      amountMinor: amountMinor,
      currency: currency,
      occurredAtUtc: occurredLocal.toUtc(),
      note: note,
      categoryGid: categoryGid,
      accountGid: accountGid,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    await db.insert(
      'incomes',
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return row.gid;
  }

  /// A fresh gid for rows that arrive without one (e.g. old backups).
  String newGid() => _uuid.v7();

  /// Restore: soft-deletes every current row, then writes [rows] with their
  /// own gids and timestamps, all in one transaction. Rows already in the DB
  /// are replaced in place, so restoring the same backup twice doesn't pile
  /// up copies, and thousands of rows don't mean thousands of commits.
  Future<void> replaceAll(List<IncomeDto> rows) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await AppDb.instance.db.transaction((txn) async {
      await txn.update('incomes', {
        'isDeleted': 1,
        'isDirty': 1,
        'updatedAtUtc': now,
      }, where: 'isDeleted = 0');
      final batch = txn.batch();
      for (final r in rows) {
        batch.insert(
          'incomes',
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<IncomeDto>> list({
    DateTime? fromUtc,
    DateTime? toUtc,
    bool includeDeleted = false,
  }) async {
    final db = AppDb.instance.db;
    final where = <String>[];
    final args = <Object?>[];

    if (!includeDeleted) where.add('isDeleted = 0');
    if (fromUtc != null) {
      where.add('occurredAtUtc >= ?');
      args.add(fromUtc.toIso8601String());
    }
    if (toUtc != null) {
      where.add('occurredAtUtc <= ?');
      args.add(toUtc.toIso8601String());
    }

    final rows = await db.query(
      'incomes',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'occurredAtUtc DESC',
    );
    return rows.map(IncomeDto.fromMap).toList();
  }

  Future<IncomeDto?> getByGid(String gid) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      'incomes',
      where: 'gid = ?',
      whereArgs: [gid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IncomeDto.fromMap(rows.first);
  }

  Future<int> update(String gid, Map<String, Object?> updates) async {
    if (updates.isEmpty) return 0;
    final db = AppDb.instance.db;
    final current = await getByGid(gid);
    final nextVersion = (current?.version ?? 1) + 1;

    final patch = Map<String, Object?>.from(updates);
    patch['updatedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    patch['isDirty'] = 1;
    patch['version'] = nextVersion;

    return db.update('incomes', patch, where: 'gid = ?', whereArgs: [gid]);
  }

  Future<int> softDelete(String gid) async {
    final db = AppDb.instance.db;
    final current = await getByGid(gid);
    final nextVersion = (current?.version ?? 1) + 1;

    return db.update(
      'incomes',
      {
        'isDeleted': 1,
        'isDirty': 1,
        'version': nextVersion,
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'gid = ?',
      whereArgs: [gid],
    );
  }
}

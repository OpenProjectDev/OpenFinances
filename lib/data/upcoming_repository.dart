import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';

import 'currency_units.dart';
import 'db.dart';

/// A planned payment (e.g. "internet bill, due in 5 days"). It is NOT an
/// expense: it becomes one only when paid with its sheet's Record box
/// ticked. Paid, it stays ([paidAtUtc]), faded, until the user deletes it;
/// undoable.
class UpcomingDto {
  final String gid;
  final String title;
  final int amountMinor;
  final String currency;
  final DateTime dueAtUtc;
  final String? note;
  final String? categoryGid;

  /// When it was paid; null: still to pay.
  final DateTime? paidAtUtc;

  /// The expense it added when paid (Record ticked), and the item "Pay &
  /// reschedule" scheduled after it: undoing the payment takes them back.
  final String? ledgerGid, nextGid;
  final int version;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final bool isDeleted;
  final bool isDirty;

  bool get isPaid => paidAtUtc != null;

  UpcomingDto({
    required this.gid,
    required this.title,
    required this.amountMinor,
    this.currency = 'IRR',
    required this.dueAtUtc,
    this.note,
    this.categoryGid,
    this.paidAtUtc,
    this.ledgerGid,
    this.nextGid,
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
    'dueAtUtc': dueAtUtc.toIso8601String(),
    'note': note,
    'categoryGid': categoryGid,
    'paidAtUtc': paidAtUtc?.toIso8601String(),
    'ledgerGid': ledgerGid,
    'nextGid': nextGid,
    'version': version,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'isDirty': isDirty ? 1 : 0,
  };

  static UpcomingDto fromMap(Map<String, Object?> m) => UpcomingDto(
    gid: (m['gid'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    amountMinor: (m['amountMinor'] as int?) ?? 0,
    currency: (m['currency'] as String?) ?? 'IRR',
    dueAtUtc: DateTime.parse((m['dueAtUtc'] ?? '') as String).toUtc(),
    note: m['note'] as String?,
    categoryGid: m['categoryGid'] as String?,
    paidAtUtc: DateTime.tryParse((m['paidAtUtc'] ?? '') as String)?.toUtc(),
    ledgerGid: m['ledgerGid'] as String?,
    nextGid: m['nextGid'] as String?,
    version: (m['version'] as int?) ?? 1,
    createdAtUtc: DateTime.parse((m['createdAtUtc'] ?? '') as String).toUtc(),
    updatedAtUtc: DateTime.parse((m['updatedAtUtc'] ?? '') as String).toUtc(),
    isDeleted: ((m['isDeleted'] as int?) ?? 0) == 1,
    isDirty: ((m['isDirty'] as int?) ?? 0) == 1,
  );

  /// This item as shown in [unit] (toman/rial converted; display only).
  UpcomingDto inUnit(String unit) {
    final shown = amountInUnit(amountMinor, currency, unit);
    if (shown == amountMinor) return this;
    return UpcomingDto(
      gid: gid,
      title: title,
      amountMinor: shown,
      currency: unit,
      dueAtUtc: dueAtUtc,
      note: note,
      categoryGid: categoryGid,
      paidAtUtc: paidAtUtc,
      ledgerGid: ledgerGid,
      nextGid: nextGid,
      version: version,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      isDeleted: isDeleted,
      isDirty: isDirty,
    );
  }
}

/// One remembered title (+ its last amount/category) for add-time
/// suggestions, like search history. Removable individually.
class UpcomingSuggestion {
  final String title;
  final int amountMinor;
  final String? categoryGid;
  final DateTime lastUsedAtUtc;

  /// Unit [amountMinor] was recorded in (null on rows from before units
  /// were kept: shown as is).
  final String? currency;

  const UpcomingSuggestion({
    required this.title,
    required this.amountMinor,
    this.categoryGid,
    required this.lastUsedAtUtc,
    this.currency,
  });

  Map<String, Object?> toMap() => {
    'title': title,
    'amountMinor': amountMinor,
    'categoryGid': categoryGid,
    'lastUsedAtUtc': lastUsedAtUtc.toIso8601String(),
    'currency': currency,
  };

  /// This suggestion as shown in [unit] (display only).
  UpcomingSuggestion inUnit(String unit) {
    if (currency == null) return this;
    final shown = amountInUnit(amountMinor, currency, unit);
    if (shown == amountMinor) return this;
    return UpcomingSuggestion(
      title: title,
      amountMinor: shown,
      categoryGid: categoryGid,
      lastUsedAtUtc: lastUsedAtUtc,
      currency: unit,
    );
  }

  static UpcomingSuggestion fromMap(Map<String, Object?> m) =>
      UpcomingSuggestion(
        title: (m['title'] ?? '') as String,
        amountMinor: (m['amountMinor'] as int?) ?? 0,
        categoryGid: m['categoryGid'] as String?,
        lastUsedAtUtc:
            DateTime.tryParse((m['lastUsedAtUtc'] ?? '') as String)?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        currency: m['currency'] as String?,
      );
}

class UpcomingRepository {
  final _uuid = const Uuid();

  /// Adds it; its gid.
  Future<String> create({
    required String title,
    required int amountMinor,
    required DateTime dueLocal,
    String? note,
    String? categoryGid,
    String currency = 'IRR',
  }) async {
    final db = AppDb.instance.db;
    final nowUtc = DateTime.now().toUtc();

    final row = UpcomingDto(
      gid: _uuid.v7(),
      title: title,
      amountMinor: amountMinor,
      currency: currency,
      dueAtUtc: dueLocal.toUtc(),
      note: note,
      categoryGid: categoryGid,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    await db.insert(
      'upcoming_payments',
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
  Future<void> replaceAll(List<UpcomingDto> rows) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await AppDb.instance.db.transaction((txn) async {
      await txn.update('upcoming_payments', {
        'isDeleted': 1,
        'isDirty': 1,
        'updatedAtUtc': now,
      }, where: 'isDeleted = 0');
      final batch = txn.batch();
      for (final r in rows) {
        batch.insert(
          'upcoming_payments',
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Pending items, soonest due first.
  Future<List<UpcomingDto>> list() async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      'upcoming_payments',
      where: 'isDeleted = 0',
      orderBy: 'dueAtUtc ASC',
    );
    return rows.map(UpcomingDto.fromMap).toList();
  }

  Future<UpcomingDto?> getByGid(String gid) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      'upcoming_payments',
      where: 'gid = ?',
      whereArgs: [gid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UpcomingDto.fromMap(rows.first);
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

    return db.update(
      'upcoming_payments',
      patch,
      where: 'gid = ?',
      whereArgs: [gid],
    );
  }

  Future<int> softDelete(String gid) async {
    final db = AppDb.instance.db;
    final current = await getByGid(gid);
    final nextVersion = (current?.version ?? 1) + 1;

    return db.update(
      'upcoming_payments',
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

  // ----------------- Title history -----------------

  /// Most recently used first.
  Future<List<UpcomingSuggestion>> listHistory() async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      'upcoming_history',
      orderBy: 'lastUsedAtUtc DESC',
    );
    return rows.map(UpcomingSuggestion.fromMap).toList();
  }

  Future<void> rememberTitle({
    required String title,
    required int amountMinor,
    String? categoryGid,
    DateTime? usedAtUtc,
    String? currency,
  }) async {
    final db = AppDb.instance.db;
    await db.insert(
      'upcoming_history',
      UpcomingSuggestion(
        title: title,
        amountMinor: amountMinor,
        categoryGid: categoryGid,
        lastUsedAtUtc: usedAtUtc ?? DateTime.now().toUtc(),
        currency: currency,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> forgetTitle(String title) async {
    final db = AppDb.instance.db;
    await db.delete('upcoming_history', where: 'title = ?', whereArgs: [title]);
  }
}

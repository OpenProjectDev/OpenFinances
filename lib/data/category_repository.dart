import 'dart:async'; // ✅ for StreamController + scheduleMicrotask
import 'package:flutter/material.dart'; // for Icons + colors
import 'package:sqflite/sqflite.dart';
import 'backup_values.dart';
import 'db.dart';

class CategoryDto {
  final String gid;
  final String name;
  final int sort;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final bool isDeleted;
  final bool isDirty;

  // NEW:
  final int iconCodePoint; // e.g. Icons.shopping_cart.codePoint
  final String? iconFontFamily; // usually 'MaterialIcons'
  final int color; // ARGB int (Color.value or your toARGB32())

  CategoryDto({
    required this.gid,
    required this.name,
    required this.sort,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.isDeleted = false,
    this.isDirty = true,
    int? iconCodePoint,
    String? iconFontFamily,
    int? color,
  }) : iconCodePoint = iconCodePoint ?? Icons.category.codePoint,
       iconFontFamily = iconFontFamily ?? 'MaterialIcons',
       color =
           color ?? const Color(0xFF607D8B).toARGB32(); // keep your extension

  static CategoryDto fromMap(Map<String, Object?> m) => CategoryDto(
    gid: m['gid'] as String,
    name: m['name'] as String,
    sort: m['sort'] as int,
    createdAtUtc: DateTime.parse(m['createdAtUtc'] as String).toUtc(),
    updatedAtUtc: DateTime.parse(m['updatedAtUtc'] as String).toUtc(),
    isDeleted: (m['isDeleted'] as int) == 1,
    isDirty: (m['isDirty'] as int) == 1,
    iconCodePoint: (m['iconCodePoint'] as int?) ?? Icons.category.codePoint,
    iconFontFamily: (m['iconFontFamily'] as String?) ?? 'MaterialIcons',
    color:
        (m['color'] as int?) ??
        const Color(0xFF607D8B).toARGB32(), // keep your extension
  );

  Map<String, Object?> toMap() => {
    'gid': gid,
    'name': name,
    'sort': sort,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'isDirty': isDirty ? 1 : 0,
    // NEW
    'iconCodePoint': iconCodePoint,
    'iconFontFamily': iconFontFamily,
    'color': color,
  };

  CategoryDto copyWith({
    String? gid,
    String? name,
    int? sort,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    bool? isDeleted,
    bool? isDirty,
    int? iconCodePoint,
    String? iconFontFamily,
    int? color,
  }) {
    return CategoryDto(
      gid: gid ?? this.gid,
      name: name ?? this.name,
      sort: sort ?? this.sort,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      isDeleted: isDeleted ?? this.isDeleted,
      isDirty: isDirty ?? this.isDirty,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      color: color ?? this.color,
    );
  }
}

class CategoryRepository {
  /// Table this repository reads/writes. Defaults to the expense
  /// categories table; pass 'income_categories' for income categories.
  /// Both tables share the exact same schema (see db.dart).
  CategoryRepository({String table = 'categories'}) : _table = table;

  final String _table;

  /// The table it manages ('categories' or 'income_categories').
  String get table => _table;

  Database get _db => AppDb.instance.db;

  /// One change stream per table, shared by every repository object: a
  /// write through any of them (e.g. the category management page's own)
  /// reaches the providers watching the table.
  static final Map<String, StreamController<void>> _bus = {};
  static final Set<String> _pending = {};
  StreamController<void> get _changes =>
      _bus.putIfAbsent(_table, () => StreamController<void>.broadcast());
  Stream<void> watch() => _changes.stream;

  /// Writes in a burst (e.g. a reorder saving every row) send one change.
  void _emitChange() {
    if (!_pending.add(_table)) return;
    // microtask avoids re-entrancy with setState/notifyListeners
    scheduleMicrotask(() {
      _pending.remove(_table);
      _changes.add(null);
    });
  }

  // One migration per table per app run, shared by every repository
  // instance: on a fresh install several providers read categories at the
  // same moment, and racing ALTER TABLEs failed with "duplicate column".
  static final Map<String, Future<void>> _metaReady = {};

  Future<void> _ensureMetaColumns() {
    return _metaReady[_table] ??= _addMetaColumns().catchError((Object e) {
      _metaReady.remove(_table); // let a later call retry
      throw e;
    });
  }

  /// Makes sure the table has its icon / color columns (a restore writes
  /// them straight into it).
  Future<void> ensureColumns() => _ensureMetaColumns();

  Future<void> _addColumn(String ddl) async {
    try {
      await _db.execute(ddl);
    } catch (e) {
      if (!e.toString().contains('duplicate column name')) rethrow;
    }
  }

  Future<void> _addMetaColumns() async {
    final info = await _db.rawQuery('PRAGMA table_info($_table)');
    bool hasIcon = false, hasFont = false, hasColor = false;
    for (final r in info) {
      final name = (r['name'] as String?) ?? '';
      if (name == 'iconCodePoint') hasIcon = true;
      if (name == 'iconFontFamily') hasFont = true;
      if (name == 'color') hasColor = true;
    }
    if (!hasIcon) {
      await _addColumn('ALTER TABLE $_table ADD COLUMN iconCodePoint INTEGER');
      await _db.execute(
        'UPDATE $_table SET iconCodePoint = ${Icons.category.codePoint}',
      );
      _emitChange(); // schema change affects reads
    }
    if (!hasFont) {
      await _addColumn('ALTER TABLE $_table ADD COLUMN iconFontFamily TEXT');
      await _db.execute("UPDATE $_table SET iconFontFamily = 'MaterialIcons'");
      _emitChange();
    }
    if (!hasColor) {
      await _addColumn('ALTER TABLE $_table ADD COLUMN color INTEGER');
      await _db.execute(
        'UPDATE $_table SET color = ${const Color(0xFF607D8B).toARGB32()}',
      );
      _emitChange();
    }
  }

  Future<List<CategoryDto>> list({bool includeDeleted = false}) async {
    await _ensureMetaColumns();
    final rows = await _db.query(
      _table,
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'sort ASC, name ASC',
    );
    return rows.map(CategoryDto.fromMap).toList();
  }

  /// The general category of this table (preferred home for entries whose
  /// category is deleted).
  String get generalGid =>
      _table == 'income_categories' ? 'inccat_general' : 'cat_general';

  bool get isIncome => _table == 'income_categories';

  /// Deletes [gid] and moves everything filed under it (entries, upcoming
  /// payments, remembered titles) to [target], so nothing points at a
  /// category that's gone.
  Future<void> deleteMovingTo(String gid, String target) async {
    if (gid == target) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final moved = {'categoryGid': target, 'isDirty': 1, 'updatedAtUtc': now};
    await _db.transaction((tx) async {
      final ledger = _table == 'income_categories'
          ? const ['incomes']
          : const ['expenses', 'upcoming_payments'];
      for (final t in ledger) {
        await tx.update(t, moved, where: 'categoryGid = ?', whereArgs: [gid]);
      }
      if (_table != 'income_categories') {
        await tx.update(
          'upcoming_history',
          {'categoryGid': target},
          where: 'categoryGid = ?',
          whereArgs: [gid],
        );
      }
      await tx.update(
        _table,
        {'isDeleted': 1, 'isDirty': 1, 'updatedAtUtc': now},
        where: 'gid = ?',
        whereArgs: [gid],
      );
    });
    _emitChange();
  }

  Future<void> softDelete(String gid) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      _table,
      {'isDeleted': 1, 'isDirty': 1, 'updatedAtUtc': now},
      where: 'gid = ?',
      whereArgs: [gid],
    );
    _emitChange(); // ✅ notify listeners
  }

  Future<void> upsert(CategoryDto c) async {
    await _ensureMetaColumns();
    await _db.insert(
      _table,
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange(); // ✅ notify listeners
  }

  // (Optional, handy) Rename by gid without constructing a full DTO
  Future<void> rename(String gid, String newName) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      _table,
      {'name': newName, 'isDirty': 1, 'updatedAtUtc': now},
      where: 'gid = ?',
      whereArgs: [gid],
    );
    _emitChange();
  }

  // (Optional) Update visuals (icon/color) by gid
  Future<void> updateVisuals({
    required String gid,
    int? iconCodePoint,
    String? iconFontFamily,
    int? color,
  }) async {
    final patch = <String, Object?>{};
    if (iconCodePoint != null) patch['iconCodePoint'] = iconCodePoint;
    if (iconFontFamily != null) patch['iconFontFamily'] = iconFontFamily;
    if (color != null) patch['color'] = color;
    if (patch.isEmpty) return;

    patch['isDirty'] = 1;
    patch['updatedAtUtc'] = DateTime.now().toUtc().toIso8601String();

    await _db.update(_table, patch, where: 'gid = ?', whereArgs: [gid]);
    _emitChange();
  }

  /// Restore: writes each backup category (own gid, name, order, icon,
  /// color) over what's there; categories missing from the backup are kept.
  /// Each row on its own, so one bad row doesn't stop the rest.
  Future<void> restoreFromBackup(List<Map<String, dynamic>> rows) async {
    final existing = {
      for (final c in await list(includeDeleted: true)) c.gid: c,
    };
    var fallbackSort = (existing.length + 1) * 100;
    for (final c in rows) {
      try {
        final gid = backupString(c['gid']);
        final name = backupString(c['name']);
        if (gid == null || name == null) continue;
        final old = existing[gid];
        final created =
            backupDateUtc(c['createdAtUtc']) ??
            old?.createdAtUtc ??
            DateTime.now().toUtc();
        await upsert(
          CategoryDto(
            gid: gid,
            name: name,
            sort: backupInt(c['sort']) ?? old?.sort ?? (fallbackSort += 100),
            createdAtUtc: created,
            updatedAtUtc: backupDateUtc(c['updatedAtUtc']) ?? created,
            iconCodePoint: backupInt(c['iconCodePoint']) ?? old?.iconCodePoint,
            iconFontFamily:
                backupString(c['iconFontFamily']) ?? old?.iconFontFamily,
            color: backupInt(c['color']) ?? old?.color,
          ),
        );
      } catch (e) {
        debugPrint('[restore] $_table row skipped: $e');
      }
    }
  }

  /// Nothing to release: the change stream is shared and lives with the app.
  void dispose() {}
}

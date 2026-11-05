import 'dart:async';
import 'package:flutter/foundation.dart';

import 'income_repository.dart';
import 'backup_values.dart';
import 'currency_units.dart';
import 'category_repository.dart';

/// Mirrors ExpenseProvider, but for income. Kept entirely separate from
/// expenses — no balance/subtraction anywhere here. Correlating the two
/// is left to a dedicated statistics view later.
class IncomeProvider extends ChangeNotifier {
  final IncomeRepository _repo;
  final CategoryRepository _catRepo;

  IncomeProvider({
    IncomeRepository? incomeRepo,
    CategoryRepository? categoryRepo,
  }) : _repo = incomeRepo ?? IncomeRepository(),
       _catRepo =
           categoryRepo ?? CategoryRepository(table: 'income_categories');

  // ----------------- State -----------------

  /// Rows as shown: `amountMinor` is in the display unit (toman/rial
  /// converted), `recordedAmountMinor` + `currency` are exactly what was
  /// stored. Backups and exports use the recorded values.
  List<Map<String, dynamic>> _raw = [];
  List<Map<String, dynamic>> get raw => _raw;

  List<IncomeDto> _rows = [];

  /// Unit amounts are shown in (the user's currency setting).
  String _displayCurrency = 'IRT';

  /// Called when the currency setting changes: re-derives the shown amounts;
  /// nothing stored changes.
  void setDisplayCurrency(String code) {
    if (code == _displayCurrency) return;
    _displayCurrency = code;
    _raw = _toRows();
    // May be called while providers rebuild: notify after this frame's work.
    scheduleMicrotask(notifyListeners);
  }

  List<Map<String, dynamic>> _toRows() => [
    for (final e in _rows)
      {
        'gid': e.gid,
        'title': e.title,
        'amountMinor': amountInUnit(
          e.amountMinor,
          e.currency,
          _displayCurrency,
        ),
        'recordedAmountMinor': e.amountMinor,
        'currency': e.currency,
        'occurredAtUtc': e.occurredAtUtc,
        'note': e.note,
        'categoryGid': e.categoryGid,
        'accountGid': e.accountGid,
        'version': e.version,
        'createdAtUtc': e.createdAtUtc,
        'updatedAtUtc': e.updatedAtUtc,
        'isDeleted': e.isDeleted,
        'isDirty': e.isDirty,
      },
  ];

  List<CategoryDto> _categories = [];
  List<CategoryDto> get categories => _categories;

  /// Where an entry without a category goes (and a deleted category's
  /// entries went): the general category while it exists, else the first.
  /// There's always at least one category.
  String get fallbackCategoryGid {
    for (final c in _categories) {
      if (c.gid == 'inccat_general') return c.gid;
    }
    return _categories.isEmpty ? 'inccat_general' : _categories.first.gid;
  }

  /// Name of [gid]'s category; unknown or missing ones count as the
  /// fallback category.
  String categoryName(String? gid) {
    for (final c in _categories) {
      if (c.gid == gid) return c.name;
    }
    final f = fallbackCategoryGid;
    for (final c in _categories) {
      if (c.gid == f) return c.name;
    }
    return '';
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<void>? _catWatchSub;

  // ----------------- Lifecycle -----------------

  Future<void> init() async {
    await loadCategories();
    await loadIncomes();

    _catWatchSub?.cancel();
    _catWatchSub = _catRepo.watch().listen((_) async {
      await loadCategories();
    });
  }

  @override
  void dispose() {
    _catWatchSub?.cancel();
    super.dispose();
  }

  // ----------------- Loads -----------------

  Future<void> loadCategories() async {
    try {
      _categories = await _catRepo.list();
      notifyListeners();
    } catch (_) {
      // ignore; categories can be empty
    }
  }

  /// Reads the ledger again. Only the first load shows as loading: a reload
  /// after a change keeps the list shown until the new one is in, and tells
  /// once (it told twice, the first time "loading": History swapped its
  /// whole list for a spinner and built it again from scratch, the lag
  /// after Upcoming's Paid; the owner, 2026-10-31).
  Future<void> loadIncomes() async {
    final first = !_loadedOnce;
    if (first) _setLoading(true);
    try {
      _rows = await _repo.list();
      _raw = _toRows();
      _error = null;
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (first) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    }
  }

  bool _loadedOnce = false;

  Future<void> reload() => loadIncomes();

  // ----------------- Income CRUD -----------------

  /// Adds an income; its gid.
  Future<String> addIncome({
    required String title,
    required int amountMinor,
    required DateTime occurredLocal,
    String? note,
    String? categoryGid,
    String? accountGid,
    String currency = 'IRR',
  }) async {
    final gid = await _repo.create(
      title: title,
      amountMinor: amountMinor,
      occurredLocal: occurredLocal,
      note: note,
      categoryGid: categoryGid,
      accountGid: accountGid,
      currency: currency,
    );
    await loadIncomes();
    return gid;
  }

  Future<void> updateIncome(String gid, Map<String, Object?> updates) async {
    await _repo.update(gid, updates);
    await loadIncomes();
  }

  Future<void> deleteIncome(String gid) async {
    await _repo.softDelete(gid);
    await loadIncomes();
  }

  Map<String, dynamic>? findByGid(String gid) {
    try {
      return _raw.firstWhere((e) => e['gid'] == gid);
    } catch (_) {
      return null;
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ----------------- Category helpers (UI proxies) -----------------

  Future<void> upsertCategory(CategoryDto c) async {
    await _catRepo.upsert(c);
    await loadCategories();
  }

  Future<void> renameCategory(String gid, String newName) async {
    await _catRepo.rename(gid, newName);
    await loadCategories();
  }

  Future<void> deleteCategory(String gid) async {
    await _catRepo.softDelete(gid);
    await loadCategories();
  }

  // ----------------- Backup / Restore -----------------

  /// Return a JSON-friendly dump of current income categories & entries.
  Future<Map<String, dynamic>> exportForBackup() async {
    await loadCategories();
    await loadIncomes();

    final categories = _categories
        .map<Map<String, dynamic>>(
          (c) => {
            'gid': c.gid,
            'name': c.name,
            'sort': c.sort,
            'createdAtUtc': c.createdAtUtc.toIso8601String(),
            'updatedAtUtc': c.updatedAtUtc.toIso8601String(),
            'isDeleted': c.isDeleted,
            'isDirty': c.isDirty,
            'iconCodePoint': c.iconCodePoint,
            'iconFontFamily': c.iconFontFamily,
            'color': c.color,
          },
        )
        .toList();

    String? toIso(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toIso8601String();
      if (v is String) return v;
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          v,
          isUtc: true,
        ).toIso8601String();
      }
      if (v is double) {
        return DateTime.fromMillisecondsSinceEpoch(
          v.toInt(),
          isUtc: true,
        ).toIso8601String();
      }
      return v.toString();
    }

    final incomes = _raw
        .map<Map<String, dynamic>>(
          (e) => {
            'gid': e['gid'],
            'title': e['title'],
            'amountMinor': e['recordedAmountMinor'],
            'currency': e['currency'],
            'occurredAtUtc': toIso(e['occurredAtUtc']),
            'note': e['note'],
            'categoryGid': e['categoryGid'],
            'accountGid': e['accountGid'],
            'version': e['version'],
            'createdAtUtc': toIso(e['createdAtUtc']),
            'updatedAtUtc': toIso(e['updatedAtUtc']),
            'isDeleted': e['isDeleted'] == true,
            'isDirty': e['isDirty'] == true,
          },
        )
        .toList();

    return {'incomeCategories': categories, 'incomes': incomes};
  }

  /// Restore: categories are merged in (backup wins), entries replace the
  /// current ones, keeping their original gids and timestamps.
  Future<void> importFromBackup({
    required List<Map<String, dynamic>> categoriesJson,
    required List<Map<String, dynamic>> incomesJson,
  }) async {
    await _catRepo.restoreFromBackup(categoriesJson);

    final now = DateTime.now().toUtc();
    final rows = <IncomeDto>[];
    for (final e in incomesJson) {
      final title = backupString(e['title']) ?? '';
      final amountMinor = backupInt(e['amountMinor'] ?? e['amount']);
      if (title.isEmpty || amountMinor == null) continue;
      if (backupBool(e['isDeleted']) == true) continue;
      final created = backupDateUtc(e['createdAtUtc']) ?? now;
      rows.add(
        IncomeDto(
          gid: backupString(e['gid']) ?? _repo.newGid(),
          title: title,
          amountMinor: amountMinor,
          currency: backupString(e['currency']) ?? 'IRR',
          occurredAtUtc:
              backupDateUtc(e['occurredAtUtc'] ?? e['occurredAt']) ?? now,
          note: backupString(e['note']),
          categoryGid: backupString(e['categoryGid']),
          accountGid: backupString(e['accountGid']),
          version: backupInt(e['version']) ?? 1,
          createdAtUtc: created,
          updatedAtUtc: backupDateUtc(e['updatedAtUtc']) ?? created,
        ),
      );
    }
    await _repo.replaceAll(rows);

    await loadCategories();
    await loadIncomes();
  }
}

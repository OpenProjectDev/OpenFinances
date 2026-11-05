import 'package:openfinances/data/upcoming_repository.dart';

/// Title suggestions for the add/edit sheet (no amounts: the owner,
/// 2026-10-25, they only had to be erased), derived from the
/// ledger itself (no extra table: nothing to migrate, back up or keep in
/// sync). Built in one pass over a provider's rows and cached per list
/// instance; providers replace their list on every change, so a new list
/// means a fresh index.
class EntrySuggestions {
  EntrySuggestions._(this._titles);

  /// Most used first (ties: most recent first).
  final List<_TitleStat> _titles;

  late final Map<String, _TitleStat> _byKey = {
    for (final t in _titles) t.key: t,
  };

  static final Expando<EntrySuggestions> _cache = Expando();

  /// The index for [rows] (expense or income rows with 'title',
  /// 'categoryGid' and 'occurredAtUtc'), built once per list instance.
  static EntrySuggestions of(List<Map<String, dynamic>> rows) =>
      _cache[rows] ??= EntrySuggestions.build(rows);

  /// Expense titles: the ledger's and Due's (a payment there is an expense
  /// too), one list for the add sheet and Due's editor (the owner,
  /// 2026-10-27: Due suggested only its own). Built once per pair of lists.
  static EntrySuggestions ofExpenses(
    List<Map<String, dynamic>> rows,
    List<UpcomingSuggestion> due,
  ) {
    final hit = _expenses;
    if (hit != null && identical(hit.$1, rows) && identical(hit.$2, due)) {
      return hit.$3;
    }
    final index = EntrySuggestions.build([
      ...rows,
      for (final h in due)
        {
          'title': h.title,
          'categoryGid': h.categoryGid,
          'occurredAtUtc': h.lastUsedAtUtc,
        },
    ]);
    _expenses = (rows, due, index);
    return index;
  }

  static (Object, Object, EntrySuggestions)? _expenses;

  factory EntrySuggestions.build(Iterable<Map<String, dynamic>> rows) {
    final byKey = <String, _TitleStat>{};
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    for (final r in rows) {
      final title = (r['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      final when = r['occurredAtUtc'] is DateTime
          ? r['occurredAtUtc'] as DateTime
          : epoch;
      final stat = byKey.putIfAbsent(
        normalize(title),
        () => _TitleStat(normalize(title)),
      );
      stat.count++;
      if (!when.isBefore(stat.last)) {
        stat.last = when;
        stat.display = title; // show the most recent spelling
        stat.category = r['categoryGid'] as String?;
      }
    }

    final titles = byKey.values.toList()
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : b.last.compareTo(a.last);
      });
    return EntrySuggestions._(titles);
  }

  /// Lowercase, trimmed, single spaces, Arabic ي/ك as Persian ی/ک, no ZWNJ:
  /// "ناهار " and "ناهار" are one title.
  static String normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('‌', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool get hasTitles => _titles.isNotEmpty;

  /// Titles by usage; with a [query], only those containing it. [hide]
  /// drops titles the user doesn't want suggested (by the title, or the
  /// category it was last used in).
  List<String> titles({
    String query = '',
    bool Function(String title, String? categoryGid)? hide,
  }) {
    final q = normalize(query);
    return [
      for (final t in _titles)
        if ((q.isEmpty || t.key.contains(q)) &&
            !(hide?.call(t.display, t.category) ?? false))
          t.display,
    ];
  }

  /// The category [title] was last used with, if it has been used.
  String? categoryFor(String title) => _byKey[normalize(title)]?.category;

  /// Whether [title] has been used before (normalized match).
  bool knows(String title) => _byKey.containsKey(normalize(title));
}

class _TitleStat {
  _TitleStat(this.key) : display = key;
  final String key;
  String display;

  /// Category of the most recent use.
  String? category;
  int count = 0;
  DateTime last = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

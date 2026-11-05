import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/entry_suggestions.dart';
import 'package:openfinances/data/upcoming_repository.dart';

Map<String, dynamic> _r(String title, int toman, int day) => {
  'title': title,
  'amountMinor': toman * 100,
  'occurredAtUtc': DateTime.utc(2026, 1, day),
};

void main() {
  final rows = [
    _r('نان', 20000, 1),
    _r('نان', 20000, 2),
    _r('نان', 25000, 3),
    _r('نان ', 20000, 4), // trailing space: same title
    _r('اسنپ', 80000, 5),
    _r('اسنپ', 120000, 6),
    _r('ناهار', 250000, 7),
    _r('كباب', 900000, 8), // Arabic kaf
  ];
  final s = EntrySuggestions.build(rows);

  test('titles ranked by usage, filtered by what is typed', () {
    expect(s.titles().first, 'نان');
    expect(s.titles().take(2), ['نان', 'اسنپ']);
    expect(s.titles(query: 'نا'), ['نان', 'ناهار']);
    expect(s.titles(query: 'کباب'), ['كباب']); // Persian kaf matches Arabic
    expect(s.titles(query: 'zzz'), isEmpty);
  });

  test('a title brings the category it was last used in', () {
    final c = EntrySuggestions.build([
      {..._r('نان', 20000, 1), 'categoryGid': 'old'},
      {..._r('نان', 20000, 2), 'categoryGid': 'food'},
    ]);
    expect(c.categoryFor('نان'), 'food');
    expect(c.knows('نان '), isTrue);
  });

  test('cached per list instance', () {
    expect(
      identical(EntrySuggestions.of(rows), EntrySuggestions.of(rows)),
      isTrue,
    );
  });

  // One list for the add sheet and Due's editor (the owner, 2026-10-27).
  test('expense titles include Due titles', () {
    final due = [
      UpcomingSuggestion(
        title: 'قبض برق',
        amountMinor: 0,
        categoryGid: 'cat_bills',
        lastUsedAtUtc: DateTime.utc(2026, 1, 9),
      ),
      UpcomingSuggestion(
        title: 'نان',
        amountMinor: 0,
        lastUsedAtUtc: DateTime.utc(2026, 1, 1),
      ),
    ];
    final both = EntrySuggestions.ofExpenses(rows, due);
    expect(both.titles(), contains('قبض برق'));
    expect(both.categoryFor('قبض برق'), 'cat_bills');
    expect(both.titles().where((t) => t.trim() == 'نان'), hasLength(1));
    expect(identical(EntrySuggestions.ofExpenses(rows, due), both), isTrue);
  });
}

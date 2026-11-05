import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> _loaded() async {
  final sp = SettingsProvider();
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return sp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('older ignore lists fold into the six current ones', () async {
    // As left by older versions (or an older backup's prefs, restored).
    SharedPreferences.setMockInitialValues({
      'ignoredTitlesV1': ['old'],
      'ignoredTitles.expense': ['سوشی'],
      'ignoredTitles.upcoming': ['کادو', 'سوشي'], // same as سوشی (Arabic ي)
      'ignoredTitles.debt': ['قسط'],
      'ignoredTitles.people': ['امیر'],
    });
    final s = await _loaded();

    expect(s.ignoredTitles(SuggestSource.expense), ['سوشی', 'old', 'کادو']);
    expect(s.ignoredTitles(SuggestSource.income), ['old']);
    for (final src in [SuggestSource.oweTitle, SuggestSource.owedTitle]) {
      expect(s.ignoredTitles(src), ['قسط']);
    }
    for (final src in [SuggestSource.owePerson, SuggestSource.owedPerson]) {
      expect(s.ignoredTitles(src), ['امیر']);
    }

    // The old keys are gone and the new ones stored: a restart reads the
    // same lists without migrating again.
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      'ignoredTitlesV1',
      'ignoredTitles.upcoming',
      'ignoredTitles.debt',
      'ignoredTitles.people',
    ]) {
      expect(prefs.containsKey(k), isFalse, reason: k);
    }
    expect(prefs.getStringList('ignoredTitles.owedPerson'), ['امیر']);
  });

  test('ignoring is per list', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await _loaded();
    await s.ignoreTitle(SuggestSource.owePerson, 'Sara');
    expect(s.isTitleIgnored(SuggestSource.owePerson, 'sara '), isTrue);
    expect(s.isTitleIgnored(SuggestSource.owedPerson, 'Sara'), isFalse);
    await s.unignoreTitle(SuggestSource.owePerson, 'SARA');
    expect(s.ignoredTitles(SuggestSource.owePerson), isEmpty);
  });
}

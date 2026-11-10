import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/data/backup_values.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide calendar selection.
enum AppCalendar { jalali, gregorian }

/// The lists of suggestions, each with its own ignore list: entry titles by
/// kind (upcoming payments are expenses: they share the expense list), and
/// for each side of debts (I owe / I'm owed) its titles and its people.
enum SuggestSource {
  expense,
  income,
  oweTitle,
  owePerson,
  owedTitle,
  owedPerson,
}

/// The charts' series off at first: the same day's average and the daily
/// average (the owner, 2026-11-02).
const kChartLinesOffAtFirst = {'sameDay', 'average'};

class SettingsProvider extends ChangeNotifier {
  // ===== Pref keys =====
  static const _kThemeMode = 'themeMode'; // 'system' | 'light' | 'dark'
  static const _kSeedColor = 'seedColor';
  static const _kOnSeedTextIsWhite = 'onSeedTextIsWhite';
  static const _kCurrency = 'currency';
  static const _kBiometric = 'biometric';
  static const _kPremium = 'premium';
  static const _kStartDay = 'startDay';
  static const _kLocale = 'locale'; // 'fa' | 'en'
  static const _kCalendar = 'calendar'; // 'jalali' | 'gregorian'
  // Per language: true = the app's font (Shabnam / Manrope), false = device.
  static const _kAppFontFa = 'appFontFa';
  static const _kAppFontEn = 'appFontEn';
  // Home page tabs besides History (each off until turned on in Settings).
  static const _kTabUpcoming = 'tabUpcoming';
  static const _kTabDebts = 'tabDebts';
  static const _kTabSms = 'tabSms';
  // Our own notification for bank messages, off until turned on (read
  // natively too, by AppPrefs: keep the key and the default in sync).
  static const _kBankNotify = 'bankNotify';
  // Title suggestions: titles the user ignored, and categories whose
  // titles aren't suggested.
  static const _kIgnoredTitlesLegacy = 'ignoredTitlesV1';
  static const _kNoSuggestCats = 'noSuggestCategoriesV1';
  // Suggestion rows in the add/edit sheets (off until turned on).
  static const _kSuggestionsOn = 'suggestionsOn';
  static const _kQuickZeros = 'quickZeros';
  static const _kHaptics = 'hapticsOn';
  static const _kRememberSections = 'rememberSections';
  static const _kRememberScroll = 'rememberScroll';
  // A due payment's sheet: paying it also records an expense (its Record
  // box; kept as last left).
  static const _kRecordDuePaid = 'recordDuePaid';

  /// Read natively too, by the backup agent (AppBackupAgent.kt, as
  /// `flutter.androidBackup` in FlutterSharedPreferences): keep the name.
  static const kAndroidBackup = 'androidBackup';
  // The backup box's last choices (null: none made yet).
  static const _kBackupFull = 'backupFull';
  static const _kBackupExcel = 'backupExcel';
  // Tips (lib/shared/ui/tips.dart): off by default; the ones shown.
  static const _kTipsOn = 'tipsOn';
  static const _kDigits = 'digits'; // DigitStyle's name
  static const _kTipsSeen = 'tipsSeenV1';
  static const _kScrollLearned = 'scrollLearnedV1';
  static const _kNeverShown = 'neverShownV1';
  static const _kDateOrder = 'dateOrder';
  static const _kDailyHidden = 'dailyChartHiddenV1';
  static const _kPaceHidden = 'paceChartHiddenV1';
  static const _kRememberEntries = 'rememberEntries';
  static const _kSectionOpenPrefix = 'sectionOpen.';
  static const _kScrollPrefix = 'scroll.';

  // ===== State =====
  int _startDay = 1; // default used in ExpensesPage
  int get startDay => _startDay;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // Strong dark blue by default on first install
  /// The brand's blue.
  static const Color _defaultSeed = kBrandBlue;

  /// Set once a theme color left at the brand green of a short-lived build
  /// (2026-10-22) has gone back to the blue.
  static const _kSeedBlueBack = 'seedBlueBack';
  Color _seedColor = _defaultSeed;
  Color get seedColor => _seedColor;

  // Text color on primary/seeded surfaces: default WHITE
  bool _onSeedTextIsWhite = true;
  bool get onSeedTextIsWhite => _onSeedTextIsWhite;

  // Optional convenience getter if you want a Color directly
  Color get onSeedTextColor => _onSeedTextIsWhite ? Colors.white : Colors.black;

  String _currencyCode = 'IRT';
  String get currencyCode => _currencyCode;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  // Locale (app language)
  Locale _locale = const Locale('fa'); // default Persian
  Locale get locale => _locale;

  // Calendar system (app-wide)
  AppCalendar _calendar = AppCalendar.jalali; // default Jalali
  AppCalendar get calendar => _calendar;

  // Font: the app's own font for each language, or the device font.
  bool _appFontFa = true;
  bool _appFontEn = true;

  /// Whether Persian text uses the app's font (Shabnam) or the device's.
  bool get appFontFa => _appFontFa;

  /// Whether English text uses the app's font (Manrope) or the device's.
  bool get appFontEn => _appFontEn;

  /// Whether numbers are written in Persian digits (Settings'
  /// Personalization).
  bool get _faDigits => appDigitStyle == DigitStyle.persian;

  /// The family all text starts from: English letters come from it (the
  /// app's Manrope, or the device font when null); Persian letters, which it
  /// doesn't have, from [fontFamilyFallback]. So each language gets its own
  /// choice, also mixed in one line. With the app's English font on, the
  /// DIGIT fonts come first (the owner's design agent, 2026-10-28): numbers
  /// in Persian digits from Vazirmatn (when the app's Persian font is on
  /// too), the rest, and every number in English digits, from Manrope's own
  /// digit cut; they hold only digits and their separators, so the letters
  /// fall through.
  String? get fontFamily => !_appFontEn
      ? null
      : (_faDigits && _appFontFa)
      ? 'VazirNum'
      : 'ManropeNum';

  /// Where the rest comes from, in order: the other digit font (always
  /// there when Persian is on: a Persian digit is Vazirmatn's wherever it
  /// shows, the Settings preview too), Manrope's letters, Persian letters
  /// from Shabnam, or (empty) the device font.
  /// The same list object while it's the same (the app shell compares it
  /// by identity: a new one each time rebuilt the shell and both themes,
  /// and faded every page's theme, on any settings change).
  List<String> get fontFamilyFallback {
    final list = [
      if (_appFontEn) ...[
        if (_faDigits && _appFontFa)
          'ManropeNum'
        else if (_appFontFa)
          'VazirNum',
        'Manrope',
      ],
      if (_appFontFa) 'Shabnam',
    ];
    final had = _fallback;
    if (had != null && listEquals(had, list)) return had;
    return _fallback = List.unmodifiable(list);
  }

  List<String>? _fallback;

  // Home page tabs (History is always there).
  bool _tabUpcoming = false;
  bool _tabDebts = false;
  bool _tabSms = false;
  bool get tabUpcoming => _tabUpcoming;
  bool get tabDebts => _tabDebts;
  bool get tabSms => _tabSms;

  bool _bankNotify = false;
  bool get bankNotify => _bankNotify;

  bool _suggestionsOn = false;

  /// Whether the add/edit sheets offer suggestion rows at all.
  bool get suggestionsOn => _suggestionsOn;

  bool? _quickZeros;

  /// A "000" button by an amount field's eraser once something is typed
  /// (the owner, 2026-10-26). Unset: on for toman and rial, off for dollars
  /// and euros, whatever the language (developer, 2026-11-10).
  bool get quickZeros => _quickZeros ?? zerosByDefault(_currencyCode);

  /// Whether [currency] has the "000" button on by default: amounts in toman
  /// and rial run to thousands and more.
  static bool zerosByDefault(String currency) =>
      currency == 'IRT' || currency == 'IRR';

  /// Felt touches ([Haptics]): on by default (the owner, 2026-11-01).
  bool _hapticsOn = true;
  bool get hapticsOn => _hapticsOn;

  Future<void> setHapticsOn(bool v) async {
    _hapticsOn = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kHaptics, v);
  }

  /// Android's own backup of the app's data (developer, 2026-11-08): off by
  /// default. On, to Google only when Android encrypts it end to end; off,
  /// nor a phone-to-phone transfer. AppBackupAgent.kt decides.
  bool _androidBackup = false;
  bool get androidBackup => _androidBackup;

  Future<void> setAndroidBackup(bool v) async {
    _androidBackup = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(kAndroidBackup, v);
  }

  Future<void> setQuickZeros(bool v) async {
    _quickZeros = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kQuickZeros, v);
  }

  Future<void> setSuggestionsOn(bool v) async {
    _suggestionsOn = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSuggestionsOn, v);
  }

  // ---- Settings > History: what the app remembers (all on by default;
  // the owner, 2026-10-26) ----
  bool _rememberSections = true;
  bool _rememberScroll = true;
  bool _rememberEntries = true;
  Map<String, bool> _sectionsOpen = const {};
  Map<String, double> _scroll = const {};

  /// Sections stay open / closed as left, even after a restart (off: each
  /// run starts from their defaults).
  bool get rememberSections => _rememberSections;

  /// Lists and pages come back where they were scrolled to, even after a
  /// restart.
  bool get rememberScroll => _rememberScroll;

  /// A cancelled add sheet keeps what was entered for next time (until the
  /// app restarts; [SheetDrafts]).
  bool get rememberEntries => _rememberEntries;

  /// A due payment marked paid is also recorded in History (its sheet's
  /// Record box, as last left; on at first).
  bool get recordDuePaid => _recordDuePaid;
  bool _recordDuePaid = true;

  Future<void> setRecordDuePaid(bool v) async {
    _recordDuePaid = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kRecordDuePaid, v);
  }

  /// What the backup box was last told (the owner, 2026-10-28: asked once, not
  /// every time): full data (else expenses only) and Excel (else JSON); null
  /// until the first backup.
  bool? get backupFull => _backupFull;
  bool? get backupExcel => _backupExcel;
  bool? _backupFull, _backupExcel;

  Future<void> setBackupChoice({
    required bool full,
    required bool excel,
  }) async {
    _backupFull = full;
    _backupExcel = excel;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBackupFull, full);
    await sp.setBool(_kBackupExcel, excel);
  }

  /// Whether section [id] was left open (null: never saved).
  bool? sectionOpen(String id) => _rememberSections ? _sectionsOpen[id] : null;

  /// Where scrollable [id] was left (0 if not remembered).
  double scrollOffset(String id) => _rememberScroll ? (_scroll[id] ?? 0) : 0;

  Future<void> setRememberSections(bool v) async {
    _rememberSections = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kRememberSections, v);
    // Off: the saved states go (the next run starts from the defaults).
    if (!v) {
      for (final k in sp.getKeys().where(
        (k) => k.startsWith(_kSectionOpenPrefix),
      )) {
        await sp.remove(k);
      }
      _sectionsOpen = {};
    }
  }

  Future<void> setRememberScroll(bool v) async {
    _rememberScroll = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kRememberScroll, v);
    if (!v) {
      for (final k in sp.getKeys().where((k) => k.startsWith(_kScrollPrefix))) {
        await sp.remove(k);
      }
      _scroll = {};
    }
  }

  Future<void> setRememberEntries(bool v) async {
    _rememberEntries = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kRememberEntries, v);
  }

  /// Saves section [id]'s state (only while sections are remembered; no
  /// rebuild needed: the section shows it already).
  Future<void> saveSectionOpen(String id, bool open) async {
    if (!_rememberSections) return;
    _sectionsOpen = {..._sectionsOpen, id: open};
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('$_kSectionOpenPrefix$id', open);
  }

  // ---- The order of a date's parts ----
  DateOrder get dateOrder => appDateOrder;

  Future<void> setDateOrder(DateOrder v) async {
    if (appDateOrder == v) return;
    appDateOrder = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDateOrder, v.name);
  }

  // ---- Digits: what was picked, in Persian; in English always English ----
  DigitStyle _digitChoice = DigitStyle.english;

  /// The digits in effect.
  DigitStyle get digitStyle => appDigitStyle;

  void _applyDigits() => appDigitStyle = _locale.languageCode == 'fa'
      ? _digitChoice
      : DigitStyle.english;

  Future<void> setDigitStyle(DigitStyle v) async {
    if (_digitChoice == v) return;
    _digitChoice = v;
    _applyDigits();
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDigits, v.name);
  }

  // ---- Tips: off until turned on (first page, Personalization) ----
  bool _tipsOn = false;
  Set<String> _tipsSeen = const {};

  bool get tipsOn => _tipsOn;
  bool tipSeen(String id) => _tipsSeen.contains(id);

  /// Turned on, every tip shows again (each once, where it's about), and so
  /// does all else that teaches and then stops: the scrolling boxes' hints
  /// and what was told "never show again" (the owner, 2026-11-04).
  Future<void> setTipsOn(bool v) async {
    _tipsOn = v;
    if (v) {
      _tipsSeen = {};
      _scrollLearned = {};
      _neverShown = {};
    }
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kTipsOn, v);
    if (v) {
      await sp.remove(_kTipsSeen);
      await sp.remove(_kScrollLearned);
      await sp.remove(_kNeverShown);
    }
  }

  /// What was told "never show again" (the date picker's warnings).
  Set<String> _neverShown = const {};
  bool neverShown(String id) => _neverShown.contains(id);

  Future<void> markNeverShown(String id) async {
    if (_neverShown.contains(id)) return;
    _neverShown = {..._neverShown, id};
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kNeverShown, _neverShown.toList());
  }

  /// Statistics' daily chart: the series turned off by their chips (kept
  /// as left; both averages start off: [kChartLinesOffAtFirst]).
  Set<String> _dailyHidden = kChartLinesOffAtFirst;
  Set<String> get dailyHidden => _dailyHidden;

  /// Heard by nothing (the chart keeps its own state).
  Future<void> setDailyHidden(Set<String> ids) async {
    _dailyHidden = Set.unmodifiable(ids);
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kDailyHidden, ids.toList());
  }

  /// Statistics' pace chart: the series turned off by their chips (kept as
  /// left; both averages start off: [kChartLinesOffAtFirst]).
  Set<String> _paceHidden = kChartLinesOffAtFirst;
  Set<String> get paceHidden => _paceHidden;

  /// Heard by nothing (the chart keeps its own state).
  Future<void> setPaceHidden(Set<String> ids) async {
    _paceHidden = Set.unmodifiable(ids);
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kPaceHidden, ids.toList());
  }

  /// The kinds of scrolling boxes the user has scrolled by hand (a chips
  /// box, the suggestions row...): theirs no longer show that they scroll
  /// ([ScrollHint]). Kept in prefs, so in full backups.
  Set<String> _scrollLearned = const {};
  bool scrollLearned(String id) => _scrollLearned.contains(id);

  /// Heard by nothing (the hints ask when they'd show).
  Future<void> markScrollLearned(String id) async {
    if (_scrollLearned.contains(id)) return;
    _scrollLearned = {..._scrollLearned, id};
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kScrollLearned, _scrollLearned.toList());
  }

  Future<void> markTipSeen(String id) async {
    if (_tipsSeen.contains(id)) return;
    _tipsSeen = {..._tipsSeen, id};
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kTipsSeen, _tipsSeen.toList());
  }

  // ---- Settings > Backup: where backups are saved ----
  String? _backupFolder;
  String? _backupFolderName;

  /// The folder picked for backups (a content URI) and its name; null:
  /// Download, the default.
  String? get backupFolder => _backupFolder;
  String? get backupFolderName => _backupFolderName;

  /// Backups go to [uri] (named [name]); null: back to Download.
  Future<void> setBackupFolder(String? uri, String? name) async {
    _backupFolder = uri;
    _backupFolderName = uri == null ? null : name;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    if (uri == null) {
      await sp.remove(kBackupFolderPrefsKey);
      await sp.remove(kBackupFolderNamePrefsKey);
    } else {
      await sp.setString(kBackupFolderPrefsKey, uri);
      await sp.setString(kBackupFolderNamePrefsKey, name ?? '');
    }
  }

  /// Saves where scrollable [id] is (only while scroll spots are
  /// remembered).
  Future<void> saveScrollOffset(String id, double offset) async {
    if (!_rememberScroll) return;
    _scroll = {..._scroll, id: offset};
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('$_kScrollPrefix$id', offset);
  }

  // Title suggestions: each list of suggestions has its own ignore list.
  Map<SuggestSource, List<String>> _ignored = const {};
  Set<String> _noSuggestCats = const {};

  /// Ignored suggestions of [source], most recently ignored first.
  List<String> ignoredTitles(SuggestSource source) =>
      _ignored[source] ?? const [];

  /// Categories whose titles aren't suggested.
  Set<String> get noSuggestCategories => _noSuggestCats;

  bool isTitleIgnored(SuggestSource source, String title) {
    final list = ignoredTitles(source);
    if (list.isEmpty) return false;
    // Each ignore list's keys, made once per version of the list.
    final had = _ignoredKeys[source];
    final keys = had != null && identical(had.$1, list)
        ? had.$2
        : (_ignoredKeys[source] = (
            list,
            {for (final t in list) _titleKey(t)},
          )).$2;
    return keys.contains(_titleKey(title));
  }

  final Map<SuggestSource, (List<String>, Set<String>)> _ignoredKeys = {};

  static final _spaces = RegExp(r'\s+');

  static String _titleKey(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ')
      .replaceAll(_spaces, ' ');

  static String _ignoredKey(SuggestSource s) => 'ignoredTitles.${s.name}';

  Future<void> _setIgnored(SuggestSource source, List<String> list) async {
    _ignored = {..._ignored, source: list};
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_ignoredKey(source), list);
  }

  Future<void> ignoreTitle(SuggestSource source, String title) async {
    if (title.trim().isEmpty || isTitleIgnored(source, title)) return;
    await _setIgnored(source, [title.trim(), ...ignoredTitles(source)]);
  }

  Future<void> unignoreTitle(SuggestSource source, String title) async {
    final k = _titleKey(title);
    await _setIgnored(source, [
      for (final t in ignoredTitles(source))
        if (_titleKey(t) != k) t,
    ]);
  }

  Future<void> setCategorySuggests(String gid, bool suggest) async {
    _noSuggestCats = {
      ..._noSuggestCats.where((g) => g != gid),
      if (!suggest) gid,
    };
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kNoSuggestCats, _noSuggestCats.toList());
  }

  /// Older ignore lists, folded into the current ones (also when a backup
  /// made before them is restored): the single list applied to entry and
  /// upcoming titles; upcoming titles are expense titles now; debt titles
  /// and people were one list for both sides.
  Future<void> _migrateIgnored(SharedPreferences sp) async {
    const old = {
      _kIgnoredTitlesLegacy: [SuggestSource.expense, SuggestSource.income],
      'ignoredTitles.upcoming': [SuggestSource.expense],
      'ignoredTitles.debt': [SuggestSource.oweTitle, SuggestSource.owedTitle],
      'ignoredTitles.people': [
        SuggestSource.owePerson,
        SuggestSource.owedPerson,
      ],
    };
    var changed = false;
    for (final MapEntry(key: key, value: targets) in old.entries) {
      final list = sp.getStringList(key);
      if (list == null) continue;
      for (final src in targets) {
        final merged = [...?_ignored[src]];
        for (final t in list) {
          final k = _titleKey(t);
          if (!merged.any((m) => _titleKey(m) == k)) merged.add(t);
        }
        _ignored = {..._ignored, src: merged};
        await sp.setStringList(_ignoredKey(src), merged);
      }
      await sp.remove(key);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // Biometric timing helper
  DateTime? _lastBiometricAuthAt;
  DateTime? get lastBiometricAuthAt => _lastBiometricAuthAt;

  // Global period offset for date range (not persisted, resets on restart)
  int _periodOffset = 0;
  int get periodOffset => _periodOffset;

  SettingsProvider() {
    ready = _load(); // async; defaults apply until loaded
  }

  /// Done loading the saved settings (main awaits it before the first
  /// frame, so pages start with them: fonts, remembered scroll spots, …).
  late final Future<void> ready;

  // ---------- tolerant reads + migrations for legacy values (helpers) ----------

  int? _readIntFlexible(SharedPreferences sp, String key) {
    final v = sp.get(key);
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is bool) return v ? 1 : 0;
    return null;
  }

  Future<void> _migrateInt(SharedPreferences sp, String key, int value) async {
    await sp.remove(key);
    await sp.setInt(key, value);
  }

  bool _readBoolFlexible(SharedPreferences sp, String key) {
    final v = sp.get(key);
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' ||
          s == '1' ||
          s == 'yes' ||
          s == 'y' ||
          s == 'on' ||
          s == 'enabled';
    }
    return false;
  }

  Future<void> _migrateBool(
    SharedPreferences sp,
    String key,
    bool value,
  ) async {
    await sp.remove(key);
    await sp.setBool(key, value);
  }

  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();

    // Locale
    final lc = sp.getString(_kLocale);
    if (lc == 'fa' || lc == 'en') {
      _locale = Locale(lc!);
    }

    // Font (default: the app's font)
    bool appFont(String key) {
      final v = sp.get(key);
      return v is bool ? v : (v is String ? v != 'false' : true);
    }

    _appFontFa = appFont(_kAppFontFa);
    _appFontEn = appFont(_kAppFontEn);

    // Home tabs (default: off)
    _tabUpcoming = sp.get(_kTabUpcoming) == true;
    _tabDebts = sp.get(_kTabDebts) == true;
    _tabSms = sp.get(_kTabSms) == true;
    _bankNotify = sp.get(_kBankNotify) == true;
    _suggestionsOn = sp.get(_kSuggestionsOn) == true;
    final zeros = sp.get(_kQuickZeros);
    _quickZeros = zeros is bool ? zeros : null;
    final haptics = sp.get(_kHaptics);
    _hapticsOn = haptics is bool ? haptics : true;
    _androidBackup = sp.get(kAndroidBackup) == true; // default: off
    _rememberSections = sp.get(_kRememberSections) != false; // default: on
    _rememberScroll = sp.get(_kRememberScroll) != false; // default: on
    _rememberEntries = sp.get(_kRememberEntries) != false; // default: on
    _recordDuePaid = sp.get(_kRecordDuePaid) != false; // default: on
    final bf = sp.get(_kBackupFull), be = sp.get(_kBackupExcel);
    _backupFull = bf is bool ? bf : null;
    _backupExcel = be is bool ? be : null;
    _tipsOn = sp.get(_kTipsOn) == true;
    final digits = sp.get(_kDigits);
    _digitChoice = DigitStyle.values.firstWhere(
      (d) => d.name == digits,
      orElse: () => DigitStyle.english,
    );
    _applyDigits();
    final order = sp.get(_kDateOrder);
    appDateOrder = DateOrder.values.firstWhere(
      (o) => o.name == order,
      orElse: () => DateOrder.standard,
    );
    final never = sp.get(_kNeverShown);
    _neverShown = never is List ? {for (final s in never) '$s'} : {};
    final seen = sp.get(_kTipsSeen);
    _tipsSeen = seen is List ? {for (final s in seen) '$s'} : {};
    final learned = sp.get(_kScrollLearned);
    _scrollLearned = learned is List ? {for (final s in learned) '$s'} : {};
    final paceHidden = sp.get(_kPaceHidden);
    _paceHidden = paceHidden is List
        ? {for (final s in paceHidden) '$s'}
        : kChartLinesOffAtFirst;
    final hidden = sp.get(_kDailyHidden);
    _dailyHidden = hidden is List
        ? {for (final s in hidden) '$s'}
        : kChartLinesOffAtFirst;
    final folder = sp.get(kBackupFolderPrefsKey);
    _backupFolder = folder is String && folder.isNotEmpty ? folder : null;
    final folderName = sp.get(kBackupFolderNamePrefsKey);
    _backupFolderName = _backupFolder != null && folderName is String
        ? folderName
        : null;
    _sectionsOpen = {
      for (final k in sp.getKeys())
        if (k.startsWith(_kSectionOpenPrefix) && sp.get(k) is bool)
          k.substring(_kSectionOpenPrefix.length): sp.getBool(k)!,
    };
    _scroll = {
      for (final k in sp.getKeys())
        if (k.startsWith(_kScrollPrefix) && sp.get(k) is double)
          k.substring(_kScrollPrefix.length): sp.getDouble(k)!,
    };
    // One ignore list per suggestion source.
    _ignored = {
      for (final src in SuggestSource.values)
        src: sp.getStringList(_ignoredKey(src)) ?? const [],
    };
    await _migrateIgnored(sp);
    _noSuggestCats = (sp.getStringList(_kNoSuggestCats) ?? const []).toSet();

    // Calendar
    final cal = sp.getString(_kCalendar);
    _calendar = (cal == 'gregorian')
        ? AppCalendar.gregorian
        : AppCalendar.jalali;

    // Start day (tolerant read + migrate)
    final sd = _readIntFlexible(sp, _kStartDay);
    if (sd != null) {
      final clamped = sd.clamp(1, 28);
      _startDay = clamped;
      if (sp.get(_kStartDay) is! int) {
        await _migrateInt(sp, _kStartDay, clamped);
      }
    }

    // Theme mode
    final tm = sp.getString(_kThemeMode);
    if (tm != null) {
      _themeMode =
          {
            'light': ThemeMode.light,
            'dark': ThemeMode.dark,
            'system': ThemeMode.system,
          }[tm] ??
          ThemeMode.system;
    }

    // Seed color (tolerant read + migrate; fallback to default)
    var colorInt = _readIntFlexible(sp, _kSeedColor);
    // Once: a build of 2026-10-22 made the brand green the theme color
    // (moving the default blue to it); back to the blue.
    if (sp.getBool(_kSeedBlueBack) != true) {
      if (colorInt == 0xFF22C55E) {
        colorInt = _defaultSeed.toARGB32();
        await sp.setInt(_kSeedColor, colorInt);
      }
      await sp.setBool(_kSeedBlueBack, true);
    }
    if (colorInt != null) {
      _seedColor = Color(colorInt);
      if (sp.get(_kSeedColor) is! int) {
        await _migrateInt(sp, _kSeedColor, colorInt);
      }
    } else {
      _seedColor = _defaultSeed;
    }

    // On-seed text (tolerant + migrate)
    _onSeedTextIsWhite = _readBoolFlexible(sp, _kOnSeedTextIsWhite);
    if (sp.get(_kOnSeedTextIsWhite) is! bool) {
      await _migrateBool(sp, _kOnSeedTextIsWhite, _onSeedTextIsWhite);
    }

    // Currency (string is fine; just default if missing)
    _currencyCode = sp.getString(_kCurrency) ?? _currencyCode;

    // Biometric (tolerant + migrate)
    _biometricEnabled = _readBoolFlexible(sp, _kBiometric);
    if (sp.get(_kBiometric) is! bool) {
      await _migrateBool(sp, _kBiometric, _biometricEnabled);
    }

    // Premium (tolerant + migrate)
    _isPremium = _readBoolFlexible(sp, _kPremium);
    if (sp.get(_kPremium) is! bool) {
      await _migrateBool(sp, _kPremium, _isPremium);
    }

    notifyListeners();
  }

  // ===== Setters (persist + notify) =====

  Future<void> setLocale(Locale loc) async {
    if (_locale == loc) return;
    _locale = loc;
    _applyDigits();
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocale, loc.languageCode); // 'fa' | 'en'
  }

  /// Sets the font choice for the current language.
  /// The app's font (true) or the device's for Persian ([fa]) or English
  /// text.
  Future<void> setAppFont({required bool fa, required bool v}) async {
    if (fa) {
      _appFontFa = v;
    } else {
      _appFontEn = v;
    }
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(fa ? _kAppFontFa : _kAppFontEn, v);
  }

  Future<void> setTabUpcoming(bool v) => _setTab(_kTabUpcoming, v);
  Future<void> setTabDebts(bool v) => _setTab(_kTabDebts, v);
  Future<void> setTabSms(bool v) => _setTab(_kTabSms, v);

  Future<void> setBankNotify(bool v) async {
    _bankNotify = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBankNotify, v);
  }

  Future<void> _setTab(String key, bool v) async {
    switch (key) {
      case _kTabUpcoming:
        _tabUpcoming = v;
      case _kTabDebts:
        _tabDebts = v;
      default:
        _tabSms = v;
    }
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, v);
  }

  Future<void> setCalendar(AppCalendar cal) async {
    if (_calendar == cal) return;
    _calendar = cal;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCalendar, cal.name); // 'jalali' | 'gregorian'
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kThemeMode, mode.name); // 'system'|'light'|'dark'
  }

  Future<void> setSeedColor(Color c) async {
    _seedColor = c;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    // If you don't have a toARGB32() extension, use `c.value` instead.
    await sp.setInt(_kSeedColor, c.toARGB32());
  }

  Future<void> setOnSeedTextIsWhite(bool v) async {
    _onSeedTextIsWhite = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kOnSeedTextIsWhite, v);
  }

  Future<void> setCurrency(String code) async {
    // A currency with another "000" default takes that default: the button
    // follows the currency (toman to euro turns it off), not an older choice
    // made for the other kind (developer, 2026-11-10).
    final reset = zerosByDefault(code) != zerosByDefault(_currencyCode);
    _currencyCode = code;
    if (reset) _quickZeros = null;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCurrency, code);
    if (reset) await sp.remove(_kQuickZeros);
  }

  Future<void> setBiometricEnabled(bool v) async {
    _biometricEnabled = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBiometric, v);
  }

  Future<void> setPremium(bool v) async {
    _isPremium = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kPremium, v);
  }

  Future<void> setStartDay(int day) async {
    final clamped = day.clamp(1, 28);
    _startDay = clamped;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kStartDay, clamped);
  }

  /// Call after a successful LocalAuth in Settings to prevent double-prompt.
  void markBiometricJustAuthed() {
    _lastBiometricAuthAt = DateTime.now();
    notifyListeners();
  }

  /// Set global period offset (used across all pages with date range controls).
  void setPeriodOffset(int offset) {
    if (_periodOffset == offset) return;
    _periodOffset = offset;
    notifyListeners();
  }
}

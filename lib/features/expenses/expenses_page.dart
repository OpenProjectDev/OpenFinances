import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/tab_swipe.dart';
import 'package:openfinances/shared/period_range.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/shared/ui/period_picker.dart';
import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart';
import 'package:openfinances/features/upcoming/upcoming_sheet.dart';
import 'package:openfinances/features/widgets/bare_app_bar.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;
import 'package:provider/provider.dart';
import 'package:openfinances/data/category_repository.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart'; // AppCalendar + startDay + currency
import 'package:openfinances/l10n/generated/app_localizations.dart'; // i18n
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/transaction_kind.dart';
import 'package:openfinances/features/expenses/day_strip.dart';
import 'package:openfinances/shared/ui/list_controls.dart';
import 'package:openfinances/shared/ui/segmented_pills.dart';
import 'package:openfinances/shared/ui/swipe_row.dart';
import 'package:openfinances/features/debts/debts_view.dart';
import 'package:openfinances/features/sms/sms_view.dart';
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/tips.dart';
import 'package:openfinances/shared/ui/tile_pill.dart';

enum _TypeFilter { all, expense, income }

/// Top-level tabs: the ledger (history), then the optional ones turned on in
/// Settings: planned payments, debts, bank SMS.
enum _PageTab { history, incoming, debts, sms }

/// History's calendar (the owner, 2026-10-31): folded away (the today
/// chip's square), the whole period, or one week once a day is gone to.
enum _Cal { closed, full, strip }

/// The sheet the bottom bar's "+" opens on this page right now (the bar's
/// plus tilts when it changes; History and SMS add an entry, whichever side
/// is preset).
final ValueNotifier<AddSheet> expensesAdds = ValueNotifier(AddSheet.entry);

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, this.bindOpenAdd, this.initialCategory});
  final void Function(VoidCallback openAdd)? bindOpenAdd;
  final String? initialCategory;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage>
    with SingleTickerProviderStateMixin {
  /// What History's tips are about, each when it's there: the first row after
  /// the very first entry, the chips row when there's one (the owner,
  /// 2026-11-04).
  final _tipPeriod = GlobalKey();
  final _tipExpenseCard = GlobalKey();
  final _tipIncomeCard = GlobalKey();
  final _tipTile = GlobalKey();
  final _tipChip = GlobalKey();

  List<Tip> _historyTips() => [
    Tip('history.welcome', const [], (l) => l.tipWelcome),
    Tip('history.period', [_tipPeriod], (l) => l.tipPeriod),
    Tip('history.cards', [_tipExpenseCard, _tipIncomeCard], (l) => l.tipCards),
    Tip('add', [AppBottomBar.addTipKey], (l) => l.tipAdd, overBar: true),
    Tip('history.tiles', [_tipTile], (l) => l.tipTiles),
    Tip('history.chips', [_tipChip], (l) => l.tipChips),
  ];

  // ==== Config ====
  static const int kMinOffset = -240;

  /// Between the last entry of a day and the first of the next (tiles of
  /// one day are 8 apart).
  static const double kDayGap = 20;
  static const int kMaxOffset = 0;
  static const double kGutter = 12;
  static const double kRowRadius = 14;

  String? _selectedCat;
  bool _sortByAmount = false; // false = by date, true = by amount
  /// The side picked (a tile or All tapped); null: none picked in this
  /// range, so the default ([_shownFilter]).
  _TypeFilter? _typeFilter;

  /// The side shown in the last build: the one picked, else by default
  /// both, or, when one side has nothing in the range, the other (as if
  /// its tile had been tapped).
  _TypeFilter _shownFilter = _TypeFilter.all;

  /// The side shown by default in the last build's range: both, or the
  /// only side with entries.
  _TypeFilter _defaultFilter = _TypeFilter.all;

  /// The range the default was taken for (a new range takes it afresh).
  String? _rangeKey;
  _PageTab _tab = _PageTab.history;

  /// History's list (today's date chip scrolls it back to the top); where
  /// it was left, while "keep place" is on.
  late final RememberedScroll _list;

  // ===== Language-based digits (for money/other non-date numbers) =====
  bool get _isFa => isFaUi(context);
  String _digits(String s) => faDigitsFor(_isFa) ? toFaDigits(s) : s;

  // Income total tile background (white text on it in both themes).
  static const Color _incomeTileGreen = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _list = RememberedScroll('history', _settings)
      ..addListener(_checkTodayAfterLayout)
      ..addListener(_followList);
    // Set initial category if provided
    _selectedCat = widget.initialCategory;
    if (_selectedCat != null) _typeFilter = _TypeFilter.expense;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.bindOpenAdd?.call(_openAddSheet);
    });
    _periodShown = _settings.periodOffset;
    _settings.addListener(_periodChanged);
    smsOpenRequest.addListener(_showSms);
    mainTabReselected.addListener(_backToHistory);
    expensesSubTabRequest.addListener(_restoreTab);
    historyFocusRequest.addListener(_focusRequested);
    // Asked before this page was made (a fresh one, after a category).
    if (historyFocusRequest.value != null) _focusRequested();
  }

  late final SettingsProvider _settings;
  late int _periodShown;

  /// Another period: its list from the top (the same offset would land in
  /// the middle of other days' rows: the owner, 2026-11-01). Before anything
  /// is built for it, so it shows in the same frame.
  void _periodChanged() {
    if (_settings.periodOffset == _periodShown) return;
    _periodShown = _settings.periodOffset;
    if (_list.hasClients) _list.jumpTo(_list.position.minScrollExtent);
  }

  /// Switches the sub-tab; the one left is remembered for Back.
  void _goTab(_PageTab t, {bool record = true}) {
    if (t == _tab) return;
    if (record && mainTab.value == 0) recordNavStop(NavStop(0, _tab.name));
    // Another tab: its sections as they start ("keep folds" off), its
    // lists at their tops ("keep place" off).
    final settings = context.read<SettingsProvider>();
    FoldSection.resetUnlessKept(settings);
    RememberedScroll.toTopUnlessKept(settings);
    setState(() => _tab = t);
    expensesSubTab = t.name;
  }

  /// Back brought us to one of our sub-tabs.
  void _restoreTab() {
    final name = expensesSubTabRequest.value;
    if (name == null || !mounted) return;
    expensesSubTabRequest.value = null;
    final t = _PageTab.values.where((x) => x.name == name).firstOrNull;
    if (t != null) _goTab(t, record: false);
  }

  @override
  void dispose() {
    _settings.removeListener(_periodChanged);
    smsOpenRequest.removeListener(_showSms);
    mainTabReselected.removeListener(_backToHistory);
    expensesSubTabRequest.removeListener(_restoreTab);
    historyFocusRequest.removeListener(_focusRequested);
    _list.dispose();
    _calOpen.dispose();
    _calOpenCurve.dispose();
    _calDay.dispose();
    _flash.dispose();
    _todayScrolledAway.dispose();
    super.dispose();
  }

  /// The home icon tapped while this page shows: one step back toward the
  /// start per tap, the first that applies (the owner's order, 2026-10-26):
  /// 1. another sub-tab → History (Back returns to it);
  /// 2. History scrolled → its top;
  /// 3. History on a category → the same side without it (the owner,
  ///    2026-10-28: it went straight to All, skipping a step);
  /// 4. History on a side → its default (All, or the only side with
  ///    entries in the range);
  /// 5. History on another period → this one (what the today chip does).
  void _backToHistory() {
    if (mainTab.value != 0 || !mounted) return;
    if (_tab != _PageTab.history) {
      _goTab(_PageTab.history);
    } else if (_list.hasClients && _list.offset > 0) {
      scrollToTop(_list);
    } else if (_selectedCat != null) {
      setState(() {
        _selectedCat = null;
        // Already on the default side: nothing left picked.
        if (_shownFilter == _defaultFilter) _typeFilter = null;
      });
    } else if (_shownFilter != _defaultFilter) {
      setState(() => _typeFilter = null);
    } else if (context.read<SettingsProvider>().periodOffset != 0) {
      _jumpToPeriod(0);
    } else if (_cal == _Cal.full) {
      // Last of all: the calendar folds, then closes (the owner, 2026-11-02).
      setState(() {
        _calWhole = false;
        _cal = _Cal.strip;
      });
    } else if (_cal == _Cal.strip) {
      _toggleCalendar();
    }
  }

  /// Something asked for the SMS tab (the tab picks up the filter itself).
  void _showSms() {
    if (smsOpenRequest.value != null && mounted) _goTab(_PageTab.sms);
  }

  @override
  void didUpdateWidget(covariant ExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bindOpenAdd != widget.bindOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.bindOpenAdd?.call(_openAddSheet);
      });
    }
  }

  /// A row's category chip: History filtered to that category, from the top
  /// (the owner, 2026-11-02).
  void _showCategory(String gid, {required bool income}) {
    if (_list.hasClients) _list.jumpTo(_list.position.minScrollExtent);
    setState(() {
      _typeFilter = income ? _TypeFilter.income : _TypeFilter.expense;
      _selectedCat = gid;
    });
  }

  void _setTypeFilter(_TypeFilter f) {
    if (f == _shownFilter && _typeFilter != null) return;
    setState(() {
      _typeFilter = f;
      _selectedCat = null; // expense/income categories are different taxonomies
    });
  }

  // Returns a readable foreground color (black/white) for a given background.
  Color _onColor(Color bg) => onColor(bg);

  // Safely convert dynamic color (int / String / Color) to Color.
  Color? _asColor(dynamic v) {
    if (v == null) return null;
    if (v is Color) return v;
    if (v is int) return Color(v);
    if (v is String) {
      var s = v.trim().toUpperCase();
      if (s.startsWith('0X')) s = s.substring(2);
      if (s.startsWith('#')) s = s.substring(1);
      if (s.length == 6) s = 'FF$s'; // add opaque alpha if missing
      final n = int.tryParse(s, radix: 16);
      if (n != null) return Color(n);
    }
    return null;
  }

  Color? _colorForCategory(String? gid, List<CategoryDto> categories) {
    if (gid == null) return null;
    // Looked up and parsed once per version of the categories (rows ask
    // for it on every build).
    if (_colorMaps.length > 4) _colorMaps.clear();
    final colors = _colorMaps[categories] ??= {
      for (final c in categories) c.gid: _asColor(c.color),
    };
    return colors[gid];
  }

  final Map<List<CategoryDto>, Map<String, Color?>> _colorMaps = Map.identity();

  List<CategoryDto> _categoriesForKind(
    TransactionKind kind,
    ExpenseProvider ep,
    IncomeProvider ip,
  ) => kind == TransactionKind.expense ? ep.categories : ip.categories;

  String _categoryNameForKind(
    TransactionKind kind,
    String? gid,
    ExpenseProvider ep,
    IncomeProvider ip,
  ) => kind == TransactionKind.expense
      ? ep.categoryName(gid)
      : ip.categoryName(gid);

  String _ensureGid(Map<String, dynamic> e) {
    final raw = e['gid'] ?? e['_id'];
    if (raw != null && raw.toString().isNotEmpty) return raw.toString();

    final dt = e['occurredAtUtc'];
    if (dt is DateTime) {
      return 'local_${dt.millisecondsSinceEpoch}_${e.hashCode}';
    }
    return 'local_${DateTime.now().millisecondsSinceEpoch}_${e.hashCode}';
  }

  // ===== Day key + title (Jalali/Gregorian) =====
  String _dayKeyForCalendar(DateTime dt, AppCalendar cal) {
    if (cal == AppCalendar.jalali) {
      final j = s.Jalali.fromDateTime(dt);
      return '${j.year.toString().padLeft(4, '0')}-${j.month.toString().padLeft(2, '0')}-${j.day.toString().padLeft(2, '0')}';
    } else {
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }

  String _dayTitleForCalendar(DateTime dt, SettingsProvider sp) =>
      dayTitle(dt, sp.calendar, _isFa);

  // ===== Range calculations (month rolling windows) =====
  String _rangeLabelOf(int offset, int startDay, SettingsProvider sp) {
    if (sp.calendar == AppCalendar.jalali) {
      final (js, je) = jalaliPeriod(offset, startDay);
      return rangeText(js.toDateTime(), je.toDateTime(), sp.calendar, _isFa);
    }
    final (gs, ge) = gregorianPeriod(offset, startDay);
    return rangeText(gs, ge, sp.calendar, _isFa);
  }

  /// Results worked out in build, kept while what they came from is the
  /// same (lists by identity, the rest by value).
  final Map<String, (List<Object?>, Object?)> _memos = {};

  T _memo<T>(String name, List<Object?> from, T Function() work) {
    final had = _memos[name];
    if (had != null && _sameInputs(had.$1, from)) return had.$2 as T;
    final v = work();
    _memos[name] = (from, v);
    return v;
  }

  static bool _sameInputs(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x is List || y is List ? !identical(x, y) : x != y) return false;
    }
    return true;
  }

  /// The period shown: its first moment and its last (local time).
  (DateTime, DateTime) _currentRange(int startDay, SettingsProvider sp) =>
      _rangeAt(sp.periodOffset, startDay, sp);

  /// The period [offset] periods from this one: its first moment and its
  /// last (local time).
  (DateTime, DateTime) _rangeAt(int offset, int startDay, SettingsProvider sp) {
    const lastSecond = Duration(hours: 23, minutes: 59, seconds: 59);
    if (sp.calendar == AppCalendar.jalali) {
      final (start, end) = jalaliPeriod(offset, startDay);
      return (start.toDateTime(), end.toDateTime().add(lastSecond));
    }
    final (start, end) = gregorianPeriod(offset, startDay);
    return (start, end.add(lastSecond));
  }

  /// Today's place in History's list: the last row of the newest day up to
  /// today (date sort), else the first row. Wholly out of view, the today
  /// chip lights up.
  final _todayAnchor = GlobalKey();
  int _todayAnchorAt = -1;

  /// History's calendar: how open it is, and the day gone to (framed there;
  /// the list's rows aren't lit). The day is heard by the calendar alone:
  /// the list moving it on as it scrolls doesn't build the page again.
  _Cal _cal = _Cal.closed;
  final _calDay = ValueNotifier<DateTime?>(null);

  /// The calendar opening (1) and closing (0); it stays built until it's
  /// closed, showing the view it closed from.
  late final _calOpen = AnimationController(vsync: this, duration: kSectionAnim)
    ..addStatusListener((s) {
      if (s == AnimationStatus.dismissed && mounted) setState(() {});
    });
  late final _calOpenCurve = CurvedAnimation(
    parent: _calOpen,
    curve: Curves.easeInOutCubic,
  );

  /// The view shown: whole (else the week); kept while it closes.
  bool _calWhole = true;

  void _toggleCalendar() => setState(() {
    if (_cal == _Cal.closed) {
      _cal = _Cal.full;
      _calWhole = true;
      _calOpen.forward();
      // Framed from the start: the day the list is at.
      _followList();
    } else {
      _cal = _Cal.closed;
      _calOpen.reverse();
    }
  });

  /// Each listed row's day (as the last build listed them).
  List<DateTime> _rowDays = const [];

  /// A day picked in the calendar: the strip shows it, the list (by date)
  /// scrolls to it.
  void _pickDay(DateTime day) {
    _calDay.value = day;
    setState(() {
      _cal = _Cal.strip;
      _calWhole = false;
      // By amount, a day has no place in the list.
      _sortByAmount = false;
    });
    _goToDay(day);
  }

  /// The list moving by itself to a picked day: the calendar doesn't follow
  /// its passing rows.
  bool _goingToDay = false;

  /// Each built row's context, by its index (to find the one at the line).
  final Map<int, BuildContext> _rowCtx = {};
  bool _followQueued = false;

  /// The room under the list's last row (it runs under the bottom bar).
  static const double _listEndPad = 88;

  /// Where the calendar reads the list (the owner, 2026-10-31): a line
  /// across it, [_lineTop] under its top until [_rampStart] (a day at the
  /// top keeps the frame until a little of the one before shows), from
  /// there running down to
  /// the last row by the end of the scroll. So every day that can come up
  /// to the top is read there when it's there, and the days after it (too
  /// short to come up) come under the line in turn over what's left of the
  /// scroll. Its y in the list (0: the top).
  double _readingLine(ScrollPosition p) {
    final from = _rampStart(p);
    final ramp = p.maxScrollExtent - from;
    if (ramp <= 0 || p.pixels <= from) return _lineTop;
    final shown = p.viewportDimension - _listEndPad;
    return _lineTop +
        (shown - _lineTop) * math.min(1.0, (p.pixels - from) / ramp);
  }

  static const double _lineTop = 14;

  /// Where the list goes for a day picked whose first row is at [top] (in
  /// the list's content): that row right at the top, under the calendar,
  /// or as near as the list goes (the owner, 2026-10-31: a day already as
  /// high as it gets was scrolled away from, to put the line on it). The
  /// frame stays on it ([_hold]) until the line reaches it.
  static double _offsetFor(ScrollPosition p, double top) =>
      top.clamp(p.minScrollExtent, p.maxScrollExtent);

  /// The day picked, framed while the line hasn't reached it yet: moving
  /// toward it keeps the frame there; away, or once it's reached, the
  /// frame follows the line again. And where the list was at the last look.
  DateTime? _hold;
  double _followFrom = 0;

  /// Less scroll than this left after a day's top, it's read as one that
  /// can't come up (a few pixels to run the line over the rest would make
  /// the frame jump at a touch).
  static const double _minRamp = 24;

  /// Where the line starts running down (a scroll offset): the top of the
  /// last day that can come up to the top (with [_minRamp] to spare), at
  /// most a screen before the end (inside a long day: its top is above).
  /// Worked out while the rows there are built, kept for the list as it is.
  double _rampStart(ScrollPosition p) {
    final max = p.maxScrollExtent;
    final shown = p.viewportDimension - _listEndPad;
    final floor = math.max(p.minScrollExtent, max - shown);
    final key = (max.round(), p.viewportDimension.round(), _rowDays);
    double? best, minTop, maxEnd;
    for (final i in _rowCtx.keys) {
      if (i >= _rowDays.length) continue;
      final span = _rowSpan(i);
      if (span == null) continue;
      final (t, h) = span;
      if (minTop == null || t < minTop) minTop = t;
      if (maxEnd == null || t + h > maxEnd) maxEnd = t + h;
      final first = i == 0 || _rowDays[i - 1] != _rowDays[i];
      if (first && t >= floor - .5 && t <= max - _minRamp) {
        if (best == null || t > best) best = t;
      }
    }
    // Every row from the floor to the end built: the answer's sure.
    if (minTop != null && maxEnd != null && minTop <= floor && maxEnd >= max) {
      _ramp = (key, best ?? floor);
    }
    final had = _ramp;
    if (had != null &&
        had.$1.$1 == key.$1 &&
        had.$1.$2 == key.$2 &&
        identical(had.$1.$3, key.$3)) {
      return had.$2;
    }
    return best ?? floor;
  }

  ((int, int, List<DateTime>), double)? _ramp;

  /// [index]'s row: where it stands in the list's content (its top) and
  /// how tall it is; null: not built.
  (double, double)? _rowSpan(int index) {
    final ctx = _rowCtx[index];
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    final view = Scrollable.maybeOf(ctx)?.context.findRenderObject();
    if (box == null || !box.attached || view is! RenderBox) return null;
    final y = box.localToGlobal(Offset.zero, ancestor: view).dy;
    return (_list.position.pixels + y, box.size.height);
  }

  /// The list scrolled (by hand, or back to today): the calendar follows the
  /// day at its reading line ([_readingLine]), its frame and its week.
  void _followList() {
    if (_followQueued || _goingToDay || _cal == _Cal.closed || _sortByAmount) {
      return;
    }
    _followQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followQueued = false;
      if (!mounted || _goingToDay || !_list.hasClients) return;
      final p = _list.position;
      final line = _readingLine(p);
      int? at, first;
      _rowCtx.removeWhere((_, c) => !c.mounted);
      for (final i in _rowCtx.keys) {
        final span = _rowSpan(i);
        if (span == null) continue;
        final top = span.$1 - p.pixels;
        // Rows showing: the last one starting above the line (the first
        // showing, when none does).
        if (top + span.$2 <= 1 || top >= p.viewportDimension) continue;
        if (top <= line + 1 && (at == null || i > at)) at = i;
        if (first == null || i < first) first = i;
      }
      at ??= first;
      if (at == null || at >= _rowDays.length) return;
      final day = _rowDays[at];
      final moved = p.pixels - _followFrom;
      _followFrom = p.pixels;
      final held = _hold;
      if (held != null && day != held) {
        final first = _rowDays.indexOf(held), last = _rowDays.lastIndexOf(held);
        // The line on its way to the day picked (below it, the list going
        // up; above it, down): the frame stays.
        if (first >= 0 && (at > last && moved < 0 || at < first && moved > 0)) {
          return;
        }
      }
      _hold = null;
      _calDay.value = day;
    });
  }

  /// Scrolls the list to [day] ([_offsetFor]), then [then] (its rows are
  /// built by then).
  Future<void> _goToDay(DateTime day, {Future<void> Function()? then}) async {
    _goingToDay = true;
    _hold = day;
    try {
      await _goToDayNow(day);
      await then?.call();
    } finally {
      _goingToDay = false;
      if (_list.hasClients) _followFrom = _list.position.pixels;
    }
  }

  /// Its first row built: eased there at once. Not built yet (far away):
  /// the list glides toward where it should be (by its rows' average
  /// height), then eases the rest, one movement (the owner, 2026-11-01: it
  /// jumped there in one frame, a flash); once there, a last look (the
  /// list's length was a guess until its end was built).
  Future<void> _goToDayNow(DateTime day) async {
    for (var tries = 0; tries < 8; tries++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_list.hasClients) return;
      final at = _rowDays.indexOf(day);
      if (at < 0) return;
      final p = _list.position;
      final first = _rowSpan(at);
      if (first != null) {
        final to = _offsetFor(p, first.$1);
        if ((to - p.pixels).abs() < 1) return;
        await _list.animateTo(
          to,
          duration: Duration(milliseconds: tries == 0 ? 360 : 220),
          curve: Curves.easeOutCubic,
        );
        continue;
      }
      final guess = _guessTop(at);
      if (guess == null) return;
      await _list.animateTo(
        guess.clamp(p.minScrollExtent, p.maxScrollExtent),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Where row [index] should start in the list's content, from the built
  /// row nearest it and their average height; null: none built.
  double? _guessTop(int index) {
    int? near;
    double? nearTop;
    var sum = 0.0;
    var n = 0;
    _rowCtx.removeWhere((_, c) => !c.mounted);
    for (final i in _rowCtx.keys) {
      final span = _rowSpan(i);
      if (span == null) continue;
      sum += span.$2;
      n++;
      if (near == null || (i - index).abs() < (near - index).abs()) {
        near = i;
        nearTop = span.$1;
      }
    }
    if (near == null || nearTop == null || n == 0) return null;
    return nearTop + (index - near) * (sum / n);
  }

  /// The entry lit a moment in the list (one asked for: [historyFocusRequest]).
  final _flash = ValueNotifier<String?>(null);

  /// Statistics asked for an entry: History on its day, by date, with both
  /// sides (or its own) and no category, the calendar folded to its week;
  /// the list goes to the day, then far enough to show the entry, and the
  /// entry lights up.
  void _focusRequested() {
    final r = historyFocusRequest.value;
    if (r == null || !mounted) return;
    historyFocusRequest.value = null;
    _goTab(_PageTab.history);
    _calDay.value = r.day;
    setState(() {
      _typeFilter = null;
      _selectedCat = null;
      _sortByAmount = false;
      _cal = _Cal.strip;
      _calWhole = false;
    });
    _calOpen.forward();
    _goToDay(
      r.day,
      then: () async {
        final at = _rowIds.indexOf(r.gid);
        final row = at < 0 ? null : _rowSpan(at);
        if (row != null && _list.hasClients) {
          final p = _list.position;
          final shown = p.viewportDimension - _listEndPad;
          final over = row.$1 + row.$2 - p.pixels - (shown - 8);
          if (over > 0) {
            await _list.animateTo(
              (p.pixels + over).clamp(p.minScrollExtent, p.maxScrollExtent),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          }
        }
        if (mounted) _flash.value = r.gid;
      },
    );
  }

  /// Each listed row's entry id (as the last build listed them).
  List<String> _rowIds = const [];

  /// The calendar under the today row: the whole period, or its strip.
  Widget _calendar(
    BuildContext context,
    SettingsProvider settings,
    List<Map<String, dynamic>> rows,
    _TypeFilter filter,
  ) {
    if (_cal == _Cal.closed && _calOpen.isDismissed) {
      return const SizedBox(width: double.infinity);
    }
    final scheme = Theme.of(context).colorScheme;
    final startDay = settings.startDay;
    // The period's days, each day's tone (what was spent, income when only
    // income is listed, of what's listed) and the days that can be gone to
    // (something listed): worked out again only when the list changes.
    final (first, end, values, pickable) = _memo(
      'calendar',
      [rows, filter, settings.periodOffset, startDay, settings.calendar],
      () {
        final (from, to) = settings.calendar == AppCalendar.jalali
            ? (() {
                final (js, je) = jalaliPeriod(settings.periodOffset, startDay);
                return (js.toDateTime(), je.toDateTime());
              })()
            : gregorianPeriod(settings.periodOffset, startDay);
        final toneKind = filter == _TypeFilter.income
            ? TransactionKind.income
            : TransactionKind.expense;
        final values = <DateTime, int>{};
        for (final e in rows) {
          if (e['kind'] != toneKind) continue;
          final d = (e['occurredAtUtc'] as DateTime).toLocal();
          values.update(
            DateTime(d.year, d.month, d.day),
            (v) => v + (e['amountMinor'] as int),
            ifAbsent: () => e['amountMinor'] as int,
          );
        }
        return (
          DateTime(from.year, from.month, from.day),
          DateTime(to.year, to.month, to.day),
          values,
          _rowDays.toSet(),
        );
      },
    );
    final fa = faDigitsFor(isFaUi(context));

    // Whole, a touch anywhere else folds it to its week (the owner,
    // 2026-11-01).
    return TapRegion(
      groupId: kHomeCalendarTapGroup,
      onTapOutside: (_) {
        if (_cal == _Cal.full && mounted) {
          setState(() {
            _calWhole = false;
            _cal = _Cal.strip;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            kSectionInset,
            kSectionInset,
            kSectionInset,
            0,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ValueListenableBuilder<DateTime?>(
            valueListenable: _calDay,
            builder: (context, day, _) => HistoryCalendar(
              from: first,
              to: end,
              values: values,
              pickable: pickable,
              selected: day != null && !day.isBefore(first) && !day.isAfter(end)
                  ? day
                  : null,
              onPick: _pickDay,
              whole: _calWhole,
              // Whole ⇄ the week (the day's, else today's).
              onToggle: () => setState(() {
                _calWhole = !_calWhole;
                _cal = _calWhole ? _Cal.full : _Cal.strip;
              }),
              calendar: settings.calendar,
              faDigits: fa,
              backdrop: scheme.surfaceContainerHigh,
            ),
          ),
        ),
      ),
    );
  }

  /// Today has scrolled out of view (the today chip says so).
  final _todayScrolledAway = ValueNotifier<bool>(false);

  bool _todayCheckQueued = false;

  /// Checks [_checkTodayInView] once this frame is laid out. A scroll
  /// notifies BEFORE layout, when the rows still stand where the last frame
  /// left them: measured then, the step that pushed today's row out still
  /// saw it a few pixels in view and nothing measured again, so the chip
  /// stayed off at the bottom one time and lit the next, and the next small
  /// move lit it for a frame (the owner's "flash", 2026-10-25).
  void _checkTodayAfterLayout() {
    if (_todayCheckQueued) return;
    _todayCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _todayCheckQueued = false;
      _checkTodayInView();
    });
  }

  /// Whether the anchor row is wholly above the list's top (call once laid
  /// out: [_checkTodayAfterLayout]).
  void _checkTodayInView() {
    if (!mounted) return;
    var away = false;
    if (_todayAnchorAt >= 0 && _list.hasClients && _list.offset > 0) {
      final row = _todayAnchor.currentContext;
      if (row == null || !row.mounted) {
        // Not built: scrolled far past it (it's near the top).
        away = true;
      } else {
        final box = row.findRenderObject() as RenderBox?;
        final view = Scrollable.maybeOf(row)?.context.findRenderObject();
        if (box != null && box.attached && view is RenderBox) {
          final bottom = box
              .localToGlobal(Offset(0, box.size.height), ancestor: view)
              .dy;
          away = bottom <= 0;
        }
      }
    }
    _todayScrolledAway.value = away;
  }

  /// Moves History to period [offset] by itself (not the user's arrows):
  /// the period bar flashes to show it moved.
  void _jumpToPeriod(int offset) {
    context.read<SettingsProvider>().setPeriodOffset(offset);
    periodJumped.value++;
  }

  /// The period (as an offset) of the newest entry, expense or income,
  /// from before the one shown; null when there's none.
  int? _lastEntryOffset(
    int startDay,
    SettingsProvider sp,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> incomes,
  ) {
    final (from, _) = _currentRange(startDay, sp);
    DateTime? last;
    for (final e in [...expenses, ...incomes]) {
      final t = (e['occurredAtUtc'] as DateTime).toLocal();
      if (t.isBefore(from) && (last == null || t.isAfter(last))) last = t;
    }
    if (last == null) return null;
    for (var k = sp.periodOffset - 1; k >= kMinOffset; k--) {
      if (!last.isBefore(_rangeAt(k, startDay, sp).$1)) return k;
    }
    return null; // older than the periods the bar reaches
  }

  // ==== Add / Edit Sheet ====

  /// The tab showing (as of the last build; a turned-off tab falls back to
  /// History).
  _PageTab _shownTab = _PageTab.history;

  /// The sub-tabs opened so far (kept built since).
  final Set<_PageTab> _openedTabs = {};

  /// The bottom bar's "+" on this page: adds what the tab shows (SMS has
  /// nothing of its own to add, so a new entry).
  void _openAddSheet() {
    switch (_shownTab) {
      case _PageTab.incoming:
        addUpcoming(context);
      case _PageTab.debts:
        addDebt(context);
      case _PageTab.history || _PageTab.sms:
        final kind = _shownFilter == _TypeFilter.income
            ? TransactionKind.income
            : TransactionKind.expense;
        showAddEditTransactionSheet(context: context, kind: kind);
    }
  }

  void _openEditSheet({
    required Map<String, dynamic> existing,
    required TransactionKind kind,
    BuildContext? hostCtx,
  }) {
    showAddEditTransactionSheet(
      context: hostCtx ?? context,
      existing: existing,
      kind: kind,
    );
  }

  // ==== Range Sheet: rolling list ====
  Future<void> _openRangeList() async {
    final l = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        final settings = sheetCtx.watch<SettingsProvider>();
        final startDay = settings.startDay;

        final textMain = cs.onSurface;
        final offsets = List<int>.generate(
          kMaxOffset - kMinOffset + 1,
          (i) => kMaxOffset - i,
        );

        return SheetPull(
          // A long list: pulled down at its top, the sheet closes.
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkText(
                    l.selectRange,
                    style: TextStyle(
                      fontSize: kSheetTitleSize,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: kSheetTitleGap),
                  SizedBox(
                    height: MediaQuery.sizeOf(sheetCtx).height * 0.415,
                    child: ListView.separated(
                      itemCount: offsets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final off = offsets[i];
                        final selected = off == settings.periodOffset;
                        return OutlinedButton(
                          onPressed: () {
                            settings.setPeriodOffset(off);
                            Navigator.pop(sheetCtx);
                          },
                          style: OutlinedButton.styleFrom(
                            overlayColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: selected
                                ? cs.primary.withValues(alpha: .18)
                                : cs.surfaceContainerHigh,
                            foregroundColor: textMain,
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Directionality(
                              textDirection:
                                  settings.calendar == AppCalendar.jalali
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: InkText(
                                _rangeLabelOf(off, startDay, settings),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? context.primaryInk
                                      : textMain,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: InkText(l.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==== Range button — chip-like tonal button ====
  Widget _rangeControl(BuildContext context, int startDay) {
    final l = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final periodOffset = settings.periodOffset;
    final canPrev = periodOffset > kMinOffset;
    final canNext = periodOffset < kMaxOffset;

    return PeriodPicker(
      label: _rangeLabelOf(periodOffset, startDay, settings),
      labelDirection: uiTextDirection(_isFa),
      canPrev: canPrev,
      canNext: canNext,
      onPrev: () => settings.setPeriodOffset(periodOffset - 1),
      onNext: () => settings.setPeriodOffset(periodOffset + 1),
      onOpenList: _openRangeList,
      prevTooltip: l.prevPeriod,
      nextTooltip: l.nextPeriod,
      flash: periodJumped,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final ep = context.watch<ExpenseProvider>();
    final ip = context.watch<IncomeProvider>();
    final settings = context
        .watch<SettingsProvider>(); // rebuild on any settings change
    final startDay = settings.startDay;

    final textMain = scheme.onSurface;

    // On the theme color: by the color itself (black on black was unreadable).
    final textStrong = context.textOnStrong;

    final isLoading = ep.isLoading || ip.isLoading;
    final error = ep.error ?? ip.error;

    // The range's entries of both ledgers, each tagged with its kind (never
    // netted: a combined chronological view), and their totals: worked out
    // again only when the data, the range or the day changes (this page
    // builds often: a tab tap, any settings change).
    final now = DateTime.now();
    final rangeData = _memo(
      'range',
      [
        ep.raw,
        ip.raw,
        settings.periodOffset,
        startDay,
        settings.calendar,
        now.year,
        now.month,
        now.day,
      ],
      () {
        final (from, to) = _currentRange(startDay, settings);
        bool inRange(Map<String, dynamic> e) {
          final t = (e['occurredAtUtc'] as DateTime).toLocal();
          return !t.isBefore(from) && !t.isAfter(to);
        }

        final list = <Map<String, dynamic>>[
          for (final e in ep.raw)
            if (inRange(e)) {...e, 'kind': TransactionKind.expense},
          for (final e in ip.raw)
            if (inRange(e)) {...e, 'kind': TransactionKind.income},
        ];
        var spent = 0, earned = 0;
        for (final e in list) {
          final a = e['amountMinor'] as int;
          if (e['kind'] == TransactionKind.expense) {
            spent += a;
          } else {
            earned += a;
          }
        }
        return (list, spent, earned);
      },
    );
    final filtered = rangeData.$1;

    // An entry's category: its own, or the fallback one when it has none
    // (as Budget counts it).
    String catOf(Map<String, dynamic> e) {
      final c = e['categoryGid'] as String?;
      if (c != null && c.isNotEmpty) return c;
      return e['kind'] == TransactionKind.income
          ? ip.fallbackCategoryGid
          : ep.fallbackCategoryGid;
    }

    final expenseTotal = rangeData.$2;
    final incomeTotal = rangeData.$3;

    // Both total tiles, tap one to see only that side (All back to both).
    // By default both show; when one side has nothing in the range, the
    // page starts as if the other side's tile had been tapped. A new range
    // takes its default afresh, unless a category is picked: it stays, and
    // so does its side (the owner, 2026-10-26: moving the period cleared it).
    final rangeKey =
        '${settings.periodOffset}|$startDay|${settings.calendar.name}';
    if (rangeKey != _rangeKey) {
      if (_rangeKey != null) {
        if (_selectedCat == null) {
          _typeFilter = null;
        } else {
          _typeFilter ??= _shownFilter;
        }
      }
      _rangeKey = rangeKey;
    }
    final defaultSide = incomeTotal == 0 && expenseTotal != 0
        ? _TypeFilter.expense
        : expenseTotal == 0 && incomeTotal != 0
        ? _TypeFilter.income
        : _TypeFilter.all;
    final filter = _typeFilter ?? defaultSide;
    _shownFilter = filter;
    _defaultFilter = defaultSide;
    // A tile tapped: that side from both, back to both from one.
    final VoidCallback? backToAll = filter == _TypeFilter.all
        ? null
        : () => _setTypeFilter(_TypeFilter.all);
    VoidCallback? tileTap(_TypeFilter side) =>
        filter == _TypeFilter.all ? () => _setTypeFilter(side) : backToAll;
    // The sub-tab shown, first: what the "+" opens follows it (worked out
    // from the last build's tab, it lagged a step behind).
    // Tabs turned on in Settings; with only History there's no tab row.
    final tabs = <_PageTab, String>{
      _PageTab.history: l.historyTab,
      if (settings.tabUpcoming) _PageTab.incoming: l.incomingTab,
      if (settings.tabDebts) _PageTab.debts: l.debtsTab,
      if (settings.tabSms) _PageTab.sms: l.smsTab,
    };
    final tab = tabs.containsKey(_tab) ? _tab : _PageTab.history;
    _shownTab = tab;
    _openedTabs.add(tab);

    // Tell the bar what its "+" opens now (after this frame: it rebuilds).
    final adds = switch (tab) {
      _PageTab.incoming => AddSheet.upcoming,
      _PageTab.debts => AddSheet.debt,
      _PageTab.history || _PageTab.sms => AddSheet.entry,
    };
    if (expensesAdds.value != adds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) expensesAdds.value = adds;
      });
    }
    // A category deleted meanwhile: no longer a filter.
    if (_selectedCat != null &&
        ![
          ...ep.categories,
          ...ip.categories,
        ].any((c) => c.gid == _selectedCat)) {
      _selectedCat = null;
    }

    final derived = _memo(
      'rows',
      [
        filtered,
        filter,
        _selectedCat,
        _sortByAmount,
        ep.categories,
        ip.categories,
        settings.calendar,
      ],
      () {
        final typeFiltered = switch (filter) {
          _TypeFilter.all => filtered,
          _TypeFilter.expense =>
            filtered
                .where((e) => e['kind'] == TransactionKind.expense)
                .toList(),
          _TypeFilter.income =>
            filtered.where((e) => e['kind'] == TransactionKind.income).toList(),
        };

        // Category chips only make sense once filtered to a single kind — an
        // expense category and an income category aren't comparable amounts
        // to rank together in one bar.
        final Map<String, int> catTotals = {};
        if (filter != _TypeFilter.all) {
          for (final e in typeFiltered) {
            final amount = e['amountMinor'] as int;
            catTotals.update(
              catOf(e),
              (v) => v + amount,
              ifAbsent: () => amount,
            );
          }
        }
        final activeCats = catTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final activeCatGids = activeCats.map((e) => e.key).toList();
        final filteredByCat = _selectedCat == null
            ? typeFiltered
            : typeFiltered.where((e) => catOf(e) == _selectedCat).toList();

        // One day's entries go in the order they were entered, the newest
        // first, as the days do (the owner, 2026-10-26: no longer by
        // category); equal amounts too.
        int newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
          final c = (b['createdAtUtc'] as DateTime).compareTo(
            a['createdAtUtc'] as DateTime,
          );
          return c != 0
              ? c
              : (b['occurredAtUtc'] as DateTime).compareTo(
                  a['occurredAtUtc'] as DateTime,
                );
        }

        // Group by day key appropriate to calendar
        final map = <String, List<Map<String, dynamic>>>{};
        late final List<MapEntry<String, List<Map<String, dynamic>>>> groups;

        if (_sortByAmount) {
          // When sorting by amount, don't group by day - show all in one group
          if (filteredByCat.isNotEmpty) {
            map['all'] = filteredByCat.toList()
              ..sort((a, b) {
                final amountA = (a['amountMinor'] as int?) ?? 0;
                final amountB = (b['amountMinor'] as int?) ?? 0;
                final c = amountB.compareTo(amountA); // Highest first
                return c != 0 ? c : newestFirst(a, b);
              });
            groups = [MapEntry('all', map['all']!)];
          } else {
            groups = [];
          }
        } else {
          // Normal grouping by day and sort by date
          for (final e in filteredByCat) {
            final dtLocal = (e['occurredAtUtc'] as DateTime).toLocal();
            final key = _dayKeyForCalendar(dtLocal, settings.calendar);
            (map[key] ??= []).add(e);
          }
          groups = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
          for (final e in groups) {
            e.value.sort(newestFirst);
          }
        }

        final rows = [for (final g in groups) ...g.value];
        final singleTotal = typeFiltered.fold<int>(
          0,
          (sum, e) => sum + (e['amountMinor'] as int),
        );
        return (catTotals, activeCatGids, groups, rows, singleTotal);
      },
    );
    final (catTotals, activeCatGids, groups, rows, singleTotal) = derived;
    // Each row's day, id, and whether a new day comes after it (a wider gap;
    // date sort only): once per list, not per row built.
    final (rowDays, rowIds, dayEnds) = _memo(
      'rowDays',
      [rows, _sortByAmount],
      () {
        final days = [
          for (final e in rows)
            () {
              final d = (e['occurredAtUtc'] as DateTime).toLocal();
              return DateTime(d.year, d.month, d.day);
            }(),
        ];
        return (
          days,
          [for (final e in rows) _ensureGid(e)],
          [
            for (var i = 0; i < days.length; i++)
              !_sortByAmount && i + 1 < days.length && days[i] != days[i + 1],
          ],
        );
      },
    );
    _rowDays = rowDays;
    _rowIds = rowIds;

    // Today's place in the list (see [_todayAnchor]): the last row of the
    // newest day up to today (today's, or, with nothing today yet, the last
    // day with entries; the owner, 2026-10-25), else the first row. Checked
    // once laid out.
    var anchor = rows.isEmpty ? -1 : 0;
    if (!_sortByAmount && settings.periodOffset == 0) {
      final today = _dayKeyForCalendar(DateTime.now(), settings.calendar);
      String? newest;
      for (var i = 0; i < rows.length; i++) {
        final day = _dayKeyForCalendar(
          (rows[i]['occurredAtUtc'] as DateTime).toLocal(),
          settings.calendar,
        );
        if (day.compareTo(today) > 0) continue; // dated ahead of today
        newest ??= day;
        if (day != newest) break; // newest first: that day's are all behind
        anchor = i;
      }
    }
    _todayAnchorAt = anchor;
    _checkTodayAfterLayout();
    final chipsCategories = filter == _TypeFilter.income
        ? ip.categories
        : ep.categories;

    void selectCat(String? cat) => setState(() => _selectedCat = cat);

    // The tab [step] places along the row (if there's one).
    void switchTab(int step) {
      final order = tabs.keys.toList();
      final at = order.indexOf(tab) + step;
      if (at >= 0 && at < order.length) _goTab(order[at]);
    }

    return Scaffold(
      appBar: bareAppBar(),
      // No inline text fields here; don't relayout under add-sheet keyboards.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if (tabs.length > 1)
            Padding(
              // As far from the top as from the sides.
              padding: const EdgeInsets.fromLTRB(kGutter, kGutter, kGutter, 8),
              child: SegmentedPills<_PageTab>(
                radius: 12,
                verticalPadding: 9,
                selected: tab,
                onChanged: _goTab,
                options: tabs,
              ),
            ),

          // Below the tab row: a sideways swipe moves between the tabs
          // (a row's own swipe and the chip rows come first).
          Expanded(
            child: TabSwipe(
              onNext: () => switchTab(1),
              onPrevious: () => switchTab(-1),
              // Each sub-tab once opened stays built (hidden ones paused):
              // switching back doesn't build it again from scratch.
              child: IndexedStack(
                index: tab.index,
                sizing: StackFit.expand,
                children: [
                  for (final t in _PageTab.values)
                    TickerMode(
                      enabled: t == tab,
                      child: !_openedTabs.contains(t) && t != tab
                          ? const SizedBox.shrink()
                          : switch (t) {
                              _PageTab.incoming => const UpcomingView(
                                gutter: kGutter,
                              ),
                              _PageTab.debts => const DebtsView(
                                gutter: kGutter,
                              ),
                              _PageTab.sms => const SmsView(gutter: kGutter),
                              _PageTab.history => TipsTrigger(
                                tips: _historyTips,
                                // The home page: the app has just opened.
                                delay: const Duration(milliseconds: 900),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        kGutter,
                                        0,
                                        kGutter,
                                        8,
                                      ),
                                      child: KeyedSubtree(
                                        key: _tipPeriod,
                                        child: _rangeControl(context, startDay),
                                      ),
                                    ),

                                    // --- Totals: separate tiles, told apart by background only ---
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        kGutter,
                                        0,
                                        kGutter,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          if (filter != _TypeFilter.income)
                                            Expanded(
                                              key: _tipExpenseCard,
                                              child: _totalTile(
                                                onTap: tileTap(
                                                  _TypeFilter.expense,
                                                ),
                                                amount:
                                                    filter == _TypeFilter.all
                                                    ? expenseTotal
                                                    : singleTotal,
                                                label: l.expenseShort,
                                                background: scheme.primary,
                                                foreground: textStrong,
                                              ),
                                            ),
                                          if (filter == _TypeFilter.all)
                                            const SizedBox(width: 8),
                                          if (filter != _TypeFilter.expense)
                                            Expanded(
                                              key: _tipIncomeCard,
                                              child: _totalTile(
                                                onTap: tileTap(
                                                  _TypeFilter.income,
                                                ),
                                                amount:
                                                    filter == _TypeFilter.all
                                                    ? incomeTotal
                                                    : singleTotal,
                                                label: l.incomeTitle,
                                                background: _incomeTileGreen,
                                                foreground: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // --- Back to all, sort, today ---
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        kGutter,
                                        0,
                                        kGutter,
                                        8,
                                      ),
                                      // Today out of view (another period, or
                                      // scrolled past it): the chip says so.
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable: _todayScrolledAway,
                                        builder: (context, scrolledAway, _) =>
                                            ListControlsRow(
                                              onAll: backToAll,
                                              byAmount: _sortByAmount,
                                              onSort: () => setState(
                                                () => _sortByAmount =
                                                    !_sortByAmount,
                                              ),
                                              list: _list,
                                              // Away from today's period: back.
                                              onToday:
                                                  settings.periodOffset != 0
                                                  ? () => _jumpToPeriod(0)
                                                  : null,
                                              todayAway:
                                                  settings.periodOffset != 0 ||
                                                  scrolledAway,
                                              // Open: closes (from either
                                              // view); closed: the whole
                                              // period.
                                              calendarOpen: _cal != _Cal.closed,
                                              onCalendar: _toggleCalendar,
                                            ),
                                      ),
                                    ),

                                    // --- The calendar (folded away, whole, or its strip) ---
                                    // Its own height changes as it folds:
                                    // opening and closing scale whatever
                                    // it is at.
                                    SizeTransition(
                                      sizeFactor: _calOpenCurve,
                                      alignment: AlignmentDirectional.topCenter,
                                      child: _calendar(
                                        context,
                                        settings,
                                        rows,
                                        filter,
                                      ),
                                    ),

                                    // --- Category wheel (only when filtered to one kind) ---
                                    // (a row of one chip has nothing to choose between)
                                    if (filter != _TypeFilter.all &&
                                        activeCatGids.length >= 2)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          kGutter,
                                          0,
                                          kGutter,
                                          8,
                                        ),
                                        child: TotalChipsRow(
                                          firstChipKey: _tipChip,
                                          selected: _selectedCat,
                                          onSelect: selectCat,
                                          chips: [
                                            for (final gid in activeCatGids)
                                              TotalChip(
                                                id: gid,
                                                label:
                                                    filter == _TypeFilter.income
                                                    ? ip.categoryName(gid)
                                                    : ep.categoryName(gid),
                                                total: catTotals[gid] ?? 0,
                                                color:
                                                    _colorForCategory(
                                                      gid,
                                                      chipsCategories,
                                                    ) ??
                                                    scheme.secondaryContainer,
                                              ),
                                          ],
                                        ),
                                      ),

                                    // --- Scrollable list ---
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: isLoading
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : (error != null)
                                          ? Center(
                                              child: InkText(
                                                error,
                                                style: const TextStyle(
                                                  color: kStrongRed,
                                                ),
                                              ),
                                            )
                                          : (groups.isEmpty)
                                          // The page extends under the bottom bar; pad by its height
                                          // so the text sits in the middle of what's visible.
                                          ? Padding(
                                              padding: EdgeInsets.only(
                                                bottom: MediaQuery.paddingOf(
                                                  context,
                                                ).bottom,
                                              ),
                                              child: Center(
                                                child: _EmptyRange(
                                                  text:
                                                      filter ==
                                                          _TypeFilter.income
                                                      ? l.noIncomeThisRange
                                                      : l.noExpensesThisRange,
                                                  // The period of the newest
                                                  // entry before this one (a
                                                  // new month starts empty).
                                                  lastEntry: () {
                                                    final k = _lastEntryOffset(
                                                      startDay,
                                                      settings,
                                                      ep.raw,
                                                      ip.raw,
                                                    );
                                                    return k == null
                                                        ? null
                                                        : () =>
                                                              _jumpToPeriod(k);
                                                  }(),
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              controller: _list,
                                              padding: const EdgeInsets.only(
                                                bottom: 88,
                                              ),
                                              // One flat list, built once per page build: a row
                                              // is a lookup, not a walk through the day groups.
                                              itemCount: rows.length,
                                              itemBuilder: (context, index) {
                                                final e = rows[index];
                                                final kind =
                                                    e['kind']
                                                        as TransactionKind;
                                                final isIncome =
                                                    kind ==
                                                    TransactionKind.income;
                                                final dtLocal =
                                                    (e['occurredAtUtc']
                                                            as DateTime)
                                                        .toLocal();

                                                final dateText =
                                                    _dayTitleForCalendar(
                                                      dtLocal,
                                                      settings,
                                                    );

                                                final categoryText =
                                                    _categoryNameForKind(
                                                      kind,
                                                      e['categoryGid']
                                                          as String?,
                                                      ep,
                                                      ip,
                                                    );
                                                final gid = rowIds[index];
                                                final noteText =
                                                    (e['note'] as String?)
                                                        ?.trim() ??
                                                    '';
                                                final catColor =
                                                    _colorForCategory(
                                                      e['categoryGid']
                                                          as String?,
                                                      _categoriesForKind(
                                                        kind,
                                                        ep,
                                                        ip,
                                                      ),
                                                    ) ??
                                                    scheme
                                                        .secondaryContainer; // fallback
                                                final catOnColor = _onColor(
                                                  catColor,
                                                );
                                                // A new day after this one: a
                                                // wider gap (date sort only;
                                                // the owner's call: no headers,
                                                // the gap is enough).
                                                final dayEnd = dayEnds[index];
                                                final row = Padding(
                                                  key: index == _todayAnchorAt
                                                      ? _todayAnchor
                                                      : null,
                                                  padding: EdgeInsets.fromLTRB(
                                                    kGutter,
                                                    0,
                                                    kGutter,
                                                    dayEnd ? kDayGap : 8,
                                                  ),
                                                  child: SwipeRow.editDelete(
                                                    context: context,
                                                    dismissKey: ValueKey(
                                                      '${isIncome ? 'inc' : 'exp'}_$gid',
                                                    ),
                                                    radius: kRowRadius,
                                                    confirmDelete: () => confirmDeleteSheet(
                                                      context,
                                                      title: isIncome
                                                          ? l.deleteIncomeTitle
                                                          : l.deleteExpenseTitle,
                                                      message: isIncome
                                                          ? l.deleteIncomeConfirm
                                                          : l.deleteExpenseConfirm,
                                                    ),
                                                    onDelete: () => isIncome
                                                        ? context
                                                              .read<
                                                                IncomeProvider
                                                              >()
                                                              .deleteIncome(gid)
                                                        : context
                                                              .read<
                                                                ExpenseProvider
                                                              >()
                                                              .deleteExpense(
                                                                gid,
                                                              ),
                                                    onEdit: () =>
                                                        _openEditSheet(
                                                          existing: e,
                                                          kind: kind,
                                                        ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              kRowRadius,
                                                            ),
                                                        onTap: () =>
                                                            _openEditSheet(
                                                              existing: e,
                                                              kind: kind,
                                                            ),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: scheme
                                                                .surfaceContainerHigh,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  kRowRadius,
                                                                ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 14,
                                                              ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .stretch,
                                                            children: [
                                                              // A 2x2 grid: title | amount on one line, category | date on
                                                              // the next. Each line is centered on its own, and both pills have
                                                              // one fixed height, so the four parts line up.
                                                              Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Expanded(
                                                                    child: InkText(
                                                                      (e['title']
                                                                              as String?) ??
                                                                          '',
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        fontSize:
                                                                            15,
                                                                        color:
                                                                            textMain,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  InkText(
                                                                    _digits(
                                                                      formatMinorWithCommas(
                                                                        (e['amountMinor']
                                                                                as int?) ??
                                                                            0,
                                                                      ),
                                                                    ),
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          18,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      color:
                                                                          textMain,
                                                                      height:
                                                                          1.2,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Expanded(
                                                                    child: Align(
                                                                      alignment:
                                                                          AlignmentDirectional
                                                                              .centerStart,
                                                                      // In the mixed list an
                                                                      // income is marked by a
                                                                      // chip, not by its amount.
                                                                      child: Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Flexible(
                                                                            // Already its list: the row's own tap.
                                                                            child: GestureDetector(
                                                                              behavior: HitTestBehavior.opaque,
                                                                              onTap:
                                                                                  e['categoryGid'] ==
                                                                                          null ||
                                                                                      e['categoryGid'] ==
                                                                                          _selectedCat
                                                                                  ? null
                                                                                  : () => _showCategory(
                                                                                      e['categoryGid']
                                                                                          as String,
                                                                                      income: isIncome,
                                                                                    ),
                                                                              child: TilePill(
                                                                                text: categoryText,
                                                                                background: catColor,
                                                                                foreground: catOnColor,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          if (isIncome &&
                                                                              filter ==
                                                                                  _TypeFilter.all) ...[
                                                                            const SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            TilePill(
                                                                              text: l.incomeTitle,
                                                                              background: _incomeTileGreen,
                                                                              foreground: Colors.white,
                                                                            ),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  TilePill(
                                                                    text:
                                                                        dateText,
                                                                    background:
                                                                        scheme
                                                                            .surfaceContainerHighest,
                                                                    foreground:
                                                                        scheme
                                                                            .onSurfaceVariant,
                                                                  ),
                                                                ],
                                                              ),

                                                              if (noteText
                                                                  .isNotEmpty) ...[
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                Container(
                                                                  width: double
                                                                      .infinity,
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: scheme
                                                                        .surfaceContainerHighest,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                  ),
                                                                  child: Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Expanded(
                                                                        child: InkText(
                                                                          noteText,
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            color:
                                                                                scheme.onSurfaceVariant,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                                // Each row's context, to tell
                                                // which is at the calendar's
                                                // reading line and to scroll
                                                // to a day.
                                                return Builder(
                                                  builder: (ctx) {
                                                    _rowCtx[index] = ctx;
                                                    // Lit a moment when
                                                    // asked for.
                                                    return _Flash(
                                                      id: gid,
                                                      flash: _flash,
                                                      insets:
                                                          EdgeInsets.fromLTRB(
                                                            kGutter,
                                                            0,
                                                            kGutter,
                                                            dayEnd
                                                                ? kDayGap
                                                                : 8,
                                                          ),
                                                      radius: kRowRadius,
                                                      child: index == 0
                                                          ? KeyedSubtree(
                                                              key: _tipTile,
                                                              child: row,
                                                            )
                                                          : row,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      // ⛔️ No FAB here — MainPage owns the single center FAB.
    );
  }

  Widget _totalTile({
    required int amount,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // One size whether one or both tiles show, so filtering doesn't
          // change the row's height.
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkText(
                _digits(formatMinorWithCommas(amount)),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              InkText(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: foreground.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row lit a moment (the theme's tint, as a selection, over its tile:
/// [child] less [insets], rounded by [radius]) when [flash] names it
/// ([id]); then [flash] is cleared. Only the row lit runs an animation.
class _Flash extends StatefulWidget {
  const _Flash({
    required this.id,
    required this.flash,
    required this.insets,
    required this.radius,
    required this.child,
  });

  final String id;
  final ValueNotifier<String?> flash;
  final EdgeInsets insets;
  final double radius;
  final Widget child;

  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  AnimationController? _lit;

  @override
  void initState() {
    super.initState();
    widget.flash.addListener(_check);
    _check();
  }

  @override
  void didUpdateWidget(_Flash old) {
    super.didUpdateWidget(old);
    if (old.flash != widget.flash) {
      old.flash.removeListener(_check);
      widget.flash.addListener(_check);
    }
    if (old.id != widget.id) _check();
  }

  void _check() {
    if (widget.flash.value != widget.id) return;
    final lit = _lit ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    lit.forward(from: 0).whenComplete(() {
      if (mounted && widget.flash.value == widget.id) widget.flash.value = null;
    });
    setState(() {});
  }

  @override
  void dispose() {
    widget.flash.removeListener(_check);
    _lit?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = _lit;
    if (lit == null) return widget.child;
    return CustomPaint(
      foregroundPainter: _FlashPainter(
        lit: lit,
        insets: widget.insets,
        radius: widget.radius,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: widget.child,
    );
  }
}

class _FlashPainter extends CustomPainter {
  _FlashPainter({
    required this.lit,
    required this.insets,
    required this.radius,
    required this.color,
  }) : super(repaint: lit);

  final Animation<double> lit;
  final EdgeInsets insets;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // In fast, held, then out slowly.
    final t = lit.value;
    final a = t < .12
        ? t / .12
        : t < .45
        ? 1.0
        : 1 - Curves.easeInOut.transform((t - .45) / .55);
    if (a <= 0 || t >= 1) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        insets.deflateRect(Offset.zero & size),
        Radius.circular(radius),
      ),
      Paint()..color = color.withValues(alpha: .22 * a),
    );
  }

  @override
  bool shouldRepaint(_FlashPainter old) =>
      old.color != color || old.insets != insets || old.radius != radius;
}

/// "Nothing in this range", and under it, when there are older entries, a
/// chip that goes to the period of the newest one ([lastEntry]).
class _EmptyRange extends StatelessWidget {
  const _EmptyRange({required this.text, required this.lastEntry});
  final String text;
  final VoidCallback? lastEntry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final go = lastEntry;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkText(text, style: TextStyle(color: scheme.onSurfaceVariant)),
        if (go != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: go,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.raised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkText(
                AppLocalizations.of(context)!.seeLastEntry,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

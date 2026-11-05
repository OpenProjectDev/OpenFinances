import 'dart:math' as math;

import 'dart:convert';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/period_range.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:openfinances/app/app_bottom_bar.dart';

import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/surfaces.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';
import 'package:openfinances/shared/ui/period_picker.dart';
import 'package:openfinances/shared/ui/tinted_dropdown.dart';
import 'package:flutter/scheduler.dart';
import 'package:openfinances/data/currency_units.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/features/settings/categories_page.dart';
import 'package:openfinances/features/widgets/bare_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart' as s;
import 'package:openfinances/shared/digits.dart';
import 'package:openfinances/shared/ui/group_fit.dart';
import 'package:openfinances/shared/ui/tips.dart';
import 'package:openfinances/shared/ui/category_legend.dart';
import 'package:openfinances/shared/ui/percent_text.dart';
import 'package:openfinances/shared/ui/dual_chip.dart';
import 'package:openfinances/shared/ui/period_place.dart';
import 'package:openfinances/shared/money_input.dart'
    show formatMinorWithCommas;

/// Persist budgets in SharedPreferences (per-category map)
class _BudgetStore {
  static const _kMapKey = 'catBudgetsV1';
  static const _kMigrationKey = '_budget_migrated_v3';

  /// Budgets exactly as recorded, in [_unit]. Never rewritten when the
  /// currency setting changes; [byCategoryMinor] shows them in [display].
  Map<String, int> _recorded = {};
  String _unit = 'IRT';

  /// Unit budgets are shown (and typed) in: the currency setting.
  String display = 'IRT';

  Map<String, int> get byCategoryMinor => {
    for (final e in _recorded.entries)
      e.key: amountInUnit(e.value, _unit, display),
  };

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    // Budgets saved before units were kept were entered in the setting.
    _unit = sp.getString(kBudgetsUnitPrefsKey) ?? display;

    // Check if migration to minor units is needed
    dynamic migratedRaw = sp.get(_kMigrationKey);
    final migrated = migratedRaw is bool
        ? migratedRaw
        : (migratedRaw is String ? migratedRaw == 'true' : false);

    final raw = sp.getString(_kMapKey);
    if (!migrated && (raw == null || raw.isEmpty)) {
      // Nothing old to convert: anything saved from now on is already in
      // minor units. (Unset, the next load "migrated" fresh budgets x100.)
      await sp.setBool(_kMigrationKey, true);
    }
    if (raw != null && raw.isNotEmpty) {
      final map = jsonDecode(raw);
      if (map is Map) {
        _recorded = map.map<String, int>(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        );

        // Migrate amounts to minor units if not done yet
        if (!migrated) {
          final migratedMap = <String, int>{};
          for (final entry in _recorded.entries) {
            final amount = entry.value;
            // Only migrate if amount seems to be in old format (< 10 million)
            if (amount < 10000000) {
              migratedMap[entry.key] = amount * 100;
            } else {
              migratedMap[entry.key] = amount;
            }
          }
          _recorded = migratedMap;

          // Save migrated data
          await sp.setString(_kMapKey, jsonEncode(_recorded));
          await sp.setBool(_kMigrationKey, true);
          debugPrint('[Budget Migration v3] Converted amounts to minor units');
        }
      }
    }
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMapKey, jsonEncode(_recorded));
    await sp.setString(kBudgetsUnitPrefsKey, _unit);
    await sp.setBool(_kMigrationKey, true); // saved values are minor units
    await sp.remove('budgetLeewayV1'); // the leeway, gone (2026-11-02)
  }

  int getFor(String categoryGid) =>
      amountInUnit(_recorded[categoryGid] ?? 0, _unit, display);

  /// [amountMinor] is in [display]; stored in the budgets' own unit.
  void setFor(String categoryGid, int amountMinor) {
    if (amountMinor <= 0) {
      _recorded.remove(categoryGid);
    } else {
      _recorded[categoryGid] = amountInUnit(amountMinor, display, _unit);
    }
  }
}

enum _SortMode {
  custom,
  budgetAsc,
  budgetDesc,
  spentAsc,
  spentDesc,
  remainingAsc, // NEW
  remainingDesc, // NEW
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, this.onCategoryTap});

  final void Function(String categoryGid)? onCategoryTap;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  /// What the page's tip is about: its sort / manage row.
  final _tipBudget = GlobalKey();

  List<Tip> _tips() => [
    Tip('budget.noBudget', [_tipBudget], (l) => l.tipBudget),
  ];

  // ==== Config ====
  static const int _kMinOffset = -240;
  static const int _kMaxOffset = 0;
  static const double _kGutter = 12;

  static const String _kSortModeKey = 'budgetSortModeV1';

  // A fresh install: by budget, largest first (until the user picks).
  _SortMode _sort = _SortMode.budgetDesc;

  /// The total bar's chips (as Statistics' pie's): categories unticked
  /// (their part leaves the bar; kept while the page is open) and the one
  /// lit by a touch (-1: none).
  final Set<String> _offBar = {};

  /// The lit one, heard only by the bar and its chips: a touch doesn't
  /// rebuild the page (the owner, 2026-10-30: lights lagged scrolling).
  final _touchedBar = ValueNotifier<int>(-1);

  final _store = _BudgetStore();
  bool _loaded = false;

  // ==== Lang helpers ====
  bool get _isFa => isFaUi(context);
  String _digits(String s) => faDigitsFor(_isFa) ? _toFaDigits(s) : s;
  AppLocalizations get _l => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _touchedBar.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _store.display = context.read<SettingsProvider>().currencyCode;
    await _store.load();
    await _loadSortMode();
    if (mounted) setState(() => _loaded = true);
  }

  // ======== Sort persistence ========
  Future<void> _loadSortMode() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSortModeKey);
    if (raw == null) return;
    final m = _sortModeFromString(raw);
    setState(() => _sort = m);
  }

  Future<void> _saveSortMode(_SortMode m) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSortModeKey, _sortModeToString(m));
  }

  Future<void> _setSort(_SortMode m) async {
    setState(() => _sort = m);
    await _saveSortMode(m);
  }

  String _sortModeToString(_SortMode m) {
    switch (m) {
      case _SortMode.custom:
        return 'custom';
      case _SortMode.budgetAsc:
        return 'budgetAsc';
      case _SortMode.budgetDesc:
        return 'budgetDesc';
      case _SortMode.spentAsc:
        return 'spentAsc';
      case _SortMode.spentDesc:
        return 'spentDesc';
      case _SortMode.remainingAsc:
        return 'remainingAsc';
      case _SortMode.remainingDesc:
        return 'remainingDesc';
    }
  }

  _SortMode _sortModeFromString(String s) {
    switch (s) {
      case 'budgetAsc':
        return _SortMode.budgetAsc;
      case 'budgetDesc':
        return _SortMode.budgetDesc;
      case 'spentAsc':
        return _SortMode.spentAsc;
      case 'spentDesc':
        return _SortMode.spentDesc;
      case 'remainingAsc':
        return _SortMode.remainingAsc;
      case 'remainingDesc':
        return _SortMode.remainingDesc;
      case 'custom':
      default:
        return _SortMode.custom;
    }
  }

  // Persian digit converter
  String _toFaDigits(String s) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], fa[i]);
    }
    return s;
  }

  String _fmtInt(int n) {
    // Convert minor units to major units with decimals
    final major = n / 100;
    final intPart = major.floor();
    final decPart = (major - intPart) * 100;

    // Format integer part with commas
    final s0 = intPart.toString();
    final b = StringBuffer();
    for (int i = 0; i < s0.length; i++) {
      final idxFromRight = s0.length - i;
      b.write(s0[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) b.write(',');
    }

    // Add decimal part if not zero
    if (decPart > 0) {
      b.write('.');
      b.write(decPart.round().toString().padLeft(2, '0'));
    }

    return b.toString();
  }

  // ========= Calendar helpers (month range by startDay & offset) =========

  (DateTime start, DateTime end) _rangeForOffset(
    AppCalendar cal,
    int startDay,
    int offset,
  ) {
    if (cal == AppCalendar.jalali) {
      final (s.Jalali js, s.Jalali je) = jalaliPeriod(offset, startDay);
      final start = js.toDateTime();
      final end = je.toDateTime().add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      return (start, end);
    } else {
      return gregorianPeriod(offset, startDay);
    }
  }

  String _rangeLabelOf(SettingsProvider sp, int offset) {
    if (sp.calendar == AppCalendar.jalali) {
      final (js, je) = jalaliPeriod(offset, sp.startDay);
      return rangeText(js.toDateTime(), je.toDateTime(), sp.calendar, _isFa);
    }
    final (gs, ge) = gregorianPeriod(offset, sp.startDay);
    return rangeText(gs, ge, sp.calendar, _isFa);
  }

  String _rangeLabel(SettingsProvider sp) => _rangeLabelOf(sp, sp.periodOffset);

  // ========= Spend aggregation =========

  Map<String, int> _spendByCategoryThisRange(
    List<Map<String, dynamic>> all,
    SettingsProvider sp,
  ) {
    final (start, end) = _rangeForOffset(
      sp.calendar,
      sp.startDay,
      sp.periodOffset,
    );
    final fallback = context.read<ExpenseProvider>().fallbackCategoryGid;
    // Worked out again only when the ledger or the period changes (the
    // page builds again on every chip touched, sort, settings change).
    final had = _spendFor;
    if (had != null &&
        identical(had.$1, all) &&
        had.$2 == start &&
        had.$3 == end &&
        had.$4 == fallback) {
      return _spend!;
    }
    final map = <String, int>{};
    for (final e in all) {
      final dtLocal = (e['occurredAtUtc'] as DateTime).toLocal();
      if (!dtLocal.isBefore(start) && !dtLocal.isAfter(end)) {
        final gid = (e['categoryGid'] as String?) ?? fallback;
        final amt = (e['amountMinor'] as int?) ?? 0;
        map.update(gid, (v) => v + amt, ifAbsent: () => amt);
      }
    }
    _spendFor = (all, start, end, fallback);
    return _spend = map;
  }

  (List<Map<String, dynamic>>, DateTime, DateTime, String)? _spendFor;
  Map<String, int>? _spend;

  int _sum(Iterable<int> xs) => xs.fold<int>(0, (a, b) => a + b);

  // ========= Range UI =========

  Future<void> _openRangeList(
    BuildContext sheetCtx,
    SettingsProvider sp,
  ) async {
    final cs = Theme.of(sheetCtx).colorScheme;
    final textMain = cs.onSurface;
    final offsets = List<int>.generate(
      _kMaxOffset - _kMinOffset + 1,
      (i) => _kMaxOffset - i,
    );

    await showModalBottomSheet(
      context: sheetCtx,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
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
                    _l.selectRange,
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
                        final selected = off == sp.periodOffset;
                        return OutlinedButton(
                          onPressed: () {
                            sp.setPeriodOffset(off);
                            Navigator.pop(ctx);
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
                                ? cs.primary.withValues(alpha: .15)
                                : cs.surfaceContainerHigh,
                            foregroundColor: textMain,
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Directionality(
                              textDirection: sp.calendar == AppCalendar.jalali
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: InkText(
                                _rangeLabelOf(sp, off),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? context.primaryInk
                                      : textMain,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: InkText(_l.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rangeControl(BuildContext context, SettingsProvider sp) {
    final periodOffset = sp.periodOffset;
    final canPrev = periodOffset > _kMinOffset;
    final canNext = periodOffset < _kMaxOffset;

    return PeriodPicker(
      label: _rangeLabel(sp),
      labelDirection: uiTextDirection(_isFa),
      canPrev: canPrev,
      canNext: canNext,
      onPrev: () => sp.setPeriodOffset(periodOffset - 1),
      onNext: () => sp.setPeriodOffset(periodOffset + 1),
      onOpenList: () => _openRangeList(context, sp),
      prevTooltip: _l.prevPeriod,
      nextTooltip: _l.nextPeriod,
    );
  }

  // ---- Category color helpers: use actual colors from ExpenseProvider ----
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

  Color _categoryColorForGid(ExpenseProvider ep, String gid, Color fallback) {
    // Each category's color looked up once per version of the categories
    // (it walked them all for every category, every build).
    if (!identical(_colorsFor, ep.categories)) {
      _colorsFor = ep.categories;
      _colors = {};
      for (final c in ep.categories) {
        final dyn = c as dynamic;
        _colors.putIfAbsent(dyn.gid as String, () => _asColor(dyn.color));
      }
    }
    return _colors[gid] ?? fallback;
  }

  List<Object?>? _colorsFor;
  Map<String, Color?> _colors = {};

  // ========= Single-category edit =========

  Future<void> _openEditSingleCategorySheet({
    required BuildContext context,
    required String categoryGid,
    required String categoryName,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final ctrl = TextEditingController(
      text: _store.getFor(categoryGid) > 0
          ? _fmtInt(_store.getFor(categoryGid))
          : '',
    );

    int parseMinor(String s) {
      final ascii = s
          .replaceAll('۰', '0')
          .replaceAll('۱', '1')
          .replaceAll('۲', '2')
          .replaceAll('۳', '3')
          .replaceAll('۴', '4')
          .replaceAll('۵', '5')
          .replaceAll('۶', '6')
          .replaceAll('۷', '7')
          .replaceAll('۸', '8')
          .replaceAll('۹', '9');
      // Remove thousands separators but keep decimal point
      final clean = ascii.replaceAll(RegExp(r'[,٬،\s]'), '');
      // Parse as double to support decimals, then convert to minor units
      final asDouble = double.tryParse(clean) ?? 0;
      return (asDouble * 100).round();
    }

    // Built once: the sheet route re-runs its builder every keyboard frame;
    // KeyboardInset lifts this instance instead of rebuilding the form.
    // (No full-screen tap catcher: the modal barrier handles outside taps.)
    final actionStyle = OutlinedButton.styleFrom(
      overlayColor: Colors.transparent,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
    );
    Widget? sheet;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => KeyboardInset(
        child: sheet ??= Material(
          color: Theme.of(sheetCtx).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          elevation: 8,
          child: SafeArea(
            top: false,
            // Like the other sheets: no title or label, the category as
            // context, the amount field (with the calculator), the actions.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkText(
                    categoryName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: kSheetTitleSize,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: kSheetTitleGap),
                  AmountFieldRow(controller: ctrl, hint: _l.categoryBudget),
                  const SizedBox(height: kSheetRowGap),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: cancelButtonStyle(actionStyle),
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: InkText(_l.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          // Grey until the amount differs from the budget
                          // it has (empty: no budget).
                          child: ListenableBuilder(
                            listenable: ctrl,
                            builder: (context, _) => OutlinedButton(
                              style: saveButtonStyle(
                                context,
                                actionStyle,
                                parseMinor(ctrl.text) !=
                                    _store.getFor(categoryGid),
                              ),
                              onPressed:
                                  parseMinor(ctrl.text) ==
                                      _store.getFor(categoryGid)
                                  ? null
                                  : () async {
                                      _store.setFor(
                                        categoryGid,
                                        parseMinor(ctrl.text),
                                      );
                                      await _store.save();
                                      if (!mounted || !sheetCtx.mounted) return;
                                      setState(() {});
                                      Navigator.pop(sheetCtx);
                                    },
                              child: InkText(_l.save),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Sort labels (text, no box arrows) ----------
  /// Fixed-height tinted box shared by the header's "Manage" and sort
  /// controls so they always match.
  Widget _headerBox(ColorScheme scheme, {required Widget child}) => Builder(
    // A step above whatever it sits in (the categories section).
    builder: (context) => Container(
      height: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );

  /// A header box's content: its mark pinned at the start, its word
  /// (shrunk to fit) centered in the rest, so another word (ascending ⇄
  /// descending) doesn't move the mark.
  Widget _iconLabel(Widget icon, String text, TextStyle style) => Row(
    children: [
      icon,
      const SizedBox(width: 6),
      Expanded(
        child: Center(
          child: GroupFit(child: InkText(text, maxLines: 1, style: style)),
        ),
      ),
    ],
  );

  // The sort is shown as two chips: what to sort by, and which way.
  _SortField get _field => switch (_sort) {
    _SortMode.custom => _SortField.custom,
    _SortMode.budgetAsc || _SortMode.budgetDesc => _SortField.budget,
    _SortMode.spentAsc || _SortMode.spentDesc => _SortField.spent,
    _SortMode.remainingAsc || _SortMode.remainingDesc => _SortField.remaining,
  };

  bool get _descending =>
      _sort == _SortMode.budgetDesc ||
      _sort == _SortMode.spentDesc ||
      _sort == _SortMode.remainingDesc;

  _SortMode _modeOf(_SortField f, bool desc) => switch (f) {
    _SortField.custom => _SortMode.custom,
    _SortField.budget => desc ? _SortMode.budgetDesc : _SortMode.budgetAsc,
    _SortField.spent => desc ? _SortMode.spentDesc : _SortMode.spentAsc,
    _SortField.remaining =>
      desc ? _SortMode.remainingDesc : _SortMode.remainingAsc,
  };

  Future<void> _manageCategories() async {
    final ep = context.read<ExpenseProvider>();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CategoriesPage(navIndex: 1)),
    );
    if (!mounted) return;
    await ep.loadCategories();
    setState(() {}); // rebuild either way
  }

  @override
  Widget build(BuildContext context) =>
      TipsTrigger(tips: _tips, child: _body(context));

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final ep = context.watch<ExpenseProvider>();

    // Budgets are shown in the current unit (stored ones never change).
    _store.display = sp.currencyCode;

    if (!_loaded) {
      return Scaffold(
        appBar: bareAppBar(),
        // No inline text fields here; don't relayout under add-sheet keyboards.
        resizeToAvoidBottomInset: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Data for current range
    final byCat = _spendByCategoryThisRange(ep.raw, sp);

    // >>> filter spend to categories that actually have a budget (>0)
    final live = {for (final c in ep.categories) c.gid};
    final budgetedIds = _store.byCategoryMinor.entries
        .where((e) => e.value > 0 && live.contains(e.key))
        .map((e) => e.key)
        .toSet();

    final byCatBudgeted = <String, int>{
      for (final e in byCat.entries)
        if (budgetedIds.contains(e.key)) e.key: e.value,
    };

    // Spend total that counts *only* budgeted categories
    final spentTotalBudgeted = _sum(byCatBudgeted.values);

    // The whole budget: the sum of all category budgets that are set (>0).
    final totalBudget = _sum([
      for (final e in _store.byCategoryMinor.entries)
        if (live.contains(e.key)) e.value,
    ]);

    final textVariant = scheme.onSurfaceVariant;
    final headerText = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );

    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = 28 + bottomSafe + kBottomNavigationBarHeight;

    // Build sortable list model
    final cats = ep.categories;
    final items = [
      for (int i = 0; i < cats.length; i++)
        _CatRow(
          gid: cats[i].gid,
          name: cats[i].name,
          index: i,
          spent: byCat[cats[i].gid] ?? 0,
          budget: _store.getFor(cats[i].gid),
          color: _categoryColorForGid(ep, cats[i].gid, scheme.primary),
          icon: resolveCategoryIcon(
            cats[i].iconCodePoint,
            cats[i].iconFontFamily,
          ),
        ),
    ];

    // color lookup for total stacked bar (consistent with rows)
    final colorOf = {for (final it in items) it.gid: it.color};

    // Apply sorting
    int remainingOf(_CatRow x) =>
        x.budget <= 0 ? 0 : math.max(0, x.budget - x.spent);

    switch (_sort) {
      case _SortMode.custom:
        items.sort((a, b) => a.index.compareTo(b.index));
        break;
      case _SortMode.budgetAsc:
        items.sort((a, b) => a.budget.compareTo(b.budget));
        break;
      case _SortMode.budgetDesc:
        items.sort((a, b) => b.budget.compareTo(a.budget));
        break;
      case _SortMode.spentAsc:
        items.sort((a, b) => a.spent.compareTo(b.spent));
        break;
      case _SortMode.spentDesc:
        items.sort((a, b) => b.spent.compareTo(a.spent));
        break;
      case _SortMode.remainingAsc:
        items.sort((a, b) {
          final aNo = a.budget <= 0;
          final bNo = b.budget <= 0;
          if (aNo != bNo) return aNo ? 1 : -1; // no budget LAST
          return remainingOf(a).compareTo(remainingOf(b));
        });
        break;
      case _SortMode.remainingDesc:
        items.sort((a, b) {
          final aNo = a.budget <= 0;
          final bNo = b.budget <= 0;
          if (aNo != bNo) return aNo ? 1 : -1; // no budget LAST
          return remainingOf(b).compareTo(remainingOf(a));
        });
        break;
    }

    // Total label order by locale (use budget-filtered spend)
    final hasAnyBudget = totalBudget > 0;

    // The bar's parts, largest first, and their chips' percentages: each
    // category's share of the TOTAL BUDGET (the bar's whole width), not of
    // what was spent: they add up to how full the bar is. Under budget the
    // rest is one more share (so the rounded tenths add up exactly); over
    // it, each is simply its spend over the budget. Unticking one takes its
    // part off the bar; the others' shares (of the same budget) stay.
    final barParts = byCatBudgeted.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final under = spentTotalBudgeted <= totalBudget;
    final shares = !hasAnyBudget
        ? [for (final _ in barParts) 0, 0]
        : under
        ? shareTenths([
            for (final e in barParts) e.value,
            totalBudget - spentTotalBudgeted,
          ])
        : [
            for (final e in barParts) (e.value * 1000 / totalBudget).round(),
            ((spentTotalBudgeted - totalBudget) * 1000 / totalBudget).round(),
          ];
    final barTenths = shares.sublist(0, barParts.length);
    final barOn = {
      for (final e in barParts)
        if (!_offBar.contains(e.key)) e.key: e.value,
    };
    String? litOf(int i) =>
        i >= 0 && i < barParts.length ? barParts[i].key : null;
    void touchBar(int i) => _touchedBar.value = i;

    final budgeted = [
      for (final it in items)
        if (it.budget > 0) it,
    ];
    final unbudgeted = [
      for (final it in items)
        if (it.budget <= 0) it,
    ];

    Widget tile(_CatRow it, {GlobalKey? pencilKey}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _CategoryBudgetTile(
        pencilKey: pencilKey,
        title: it.name,
        color: it.color,
        icon: it.icon,
        spentMinor: it.spent,
        budgetMinor: it.budget,
        digits: _digits,
        faLocale: _isFa,
        onEdit: () => _openEditSingleCategorySheet(
          context: context,
          categoryGid: it.gid,
          categoryName: it.name,
        ),
        // Only with entries this period (History would be empty).
        onTap: byCat.containsKey(it.gid)
            ? () => widget.onCategoryTap?.call(it.gid)
            : null,
      ),
    );

    return Scaffold(
      appBar: bareAppBar(),
      // No inline text fields here; don't relayout under add-sheet keyboards.
      resizeToAvoidBottomInset: false,
      // The period bar stays in view while the page scrolls under it, as
      // on Home and Statistics (the owner, 2026-11-01).
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_kGutter, 12, _kGutter, 8),
            child: _rangeControl(context, sp),
          ),
          Expanded(
            child: TabScrollTop(
              tab: 1,
              // Tapping this tab again scrolls back up.
              builder: (list) => PeriodPlace(
                controller: list,
                child: SingleChildScrollView(
                  controller: list,
                  padding: EdgeInsets.fromLTRB(
                    _kGutter,
                    4,
                    _kGutter,
                    bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== BUDGET: spent of the whole budget and how much of it
                      // that is, the bar, and its categories (the owner, 2026-10-29:
                      // a section like the rest; it was a "Total" card).
                      FoldSection(
                        id: 'budget.total',
                        title: _l.budget,
                        initiallyOpen: true,
                        // Nothing budgeted: just saying so (the owner, 2026-11-04: it
                        // was this content blurred, the words over it).
                        child: !hasAnyBudget
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: InkText(
                                  _l.assignBudgetFirst,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : RepaintBoundary(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _TotalChips(
                                      spentMinor: spentTotalBudgeted,
                                      budgetMinor: totalBudget,
                                      digits: _digits,
                                    ),
                                    const SizedBox(height: 14),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _touchedBar,
                                      builder: (context, touched, _) =>
                                          _StackedBudgetBar(
                                            // sorted biggest-first internally
                                            spentByCategory: barOn,
                                            totalBudgetMinor: totalBudget,
                                            background:
                                                scheme.surfaceContainerHighest,
                                            colorForGid: (gid) =>
                                                colorOf[gid] ?? scheme.primary,
                                            lit: litOf(touched),
                                            // A part touched lights its chip.
                                            onTouch: (gid) => touchBar(
                                              gid == null
                                                  ? -1
                                                  : barParts.indexWhere(
                                                      (e) => e.key == gid,
                                                    ),
                                            ),
                                            height: 32, // thicker total bar
                                          ),
                                    ),
                                    // The bar's categories, as the pie's chips
                                    // (the owner, 2026-10-26).
                                    if (barParts.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ValueListenableBuilder<int>(
                                        valueListenable: _touchedBar,
                                        builder: (context, touched, _) =>
                                            CategoryLegend(
                                              gids: [
                                                for (final e in barParts) e.key,
                                              ],
                                              tenths: [
                                                for (final (i, e)
                                                    in barParts.indexed)
                                                  _offBar.contains(e.key)
                                                      ? null
                                                      : barTenths[i],
                                              ],
                                              layoutTenths: barTenths,
                                              colorOf: (gid, _) =>
                                                  colorOf[gid] ??
                                                  scheme.primary,
                                              nameOf: ep.categoryName,
                                              off: _offBar,
                                              onToggle: (gid) {
                                                _touchedBar.value = -1;
                                                setState(() {
                                                  if (!_offBar.remove(gid)) {
                                                    _offBar.add(gid);
                                                  }
                                                });
                                              },
                                              touched: touched,
                                              onTouch: touchBar,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // ===== BUDGETS: its controls first, then the categories with a
                      // budget.
                      FoldSection(
                        id: 'budget.categories',
                        title: _l.budgetsSection,
                        initiallyOpen: true,
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  // Tiles bring their own 10 below them.
                                  padding: const EdgeInsets.fromLTRB(
                                    kSectionInset,
                                    kSectionInset,
                                    kSectionInset,
                                    kSectionInset - 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Sort by, which way, manage: equal widths,
                                      // their words one size.
                                      FitGroup(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TintedDropdown<_SortField>(
                                                value: _field,
                                                leading: UIcons.sort,
                                                items: {
                                                  _SortField.custom:
                                                      _l.sortCustom,
                                                  _SortField.budget:
                                                      _l.sortBudget,
                                                  _SortField.spent:
                                                      _l.sortSpent,
                                                  _SortField.remaining:
                                                      _l.sortRemaining,
                                                },
                                                // Largest first when picking a new field.
                                                onChanged: (f) => _setSort(
                                                  _modeOf(
                                                    f,
                                                    _field ==
                                                            _SortField.custom ||
                                                        _descending,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Custom order has no direction: Manage
                                            // takes its place too.
                                            if (_field !=
                                                _SortField.custom) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => _setSort(
                                                    _modeOf(
                                                      _field,
                                                      !_descending,
                                                    ),
                                                  ),
                                                  child: _headerBox(
                                                    scheme,
                                                    child: _iconLabel(
                                                      Icon(
                                                        _descending
                                                            ? UIcons.arrowDown
                                                            : UIcons.arrowUp,
                                                        size: 16,
                                                        color: scheme.onSurface,
                                                      ),
                                                      _descending
                                                          ? _l.sortDescending
                                                          : _l.sortAscending,
                                                      headerText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: _field == _SortField.custom
                                                  ? 2
                                                  : 1,
                                              child: GestureDetector(
                                                onTap: _manageCategories,
                                                child: _headerBox(
                                                  scheme,
                                                  child: _iconLabel(
                                                    ImageIcon(
                                                      AppIcons.cogwheel,
                                                      size: 16,
                                                      color: scheme.onSurface,
                                                    ),
                                                    _l.manageCategories,
                                                    headerText,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (items.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 24,
                                          ),
                                          child: Center(
                                            child: InkText(
                                              _l.noData,
                                              style: TextStyle(
                                                color: textVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                      for (final it in budgeted) tile(it),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ===== NO BUDGET: the categories without one, a section of
                      // their own under it (open at first when nothing has a budget).
                      if (unbudgeted.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FoldSection(
                          id: 'budget.noBudget',
                          title: _l.noBudgetGroup,
                          initiallyOpen: !hasAnyBudget,
                          padding: const EdgeInsets.fromLTRB(
                            kSectionInset,
                            kSectionInset,
                            kSectionInset,
                            kSectionInset - 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            // The first one's pencil: where the tip points.
                            children: [
                              for (final (i, it) in unbudgeted.indexed)
                                tile(it, pencilKey: i == 0 ? _tipBudget : null),
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
        ],
      ),
    );
  }
}

/// What the categories are sorted by (the direction is its own chip).
enum _SortField { custom, budget, spent, remaining }

// ======= Data helper for sorting =======
class _CatRow {
  final String gid;
  final String name;
  final int index; // original order (custom)
  final int spent;
  final int budget;
  final Color color;
  final IconData icon;

  _CatRow({
    required this.gid,
    required this.name,
    required this.index,
    required this.spent,
    required this.budget,
    required this.color,
    required this.icon,
  });
}

// ======= UI widgets =======

class _StackedBudgetBar extends StatefulWidget {
  const _StackedBudgetBar({
    required this.spentByCategory,
    required this.totalBudgetMinor,
    required this.background,
    required this.colorForGid,
    this.lit,
    this.onTouch,
    this.height = 18,
  });

  final Map<String, int> spentByCategory;

  /// The whole budget (the bar's length).
  final int totalBudgetMinor;
  final Color background;
  final Color Function(String gid) colorForGid;

  /// The part whose chip is lit: it grows out of the bar, up and down (as
  /// the pie's slice grows out of the pie; the owner, 2026-10-26).
  final String? lit;

  /// A part touched (its category) or let go (null), like the pie's slices.
  final ValueChanged<String?>? onTouch;
  final double height;

  @override
  State<_StackedBudgetBar> createState() => _StackedBudgetBarState();
}

class _StackedBudgetBarState extends State<_StackedBudgetBar>
    with SingleTickerProviderStateMixin {
  /// How far a lit part reaches past the bar, up and down.
  static const double _out = 6;
  static const _duration = Duration(milliseconds: 200);

  /// How far out each part is (0 in the bar, 1 all the way out).
  final Map<String, double> _grown = {};
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void didUpdateWidget(_StackedBudgetBar old) {
    super.didUpdateWidget(old);
    if (old.lit != widget.lit && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final step = (elapsed - _last).inMicroseconds / _duration.inMicroseconds;
    _last = elapsed;
    var moving = false;
    setState(() {
      for (final gid in {..._grown.keys, ?widget.lit}) {
        final to = gid == widget.lit ? 1.0 : 0.0;
        final from = _grown[gid] ?? 0;
        final now = from < to
            ? math.min(to, from + step)
            : math.max(to, from - step);
        if (now == 0) {
          _grown.remove(gid);
        } else {
          _grown[gid] = now;
        }
        if (now != to) moving = true;
      }
    });
    if (!moving) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// The parts, biggest first, each with its share of the colored length.
  List<MapEntry<String, int>> get _parts =>
      widget.spentByCategory.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  double get _cap {
    final spent = widget.spentByCategory.values.fold<int>(0, (a, b) => a + b);
    return widget.totalBudgetMinor <= 0
        ? 0.0
        : (spent / widget.totalBudgetMinor).clamp(0.0, 1.0);
  }

  /// Between two segments.
  static const double _gap = 3;

  /// The narrowest a segment gets (a sliver of a category still shows).
  static const double _minWidth = 4;

  /// The segments across [width], left to right: each category's (biggest
  /// first) as its share of what was spent, then what's left of the budget
  /// (gid null), a [_gap] between each (the owner, 2026-10-27: rounded
  /// chunks with a break between them, as current charts do).
  List<(String?, double, double)> _segments(double width) {
    final parts = _parts;
    final sum = parts.fold<int>(0, (a, e) => a + e.value);
    final cap = sum <= 0 ? 0.0 : _cap;
    final left = math.max(0.0, 1 - cap);
    final items = <(String?, double)>[
      for (final e in parts) (e.key, cap * e.value / sum),
      if (left > 0) (null, left),
    ];
    if (items.isEmpty) return const [];
    final room = width - _gap * (items.length - 1);
    var widths = [for (final it in items) room * it.$2];
    // Slivers widen to the least; the rest give that room back in step.
    final small = widths.where((w) => w < _minWidth).length;
    if (small > 0 && small < widths.length) {
      final big = widths
          .where((w) => w >= _minWidth)
          .fold(0.0, (a, w) => a + w);
      final scale = (room - small * _minWidth) / big;
      widths = [for (final w in widths) w < _minWidth ? _minWidth : w * scale];
    }
    final out = <(String?, double, double)>[];
    var x = 0.0;
    for (var k = 0; k < items.length; k++) {
      out.add((items[k].$1, x, x + widths[k]));
      x += widths[k] + _gap;
    }
    return out;
  }

  /// The category under [x] (null: none, or what's left of the budget); a
  /// gap goes to the segment nearer it.
  String? _partAt(double x, double width) {
    for (final (gid, a, b) in _segments(width)) {
      if (x >= a - _gap / 2 && x <= b + _gap / 2) {
        return gid;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        void touch(Offset p) =>
            widget.onTouch?.call(_partAt(p.dx, box.maxWidth));
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => touch(e.localPosition),
          onPointerMove: (e) => touch(e.localPosition),
          onPointerUp: (_) => widget.onTouch?.call(null),
          onPointerCancel: (_) => widget.onTouch?.call(null),
          child: CustomPaint(
            size: Size(box.maxWidth, widget.height),
            painter: _BarPainter(
              segments: [
                for (final (gid, a, b) in _segments(box.maxWidth))
                  (
                    a,
                    b,
                    gid == null ? widget.background : widget.colorForGid(gid),
                    gid == null
                        ? 0.0
                        : Curves.easeOutCubic.transform(_grown[gid] ?? 0),
                  ),
              ],
              out: _out,
            ),
          ),
        );
      },
    );
  }
}

/// The bar: its segments ([_StackedBudgetBarState._segments]), each a
/// rounded chunk in its color; one with a grow above 0 reaches that much of
/// [out] past the bar, up and down (drawn last, over the others).
class _BarPainter extends CustomPainter {
  _BarPainter({required this.segments, required this.out});

  /// Each segment's start and end, color and grow (0..1).
  final List<(double, double, Color, double)> segments;
  final double out;

  static const double _radius = 5;

  @override
  void paint(Canvas canvas, Size size) {
    void chunk(double a, double b, Color color, double grow) {
      final g = out * grow;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(a, -g, b, size.height + g),
          Radius.circular(math.min(_radius, (b - a) / 2)),
        ),
        Paint()..color = color,
      );
    }

    for (final (a, b, color, grow) in segments) {
      if (grow == 0) chunk(a, b, color, 0);
    }
    for (final (a, b, color, grow) in segments) {
      if (grow > 0) chunk(a, b, color, grow);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.out != out ||
      old.segments.length != segments.length ||
      [for (var i = 0; i < segments.length; i++) old.segments[i] != segments[i]]
          .any((d) => d);
}

/// The Budget section's first row: what was spent OF the whole budget, a
/// chip of two tones meeting along a "/" (a fraction: left to right in both
/// languages, as each category's tile), and how much of it that is, a chip
/// one width for the widest share (999.9 %), as the tiles' own.
class _TotalChips extends StatelessWidget {
  const _TotalChips({
    required this.spentMinor,
    required this.budgetMinor,
    required this.digits,
  });

  final int spentMinor, budgetMinor;
  final String Function(String) digits;

  @override
  Widget build(BuildContext context) {
    final chipText = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    String fmt(int n) => digits(formatMinorWithCommas(n));
    double textWidth(String t) => (TextPainter(
      text: TextSpan(
        text: t,
        style: DefaultTextStyle.of(context).style.merge(chipText),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width.ceilToDouble();
    final used = budgetMinor <= 0
        ? 0
        : (spentMinor * 1000 / budgetMinor).round();
    // A step above the section, the fraction's first part one more (as a
    // tile's chips are above the tile).
    final tone = context.raised;
    return Row(
      children: [
        Expanded(
          child: DualValueChip(
            firstTone: context.raisedBy(2),
            secondTone: tone,
            data: DualChipData(
              label: '',
              direction: TextDirection.ltr,
              slant: true,
              first: InkText(fmt(spentMinor), style: chipText),
              firstWidth: textWidth(fmt(spentMinor)),
              second: InkText(fmt(budgetMinor), style: chipText),
              secondWidth: textWidth(fmt(budgetMinor)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Red once over the budget (the owner, 2026-11-02).
        Container(
          height: DualChipRow.height,
          width: 20 + PercentText.widthOf(context, 9999, chipText),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: spentMinor > budgetMinor && budgetMinor > 0
                ? kStrongRed
                : tone,
            borderRadius: BorderRadius.circular(8),
          ),
          child: PercentText(
            used,
            style: spentMinor > budgetMinor && budgetMinor > 0
                ? chipText.copyWith(color: Colors.white)
                : chipText,
          ),
        ),
      ],
    );
  }
}

/// A category's budget: its own icon in its color, its name, how much of
/// the budget is used (a percentage) and the edit pencil; its bar; under it
/// one chip ([DualValueChip], the tile's width): what was spent OF the
/// budget, the two tones meeting along a "/" (a fraction: left to right in
/// both languages). No budget: what was spent, by the pencil.
class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.title,
    required this.color,
    required this.icon,
    required this.spentMinor,
    required this.budgetMinor,
    required this.digits,
    required this.faLocale,
    required this.onEdit,
    this.pencilKey,
    this.onTap,
  });

  final String title;
  final Color color;
  final IconData icon;
  final int spentMinor;
  final int budgetMinor;
  final String Function(String) digits;
  final bool faLocale;
  final VoidCallback onEdit;

  /// On the pencil (a tip points at it).
  final GlobalKey? pencilKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textMain = scheme.onSurface;
    final textVariant = scheme.onSurfaceVariant;
    // A step above the section it's in; its bar track and chips a step
    // above the tile, their first parts (and the words under them) one
    // more.
    final bg = context.raised;
    final trackBg = context.raisedBy(2);
    final lightBg = context.raisedBy(3);

    // No budget: the title row only (no bar, no chips under it).
    final bool noBudget = budgetMinor <= 0;
    final double pct = noBudget
        ? 0
        : (spentMinor / budgetMinor).clamp(0.0, 1.0);

    String fmt(int n) => digits(formatMinorWithCommas(n));
    final chipText = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: textVariant,
    );
    double textWidth(String t) => (TextPainter(
      text: TextSpan(
        text: t,
        style: DefaultTextStyle.of(context).style.merge(chipText),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width.ceilToDouble();

    // How much of the budget is used (over 100% when it's overspent).
    final usedTenths = noBudget ? 0 : (spentMinor * 1000 / budgetMinor).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        // Flush with the section's controls (no card margin).
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        color: bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CategoryIcon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkText(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: textMain,
                      ),
                    ),
                  ),
                  if (noBudget) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: DualChipRow.height,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: trackBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkText(fmt(spentMinor), style: chipText),
                    ),
                  ],
                  // How much of it is used, by the pencil (the owner,
                  // 2026-10-28; it was "remaining" in a row of its own).
                  if (!noBudget) ...[
                    const SizedBox(width: 8),
                    // One width on every tile, for the widest share (the
                    // owner, 2026-10-28): 999.9 %. Red once over the budget
                    // (2026-11-02).
                    Container(
                      height: DualChipRow.height,
                      width: 20 + PercentText.widthOf(context, 9999, chipText),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: spentMinor > budgetMinor ? kStrongRed : trackBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PercentText(
                        usedTenths,
                        style: spentMinor > budgetMinor
                            ? chipText.copyWith(color: Colors.white)
                            : chipText,
                      ),
                    ),
                  ],
                  // At the very end: in the same place on every tile.
                  const SizedBox(width: 8),
                  EditSquare(
                    key: pencilKey,
                    onTap: onEdit,
                    background: trackBg,
                    addLabel: noBudget
                        ? AppLocalizations.of(context)!.addBudget
                        : null,
                  ),
                ],
              ),
              if (!noBudget) ...[
                const SizedBox(height: 12),
                Container(
                  height: 16,
                  // The color one physical pixel inside its track (see
                  // _StackedBudgetBar).
                  padding: EdgeInsets.all(
                    1 / MediaQuery.devicePixelRatioOf(context),
                  ),
                  // Flat ends, the corners rounded (as the total bar's
                  // segments; the owner, 2026-10-27), the fill's too.
                  decoration: BoxDecoration(
                    color: trackBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // What was spent of the budget, one chip the tile's width.
                DualValueChip(
                  firstTone: lightBg,
                  secondTone: trackBg,
                  data: DualChipData(
                    label: '',
                    // A fraction: spent / budget, left to right.
                    direction: TextDirection.ltr,
                    slant: true,
                    first: InkText(fmt(spentMinor), style: chipText),
                    firstWidth: textWidth(fmt(spentMinor)),
                    second: InkText(fmt(budgetMinor), style: chipText),
                    secondWidth: textWidth(fmt(budgetMinor)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

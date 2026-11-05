import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import 'package:openfinances/data/backup.dart';
import 'package:openfinances/shared/calendar_text.dart';
import 'package:openfinances/data/expense_provider.dart';
import 'package:openfinances/data/income_provider.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/app/app_bottom_bar.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/features/stats/statistics_page.dart';
import 'package:openfinances/features/expenses/expenses_page.dart';
import 'package:openfinances/features/settings/settings_page.dart';
import 'package:openfinances/features/budget/budget_page.dart';

import 'package:openfinances/features/expenses/add_edit_expense_sheet.dart';
import 'package:openfinances/features/sms/bank_notifications.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _index = 0;
  String? _expensesInitialCategory;

  /// Tabs built so far. A tab is built on first visit and then kept alive,
  /// so switching back doesn't rebuild the page (and reload its data).
  final Set<int> _visited = {0};

  /// What "+" adds on the Expenses page (depends on its own tab: an entry,
  /// an upcoming payment, a debt). Set by the page itself.
  VoidCallback? _expensesAdd;

  @override
  void initState() {
    super.initState();
    // Just restarted after a restore: say how it went.
    final restored = BackupData.lastRestore;
    if (restored != null) {
      BackupData.lastRestore = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        showAppNotice(
          context,
          restored.skipped > 0
              ? (restored.skipped == 1
                    ? l.restoreSkippedOne
                    : l.restoreSkipped)(
                  uiDigits('${restored.skipped}', isFaUi(context)),
                )
              : l.restoreDone,
          // Some rows left out: said plainly, not as a clean success.
          kind: restored.skipped > 0 ? NoticeKind.neutral : NoticeKind.success,
        );
      });
    }
    mainTab.value = _index;
    // Pushed pages (with their own bottom bar) switch tabs through this.
    mainTab.addListener(_onMainTab);
  }

  @override
  void dispose() {
    mainTab.removeListener(_onMainTab);
    super.dispose();
  }

  void _onMainTab() {
    if (mainTab.value != _index) _select(mainTab.value);
  }

  void _select(int index, {bool record = true}) {
    if (index == _index) mainTabReselected.value++;
    // Another page: its sections as they start ("keep folds" off), its
    // lists at their tops ("keep place" off).
    if (index != _index) {
      final settings = context.read<SettingsProvider>();
      FoldSection.resetUnlessKept(settings);
      RememberedScroll.toTopUnlessKept(settings);
    }
    if (record && index != _index) {
      recordNavStop(NavStop(_index, _index == 0 ? expensesSubTab : null));
    }
    setState(() {
      _index = index;
      _visited.add(index);
    });
    mainTab.value = index;
  }

  /// The "+": what the current page adds, else a new entry.
  void _add() {
    final pageAdd = _index == 0 ? _expensesAdd : null;
    if (pageAdd != null) {
      pageAdd();
    } else {
      showAddEditTransactionSheet(context: context);
    }
  }

  // Navigate to expenses page with a selected category
  void switchToExpensesWithCategory(String categoryGid) {
    // Back returns here; the fresh Expenses page starts on History.
    recordNavStop(NavStop(_index, _index == 0 ? expensesSubTab : null));
    expensesSubTab = 'history';
    setState(() {
      _expensesInitialCategory = categoryGid;
      _expensesPage = _makeExpensesPage(); // new key => fresh filter state
      _index = 0; // Switch to expenses tab
      _visited.add(0);
    });
    mainTab.value = 0;
  }

  // Page widgets are cached: the same instances on every MainPage build means
  // a tab tap doesn't rebuild the (kept-alive) pages behind it.
  late Widget _expensesPage = _makeExpensesPage();
  late final Widget _budgetPage = BudgetPage(
    onCategoryTap: switchToExpensesWithCategory,
  );

  Widget _makeExpensesPage() => ExpensesPage(
    key: ValueKey(_expensesInitialCategory),
    initialCategory: _expensesInitialCategory,
    bindOpenAdd: (add) => _expensesAdd = add,
  );

  List<Widget> _buildPages() => [
    _expensesPage,
    _budgetPage,
    const StatisticsPage(),
    const SettingsPage(),
  ];

  /// When Back was last pressed with nowhere to go back to.
  DateTime? _exitAskedAt;

  /// Back on the main page: to the previous place (tab / sub-tab, the last
  /// 10 kept); with none left, a notice first, and a second Back within 2
  /// seconds leaves the app.
  void _back() {
    while (navTrail.isNotEmpty) {
      final stop = navTrail.removeLast();
      // Places that are gone (a sub-tab turned off since) or where we
      // already are would make Back look dead: skip them.
      if (!_stillThere(stop)) continue;
      if (stop.page == null && _isHere(stop)) continue;
      if (stop.tab != _index) _select(stop.tab, record: false);
      if (stop.tab == 0 && stop.sub != null) {
        expensesSubTabRequest.value = stop.sub;
      }
      final page = stop.page;
      if (page != null) {
        // The page left by a tab jump, back over its tab. Categories may
        // change there (nobody else waits for it to close now).
        final ep = context.read<ExpenseProvider>();
        final ip = context.read<IncomeProvider>();
        Navigator.of(context).push(MaterialPageRoute(builder: page)).then((_) {
          ep.loadCategories();
          ip.loadCategories();
        });
      }
      return;
    }
    final now = DateTime.now();
    final asked = _exitAskedAt;
    if (asked != null && now.difference(asked) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _exitAskedAt = now;
    showAppNotice(
      context,
      AppLocalizations.of(context)!.backAgainToExit,
      duration: const Duration(seconds: 2),
    );
  }

  bool _isHere(NavStop s) =>
      s.tab == _index &&
      (s.tab != 0 || s.sub == null || s.sub == expensesSubTab);

  bool _stillThere(NavStop s) {
    if (s.tab != 0 || s.sub == null) return true;
    final sp = context.read<SettingsProvider>();
    return switch (s.sub) {
      'incoming' => sp.tabUpcoming,
      'debts' => sp.tabDebts,
      'sms' => sp.tabSms,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: BankPendingAdd(
        child: Scaffold(
          // ✅ Lets the body paint under the BottomAppBar; makes the notch truly see-through.
          extendBody: true,
          // Pages have no inline text fields; resizing them for the keyboard of
          // an add sheet just relayouts the whole tab every keyboard frame.
          resizeToAvoidBottomInset: false,

          body: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < pages.length; i++)
                // Hidden tabs keep their state but run no animations.
                TickerMode(
                  enabled: i == _index,
                  child: _visited.contains(i)
                      ? pages[i]
                      : const SizedBox.shrink(),
                ),
            ],
          ),

          bottomNavigationBar: ValueListenableBuilder<AddSheet>(
            valueListenable: expensesAdds,
            builder: (_, adds, _) => AppBottomBar(
              selected: _index,
              onTab: _select,
              onAdd: _add,
              // Off the Expenses tab, "+" adds an entry.
              adds: _index == 0 ? adds : AddSheet.entry,
              tipTarget: true,
            ),
          ),
        ),
      ),
    );
  }
}

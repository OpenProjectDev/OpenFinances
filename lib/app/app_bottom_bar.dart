// lib/app/app_bottom_bar.dart
// The bottom nav bar: four tabs and the center "+". MainPage shows it, and
// so do pages pushed over it that have something to add (e.g. category
// management): there a tab tap goes back to the main page on that tab, and
// the "+" adds what that page manages.

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/app/home_nav_icon.dart';
import 'package:openfinances/app/nav_icons.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';

/// The main page's current tab. Pushed pages set it (after popping back)
/// to switch tabs; MainPage listens.
final ValueNotifier<int> mainTab = ValueNotifier<int>(0);

/// Bumped when the tab already showing is tapped again: that page steps
/// back toward its start (the Expenses page: to History, then to the top
/// of the list, then to All, then to this period; the others scroll to
/// the top, [TabScrollTop]).
final ValueNotifier<int> mainTabReselected = ValueNotifier<int>(0);

/// The home icon and History's calendar: a tap on the icon isn't outside the
/// calendar (it folds it only as the last of what it does).
const Object kHomeCalendarTapGroup = 'homeCalendar';

/// Bumped on every tap of a tab (by index): its icon plays (Home's roof
/// hops, Budget's lights flash, Statistics' bars move, Settings' gear
/// turns).
final List<ValueNotifier<int>> tabTapped = List.generate(
  4,
  (_) => ValueNotifier<int>(0),
);

/// From a page pushed over MainPage: back to it, on tab [index]. [reopen]
/// builds the page being left, so Back can bring it back (it's popped here);
/// only when this really goes to another tab (the page's own tab is just
/// Back).
void goToMainTab(BuildContext context, int index, {WidgetBuilder? reopen}) {
  if (reopen != null && index != mainTab.value) {
    final here = mainTab.value;
    recordNavStop(NavStop(here, here == 0 ? expensesSubTab : null, reopen));
  }
  Navigator.of(context).popUntil((r) => r.isFirst);
  mainTab.value = index;
}

/// Scrolls [list] back to its top (no-op when it's there or not shown).
void scrollToTop(ScrollController? list) {
  if (list == null || !list.hasClients || list.offset <= 0) return;
  list.animateTo(
    0,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );
}

/// A main tab's page list: [builder] gets its controller, and tapping tab
/// [tab] again while it shows scrolls the list to the top.
class TabScrollTop extends StatefulWidget {
  const TabScrollTop({super.key, required this.tab, required this.builder});

  final int tab;
  final Widget Function(RememberedScroll list) builder;

  @override
  State<TabScrollTop> createState() => _TabScrollTopState();
}

class _TabScrollTopState extends State<TabScrollTop> {
  // Where it was left, while Settings > History > "keep place" is on.
  late final RememberedScroll _list;

  @override
  void initState() {
    super.initState();
    _list = RememberedScroll(
      'tab${widget.tab}',
      context.read<SettingsProvider>(),
    );
    mainTabReselected.addListener(_reselected);
  }

  void _reselected() {
    if (mainTab.value == widget.tab) scrollToTop(_list);
  }

  @override
  void dispose() {
    mainTabReselected.removeListener(_reselected);
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_list);
}

class AppBottomBar extends StatelessWidget {
  /// The bar's height (above the system's own bottom inset) and the "+"'s
  /// square, in the middle of it like the tabs' icons.
  static const double _height = 72, _addSquare = 48;

  /// On the main page's "+" (what the "add" tip is about). Only that bar
  /// carries it ([tipTarget]): pages pushed over the main page have bars of
  /// their own, and one key in two bars at once moved the "+" out of the
  /// main page's bar (it vanished, not even tappable, until a tab tap
  /// rebuilt it; the owner, 2026-10-26).
  static final addTipKey = GlobalKey();

  const AppBottomBar({
    super.key,
    required this.selected,
    required this.onTab,
    required this.onAdd,
    this.adds = AddSheet.entry,
    this.tipTarget = false,
  });

  /// The main page's bar: its "+" carries [addTipKey].
  final bool tipTarget;

  /// Highlighted tab (the one this screen belongs to).
  final int selected;
  final ValueChanged<int> onTab;

  /// What "+" adds here.
  final VoidCallback onAdd;

  /// The sheet [onAdd] opens (not what's preset in it): when it changes,
  /// the plus tilts ([AddNavIcon]).
  final AddSheet adds;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final labels = [l.expenses, l.budget, l.statistics, l.settings];

    // Each icon's size, and the share of it that's ink across (their images
    // have margins of their own): the gaps are measured between the inks.
    const sizes = [30.0, 30.0, 33.0, 34.0];
    const inkShare = [1.0, 470 / 512, 470 / 512, 480 / 512];

    Widget tab(int i) {
      final color = i == selected ? context.primaryInk : cs.onSurfaceVariant;
      // Icon-only; the label survives as screen-reader text (and a tooltip,
      // see [tappable]).
      return Center(
        // The icon may be wider than its ink's slot: it overhangs it.
        child: OverflowBox(
          maxWidth: double.infinity,
          child: Semantics(
            label: labels[i],
            child: ValueListenableBuilder<int>(
              valueListenable: tabTapped[i],
              builder: (_, n, _) => switch (i) {
                0 => HomeNavIcon(color: color, size: sizes[0], bounce: n),
                1 => BudgetNavIcon(color: color, size: sizes[1], bounce: n),
                2 => StatsNavIcon(color: color, size: sizes[2], bounce: n),
                _ => SettingsNavIcon(color: color, size: sizes[3], bounce: n),
              },
            ),
          ),
        ),
      );
    }

    // A tab's whole slot (its icon and the gaps around it) takes the tap.
    Widget tappable(int i, Widget child) {
      final tab = Semantics(
        button: true,
        label: labels[i],
        child: InkWell(
          onTap: () {
            tabTapped[i].value++;
            onTab(i);
          },
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      );
      return i == 0
          ? TapRegion(groupId: kHomeCalendarTapGroup, child: tab)
          : tab;
    }

    // The "+": its square (69% of its box) in the theme color, the plus on
    // it in the bar's own color.
    const addBox = _addSquare / (352 / 512);
    final add = SizedBox.square(
      key: tipTarget ? addTipKey : null,
      dimension: addBox,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onAdd,
        child: Semantics(
          button: true,
          label: l.addExpenseTitle,
          child: AddNavIcon(
            adds: adds,
            size: addBox,
            color: cs.primary,
            // The plus in the bar's color (a cut-out look), unless that
            // doesn't read on the theme color (a pale one in light mode).
            plusColor: contrastOf(cs.surfaceContainerHigh, cs.primary) >= 3
                ? cs.surfaceContainerHigh
                : onColor(cs.primary),
          ),
        ),
      ),
    );

    final bottom = MediaQuery.paddingOf(context).bottom;
    // Its own layer: the page scrolling under it doesn't repaint it, nor
    // its icons' animations the page.
    return RepaintBoundary(
      child: ColoredBox(
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox(
            height: _height,
            child: LayoutBuilder(
              builder: (context, box) {
                // The five inks in a row, the same gap between each two
                // and at both ends.
                final inks = [
                  sizes[0] * inkShare[0],
                  sizes[1] * inkShare[1],
                  _addSquare,
                  sizes[2] * inkShare[2],
                  sizes[3] * inkShare[3],
                ];
                final gap =
                    (box.maxWidth - inks.fold(0.0, (a, b) => a + b)) / 6;
                Widget slot(int k, Widget child) => Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: k == 0 ? gap : gap / 2,
                    end: k == 4 ? gap : gap / 2,
                  ),
                  child: SizedBox(width: inks[k], child: child),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (k, i) in [
                      (0, 0),
                      (1, 1),
                      (2, -1),
                      (3, 2),
                      (4, 3),
                    ])
                      // The "+" overhangs its square's slot (its box
                      // is wider than its ink).
                      i < 0
                          ? slot(
                              k,
                              // Loose both ways: the box may be
                              // wider than the slot and shorter or
                              // taller than the bar (a min above the
                              // max is an invalid layout).
                              OverflowBox(
                                minWidth: 0,
                                maxWidth: addBox,
                                minHeight: 0,
                                maxHeight: addBox,
                                child: add,
                              ),
                            )
                          : tappable(i, slot(k, tab(i))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One place to come back to: a main tab, on the Expenses tab its sub-tab
/// (History / Upcoming / Debts / SMS, by name), and [page] when the user was
/// on a page pushed over it (Back pushes it again).
class NavStop {
  const NavStop(this.tab, [this.sub, this.page]);

  final int tab;
  final String? sub;
  final WidgetBuilder? page;

  bool samePlace(NavStop o) => tab == o.tab && sub == o.sub;
}

/// Where the user has been on the main page, oldest first, the last 10:
/// Back walks it back (see MainPage).
final List<NavStop> navTrail = [];

/// The Expenses page's current sub-tab (it keeps this up to date).
String expensesSubTab = 'history';

/// Remembers [stop] as a place to come back to. The same place again adds
/// nothing (nor does the main page under a pushed page just remembered).
void recordNavStop(NavStop stop) {
  if (navTrail.isNotEmpty &&
      navTrail.last.samePlace(stop) &&
      stop.page == null) {
    return;
  }
  navTrail.add(stop);
  if (navTrail.length > 10) navTrail.removeAt(0);
}

/// Back asks the Expenses page for one of its sub-tabs (by name).
final ValueNotifier<String?> expensesSubTabRequest = ValueNotifier(null);

/// An entry to show in History (Statistics' day preview, a row tapped):
/// History goes to its day in the calendar, scrolls the entry into view
/// and lights it a moment. Taken (set back to null) by History.
final ValueNotifier<HistoryFocus?> historyFocusRequest = ValueNotifier(null);

class HistoryFocus {
  const HistoryFocus({required this.gid, required this.day});

  /// The entry's id, and its day (a local date).
  final String gid;
  final DateTime day;
}

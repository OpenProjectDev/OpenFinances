// FoldSection (lib/shared/ui/fold_section.dart): opening a section closes
// its start-closed siblings (not its parent, not start-open ones), and an
// opened section brings itself into view. ScrollChain: an inner list at its
// end scrolls the page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/scroll_chain.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _rows(int n) =>
    Column(children: [for (var i = 0; i < n; i++) const SizedBox(height: 50)]);

void main() {
  late SettingsProvider settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsProvider();
    await settings.ready;
  });

  Widget app(Widget body, {ScrollController? controller}) =>
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(home: Scaffold(body: body)),
      );

  FoldSectionState state(WidgetTester t, String id) =>
      t.state(find.byWidgetPredicate((w) => w is FoldSection && w.id == id));

  Future<void> tapTitle(WidgetTester t, String title) async {
    await t.tap(find.text(title));
    await t.pumpAndSettle();
  }

  bool isOpen(WidgetTester t, String id) =>
      find
          .descendant(
            of: find.byWidgetPredicate((w) => w is FoldSection && w.id == id),
            matching: find.byType(SizeTransition),
          )
          .evaluate()
          .isNotEmpty &&
      t
              .widget<SizeTransition>(
                find
                    .descendant(
                      of: find.byWidgetPredicate(
                        (w) => w is FoldSection && w.id == id,
                      ),
                      matching: find.byType(SizeTransition),
                    )
                    .first,
              )
              .sizeFactor
              .value ==
          1;

  testWidgets('opening one closes the siblings that start closed', (t) async {
    await t.pumpWidget(
      app(
        ListView(
          children: [
            FoldSection(
              id: 't.a',
              title: 'A',
              children: [
                _rows(2),
                FoldSection(id: 't.a.inner', title: 'Inner', child: _rows(1)),
                FoldSection(id: 't.a.inner2', title: 'Inner2', child: _rows(1)),
              ],
            ),
            FoldSection(id: 't.b', title: 'B', child: _rows(2)),
            FoldSection(
              id: 't.c',
              title: 'C',
              initiallyOpen: true,
              child: _rows(2),
            ),
          ],
        ),
      ),
    );
    await tapTitle(t, 'A');
    expect(isOpen(t, 't.a'), isTrue);
    // Inside A: its own group; A stays open.
    await tapTitle(t, 'Inner');
    await tapTitle(t, 'Inner2');
    expect(isOpen(t, 't.a'), isTrue);
    expect(isOpen(t, 't.a.inner'), isFalse);
    expect(isOpen(t, 't.a.inner2'), isTrue);
    // B opens: A (starts closed) closes; C (starts open) stays.
    await tapTitle(t, 'B');
    expect(isOpen(t, 't.b'), isTrue);
    expect(isOpen(t, 't.a'), isFalse);
    expect(isOpen(t, 't.c'), isTrue);
    expect(state(t, 't.b').mounted, isTrue);
  });

  testWidgets('an opened section comes into view, its top first', (t) async {
    t.view.physicalSize = const Size(400, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final list = ScrollController();
    await t.pumpWidget(
      app(
        ListView(
          controller: list,
          children: [
            const SizedBox(height: 480),
            FoldSection(id: 't.small', title: 'Small', child: _rows(3)),
            FoldSection(id: 't.big', title: 'Big', child: _rows(30)),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tapTitle(t, 'Small');
    final small = t.getRect(
      find.byWidgetPredicate((w) => w is FoldSection && w.id == 't.small'),
    );
    expect(small.bottom, lessThanOrEqualTo(600));
    expect(small.top, greaterThanOrEqualTo(0));

    // Taller than the view: its top shows. (Opened as a tap would; its
    // title is at the screen's edge. Not awaited: it's pumped.)
    state(t, 't.big').open();
    await t.pumpAndSettle();
    final big = t.getRect(
      find.byWidgetPredicate((w) => w is FoldSection && w.id == 't.big'),
    );
    expect(big.top, inInclusiveRange(0, 16));
  });

  testWidgets('an inner list at its end scrolls the page on', (t) async {
    t.view.physicalSize = const Size(400, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final page = ScrollController();
    final inner = ScrollController();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            children: [
              const SizedBox(height: 100),
              SizedBox(
                height: 200,
                child: ScrollChain(
                  child: SingleChildScrollView(
                    controller: inner,
                    child: const SizedBox(height: 400),
                  ),
                ),
              ),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );
    // 200 to the inner list's end, then 150 more for the page.
    await t.dragFrom(const Offset(200, 200), const Offset(0, -380));
    await t.pump();
    expect(inner.offset, 200);
    expect(page.offset, greaterThan(100));
  });

  // "Keep folds" off: a page change puts every section back as it starts
  // (the owner, 2026-10-26); on, they stay as left.
  testWidgets('a page change resets the sections unless kept', (t) async {
    await t.pumpWidget(
      app(
        ListView(
          children: [
            FoldSection(id: 'r.a', title: 'RA', child: _rows(1)),
            FoldSection(
              id: 'r.b',
              title: 'RB',
              initiallyOpen: true,
              child: _rows(1),
            ),
          ],
        ),
      ),
    );
    await tapTitle(t, 'RA'); // opens A
    await tapTitle(t, 'RB'); // closes B
    expect(isOpen(t, 'r.a'), isTrue);
    expect(isOpen(t, 'r.b'), isFalse);
    await settings.setRememberSections(true);
    FoldSection.resetUnlessKept(settings);
    await t.pumpAndSettle();
    expect(isOpen(t, 'r.a'), isTrue);
    await settings.setRememberSections(false);
    FoldSection.resetUnlessKept(settings);
    await t.pumpAndSettle();
    expect(isOpen(t, 'r.a'), isFalse);
    expect(isOpen(t, 'r.b'), isTrue);
  });

  // "Keep place" off: a page change puts the lists back at their tops (the
  // owner, 2026-10-26); on (the default), they stay where they were.
  testWidgets('a page change scrolls lists to the top unless kept', (t) async {
    expect(settings.rememberScroll, isTrue);
    final list = RememberedScroll('t.list', settings);
    addTearDown(list.dispose);
    await t.pumpWidget(app(ListView(controller: list, children: [_rows(40)])));
    list.jumpTo(600);
    await t.pump();
    RememberedScroll.toTopUnlessKept(settings);
    await t.pump();
    expect(list.offset, 600);
    await settings.setRememberScroll(false);
    RememberedScroll.toTopUnlessKept(settings);
    await t.pump();
    expect(list.offset, 0);
    // (Its spot is saved once it settles.)
    await t.pump(const Duration(milliseconds: 500));
  });
}

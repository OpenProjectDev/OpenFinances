// A part growing inside a section brings the SECTION into view, with a gap
// under it (the owner, 2026-11-02: only the part was measured, and the
// section's end landed on the bottom bar, the next section just out of view).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/shared/ui/fold_section.dart';
import 'package:openfinances/shared/ui/keep_in_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _gap = 16;
const double _bar = 80;

class _Page extends StatefulWidget {
  const _Page({required this.above});
  final double above;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int? day;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(padding: const EdgeInsets.only(bottom: _bar)),
    child: Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: widget.above),
          FoldSection(
            id: 'test.read',
            title: 'read',
            initiallyOpen: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => setState(() => day = 1),
                  child: const Text('pick'),
                ),
                AnimatedSize(
                  duration: kSectionAnim,
                  alignment: Alignment.topCenter,
                  child: KeepShown(
                    trigger: day,
                    gapBelow: _gap,
                    child: SizedBox(height: day == null ? 0 : 200),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          const FoldSection(
            id: 'test.next',
            title: 'next',
            initiallyOpen: true,
            child: SizedBox(height: 900),
          ),
        ],
      ),
    ),
  );
}

void main() {
  Future<void> open(WidgetTester t, double above) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late SettingsProvider sp;
    await t.runAsync(() async {
      SharedPreferences.setMockInitialValues({'rememberScroll': false});
      sp = SettingsProvider();
      await sp.ready;
    });
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: sp,
        child: MaterialApp(home: _Page(above: above)),
      ),
    );
    await t.pump();
    await t.tap(find.text('pick'));
    await t.pumpAndSettle();
  }

  double bottomOf(WidgetTester t, String id) => t
      .getBottomLeft(
        find.byWidgetPredicate((w) => w is FoldSection && w.id == id),
      )
      .dy;

  testWidgets('the section shows whole, the gap under it, the next one out', (
    t,
  ) async {
    await open(t, 500);
    final visible = 800 - _bar;
    expect(bottomOf(t, 'test.read'), closeTo(visible - _gap, 1));
    expect(t.getTopLeft(find.text('next')).dy, greaterThanOrEqualTo(visible));
  });

  testWidgets('short of room: what grows keeps its top in view', (t) async {
    await open(t, 620);
    expect(t.getTopLeft(find.text('pick')).dy, greaterThanOrEqualTo(0));
  });
}

// A sheet whose content scrolls (a form with the keyboard up, a long list)
// can still be pulled down to close (SheetPull, in every KeyboardInset).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';

void main() {
  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => KeyboardInset(
                child: SizedBox(
                  height: 400,
                  child: ListView(
                    children: [
                      for (var i = 0; i < 40; i++)
                        SizedBox(height: 50, child: Text('row $i')),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
  }

  testWidgets('pulled down far from the top, it closes', (t) async {
    await open(t);
    await t.drag(find.text('row 2'), const Offset(0, 220));
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });

  testWidgets('pulled a little, it settles back', (t) async {
    await open(t);
    final before = t.getTopLeft(find.text('row 0'));
    final g = await t.startGesture(t.getCenter(find.text('row 2')));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 6));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(t.getTopLeft(find.text('row 0')).dy, greaterThan(before.dy));
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
    expect(t.getTopLeft(find.text('row 0')), before);
  });

  testWidgets('scrolled down, a pull scrolls the list first', (t) async {
    await open(t);
    await t.drag(find.text('row 5'), const Offset(0, -300));
    await t.pumpAndSettle();
    await t.drag(find.text('row 10'), const Offset(0, 150));
    await t.pumpAndSettle();
    expect(find.text('row 10'), findsOneWidget); // still open
  });
}

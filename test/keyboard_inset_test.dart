// Typing in a form scrolled down, with the keyboard up, keeps the form
// still. KeyboardInset measured the form at full height before shortening it
// above the keyboard, and the scroll position was clamped in between: the
// form jumped up and slid back on every letter (found by OpenTracker in the
// code it took from here, 2026-11-10).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/keyboard_inset.dart';

void main() {
  testWidgets('typing in the last field of a scrolled form, it stays put', (
    t,
  ) async {
    t.view.physicalSize = const Size(384 * 3, 832 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final fields = List.generate(10, (_) => TextEditingController());
    addTearDown(() {
      for (final c in fields) {
        c.dispose();
      }
    });
    // Built once and reused, as the sheets do.
    final form = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in fields)
            SizedBox(height: 70, child: TextField(controller: c)),
        ],
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: KeyboardInset(child: form),
          ),
        ),
      ),
    );
    await t.showKeyboard(find.byType(TextField).last);
    // The keyboard comes up: 700 of form, 532 of room.
    t.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    await t.pumpAndSettle();

    final position = t
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    // Scrolled down to the field being typed in.
    position.jumpTo(position.maxScrollExtent);
    await t.pumpAndSettle();
    final before = position.pixels;
    expect(before, greaterThan(0), reason: 'the form is scrolled down');
    var text = '';
    for (final letter in 'abc'.split('')) {
      text += letter;
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
      for (var frame = 0; frame < 6; frame++) {
        await t.pump(const Duration(milliseconds: 50));
        expect(
          position.pixels,
          closeTo(before, .5),
          reason: 'after "$text", frame $frame',
        );
      }
    }
  });
}

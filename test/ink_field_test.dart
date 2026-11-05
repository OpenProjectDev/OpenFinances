import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';

void main() {
  // The placeholder comes and goes as the field fills and empties; the field
  // itself must stay the same one, or it loses focus (the keyboard closes).
  testWidgets('InkField keeps focus at the first letter and the last erased', (
    t,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => InkField(
              controller: controller,
              hint: 'Title',
              builder: (shown) => TextField(
                controller: controller,
                focusNode: focus,
                decoration: entryFieldDecoration(context, shown: shown),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(TextField));
    await t.pump();
    expect(focus.hasFocus, isTrue);
    final field = t.state(find.byType(EditableText));

    await t.enterText(find.byType(TextField), 'a');
    await t.pump();
    expect(focus.hasFocus, isTrue, reason: 'after the first letter');
    expect(t.state(find.byType(EditableText)), same(field));

    await t.enterText(find.byType(TextField), '');
    await t.pump();
    expect(focus.hasFocus, isTrue, reason: 'after erasing it');
    expect(t.state(find.byType(EditableText)), same(field));
  });
}

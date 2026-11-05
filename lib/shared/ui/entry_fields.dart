// lib/shared/ui/entry_fields.dart
// Pieces of the add/edit sheets' fields: the faint centered placeholder
// decoration, the red clear button, and the suggestion chip row.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/shared/ui/split_chip.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/app/theme.dart';
import 'package:provider/provider.dart';

import 'package:openfinances/data/settings_provider.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/date_picker.dart';
import 'package:openfinances/shared/money_input.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/haptics.dart';

/// Space between a sheet's sections, and between rows inside one (every
/// add/edit sheet uses these).
const double kSheetSectionGap = 28.8;
const double kSheetRowGap = 8;

/// A sheet's heading (its title, or whose it is and its amount): read at a
/// glance, with air under it before the form (the owner, 2026-10-25: 16
/// with a row gap was too small and tight).
const double kSheetTitleSize = 18;
const double kSheetTitleGap = 16;

/// A payment sheet's heading: whose it is at the start; its amount at the
/// end, and at the very edge what that amount is, in a chip (a debt's
/// "Total": not what's left; the owner, 2026-10-25), all centered on one
/// line. The sheets a tap on a row opens (not the editors) start it with a
/// red close square instead of a Cancel button ([onClose]; the owner,
/// 2026-10-25).
class SheetAmountHeader extends StatelessWidget {
  const SheetAmountHeader({
    super.key,
    required this.title,
    this.amount,
    this.onEdit,
    this.onClose,
  });

  final String title;

  /// Already formatted (digits in the user's language); none: just the
  /// title.
  final String? amount;

  /// The red close square at the row's start.
  final VoidCallback? onClose;

  /// An edit square (the pencil) right after the close square, before the
  /// title (the owner, 2026-10-27; the pay sheets: what it pays is edited
  /// from there).
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Close, Edit, then the title.
    final titleRow = Row(
      children: [
        if (onClose != null) ...[
          SheetCloseChip(onTap: onClose!),
          const SizedBox(width: 10),
        ],
        if (onEdit != null) ...[
          EditSquare(onTap: onEdit!, background: scheme.surfaceContainerHigh),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: InkText(
            title,
            style: const TextStyle(
              fontSize: kSheetTitleSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    if (amount == null) return titleRow;
    // The amount, a row of its own (beside it the title had little room: the
    // owner, 2026-11-02), in a simple chip (no word by it, no second tone: the
    // owner, 2026-11-03).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleRow,
        const SizedBox(height: kSheetTitleGap),
        Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkText(
            amount!,
            style: const TextStyle(
              fontSize: kSheetTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// The pencil in a square (no word; the owner, 2026-10-26): edits what it
/// sits by (a pay sheet's debt or item, a budget), as tall as the chips
/// beside it.
class EditSquare extends StatelessWidget {
  const EditSquare({
    super.key,
    required this.onTap,
    required this.background,
    this.addLabel,
  });
  final VoidCallback onTap;
  final Color background;

  /// Nothing to edit yet: a plus instead of the pencil, saying this (the owner,
  /// 2026-11-04: a category with no budget).
  final String? addLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: addLabel ?? AppLocalizations.of(context)!.edit,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: addLabel == null
            ? ImageIcon(AppIcons.edit, size: 15, color: context.primaryInk)
            // In the text's color: in the theme's it would read as the bottom
            // bar's "+", which adds an entry.
            : CustomPaint(
                size: const Size.square(14),
                painter: _PlusPainter(Theme.of(context).colorScheme.onSurface),
              ),
      ),
    ),
  );
}

/// The plus of the bottom bar's "+" (its bars 212 long and 32 thick, round
/// ended), filling its box.
class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final thick = size.width * 32 / 212;
    final mid = size.width / 2, end = size.width - thick / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(thick / 2, mid), Offset(end, mid), paint);
    canvas.drawLine(Offset(mid, thick / 2), Offset(mid, end), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}

/// A red square with an x: closes the sheet it heads ([SheetAmountHeader]),
/// as tall as the chips beside it.
class SheetCloseChip extends StatelessWidget {
  const SheetCloseChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppLocalizations.of(context)!.close,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kStrongRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const ImageIcon(AppIcons.close, size: 14, color: Colors.white),
      ),
    ),
  );
}

/// A sheet row in two parts, a little apart ([SplitChip]): [label] at the
/// start on a lighter step, [child] centered in the rest (the debt pay sheet's Remaining and
/// repayment date). [labelWidth]: the same for rows that stack, so their
/// values line up.
class SheetSplitRow extends StatelessWidget {
  const SheetSplitRow({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.labelWidth,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final double? labelWidth;

  /// The label's style (to measure [labelWidth] with).
  static TextStyle labelStyle(BuildContext context) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  /// The width that holds each of [labels] (and its padding).
  static double widthFor(BuildContext context, List<String> labels) {
    final style = DefaultTextStyle.of(context).style.merge(labelStyle(context));
    var w = 0.0;
    for (final t in labels) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (tp.width > w) w = tp.width;
    }
    return w.ceilToDouble() + 2 * 14;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SplitChip(
        height: 50,
        parts: [
          Container(
            width: labelWidth,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: InkText(label, maxLines: 1, style: labelStyle(context)),
          ),
          Expanded(
            child: ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cancel buttons are red everywhere (white text), keeping [base]'s shape
/// and size.
ButtonStyle cancelButtonStyle([ButtonStyle? base]) =>
    (base ?? const ButtonStyle()).copyWith(
      backgroundColor: const WidgetStatePropertyAll(kStrongRed),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );

/// Save, and every button that confirms a sheet (Save changes, Pay, Done,
/// …), is filled in the app's color everywhere, keeping [base]'s shape and
/// size: it pairs with the red Cancel beside it. Grey while it can't save
/// yet ([ready] false: something required is missing, or an edit changed
/// nothing) and while disabled. [color]: a different fill (the theme color
/// picker shows the color being picked).
ButtonStyle saveButtonStyle(
  BuildContext context, [
  ButtonStyle? base,
  bool ready = true,
  Color? color,
]) {
  final scheme = Theme.of(context).colorScheme;
  final fill = color ?? scheme.primary;
  final onFill = color == null ? context.textOnStrong : onColor(color);
  return (base ?? const ButtonStyle()).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => !ready || s.contains(WidgetState.disabled)
          ? scheme.surfaceContainerHigh
          : fill,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => !ready || s.contains(WidgetState.disabled)
          ? scheme.onSurfaceVariant.withValues(alpha: .5)
          : onFill,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

/// A date button's padding ([height] tall): its calendar mark ([icon]
/// px) as far from the start as from the top and bottom, and its date
/// ([fontSize] px digits) as far from the end, measured by their ink (the
/// mark's image is 84% as tall as drawn, 2% in from its sides; digits stand
/// about .7 em tall).
/// A date in a field: before it a calendar, or, when there's a date to undo,
/// what undoes it in the app's red, in the calendar's place: the reset when the
/// field can't be empty ([reset]: back to today), the eraser when it can
/// ([clear]; the owner, 2026-11-04).
class DateFieldLabel extends StatelessWidget {
  const DateFieldLabel({
    super.key,
    required this.label,
    this.reset,
    this.clear,
  });

  final String label;
  final VoidCallback? reset, clear;

  @override
  Widget build(BuildContext context) {
    final undo = reset ?? clear;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (undo == null)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 12, end: 8),
            child: ImageIcon(AppIcons.calendar, size: 18),
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.tap(context);
              undo();
            },
            child: SizedBox(
              width: 38,
              height: 44,
              child: Center(
                child: ImageIcon(
                  reset != null ? AppIcons.undo : AppIcons.eraser,
                  size: reset != null ? 17 : 20,
                  color: kStrongRed,
                ),
              ),
            ),
          ),
        Flexible(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: InkText(
              label,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: const TextStyle(height: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A [DateFieldLabel] as a field of its own: a tap picks the date.
class SheetDateField extends StatelessWidget {
  const SheetDateField({
    super.key,
    required this.label,
    required this.style,
    required this.onTap,
    this.reset,
    this.clear,
  });

  final String label;
  final ButtonStyle style;
  final VoidCallback onTap;
  final VoidCallback? reset, clear;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: style.copyWith(
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    ),
    onPressed: onTap,
    child: DateFieldLabel(label: label, reset: reset, clear: clear),
  );
}

/// An add sheet's note: its text, whether it's open, and its focus, shared by
/// the chip at the end of the amount's row ([NoteRow]; by the title, it sat
/// over the title's suggestions) and the field under it ([NoteSection]; the
/// owner, 2026-11-04: the sheets ran too tall). Open while there's a note, or
/// from a tap on the chip until a tap outside it.
class NoteFold extends ChangeNotifier {
  NoteFold(this.controller) : open = controller.text.isNotEmpty {
    controller.addListener(_onText);
    focus.addListener(_onFocus);
  }

  final TextEditingController controller;
  final focus = FocusNode();
  Timer? _afterTap;

  /// The chip and the field: taps in either aren't "outside".
  final tapGroup = Object();
  bool open;

  void _onText() {
    if (controller.text.isNotEmpty && !open) {
      open = true;
      notifyListeners();
    }
  }

  /// Focus gone to another field: folds, the keyboard handed over.
  void _onFocus() {
    if (!focus.hasFocus) closeIfEmpty();
  }

  /// A tap outside has ended. Not folded until a field tapped has had time to
  /// take the focus: unfocusing first closes the keyboard, and the field opens
  /// it again (the owner, 2026-11-04: going from field to field it should just
  /// change, as from the title to the amount). A tap on nothing folds it here.
  void tappedOutside() {
    _afterTap?.cancel();
    _afterTap = Timer(const Duration(milliseconds: 40), closeIfEmpty);
  }

  /// The chip: opens, ready to type; empty and open, folds; with a note, to it.
  void tapChip() {
    if (open && controller.text.isEmpty) return closeIfEmpty();
    if (!open) {
      open = true;
      notifyListeners();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  void closeIfEmpty() {
    if (!open || controller.text.trim().isNotEmpty) return;
    if (focus.hasFocus) focus.unfocus();
    controller.clear();
    open = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _afterTap?.cancel();
    controller.removeListener(_onText);
    focus.removeListener(_onFocus);
    focus.dispose();
    super.dispose();
  }
}

/// [field] (the amount) and, at the end of its row, as tall as it and as wide as
/// its word, the note's chip, tinted while it's open.
class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.fold, required this.field});
  final NoteFold fold;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: field),
          const SizedBox(width: kSheetRowGap),
          TapRegion(
            groupId: fold.tapGroup,
            child: GestureDetector(
              key: const ValueKey('noteChip'),
              behavior: HitTestBehavior.opaque,
              onTap: fold.tapChip,
              child: ListenableBuilder(
                listenable: fold,
                builder: (context, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: fold.open
                        ? scheme.primary.withValues(alpha: .22)
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkText(
                    AppLocalizations.of(context)!.noteLabel,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
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

/// The note's field, under the amount's row, while [fold] is open, with the gap
/// after it; a tap outside it and the chip folds it if it's empty.
class NoteSection extends StatelessWidget {
  const NoteSection({super.key, required this.fold});
  final NoteFold fold;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: fold,
    builder: (context, _) => AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !fold.open
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: kSheetRowGap),
              child: TapRegion(
                groupId: fold.tapGroup,
                onTapUpOutside: (_) => fold.tappedOutside(),
                child: InkField(
                  controller: fold.controller,
                  hint: AppLocalizations.of(context)!.noteLabel,
                  builder: (shown) => TextField(
                    key: const ValueKey('noteField'),
                    controller: fold.controller,
                    focusNode: fold.focus,
                    minLines: 1,
                    maxLines: 3,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: entryFieldDecoration(
                      context,
                      shown: shown,
                      suffixIcon: ClearWhenFilled(
                        controller: fold.controller,
                        onClear: fold.controller.clear,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}

/// A filled field with no stroke (an error tints the fill); typed text
/// keeps the field's own alignment. Its faint, centered placeholder is
/// [InkField]'s.
///
/// [shown] is what the field holds (its controller's text): what's typed
/// moves up or down by its letters' ink ([InkMetrics]), so it sits in the
/// middle like all other text.
InputDecoration entryFieldDecoration(
  BuildContext context, {
  String? shown,
  TextStyle? textStyle,
  bool error = false,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  final noStroke = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );
  final dy = shown == null || shown.isEmpty
      ? 0.0
      : InkMetrics.instance.offset(
          shown,
          Theme.of(context).textTheme.bodyLarge!.merge(textStyle),
          MediaQuery.textScalerOf(context),
        );
  return InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.fromLTRB(14, 14 + dy, 14, 14 - dy),
    filled: true,
    fillColor: error
        ? kStrongRed.withValues(alpha: .35)
        : scheme.surfaceContainerHigh,
    border: noStroke,
    enabledBorder: noStroke,
    focusedBorder: noStroke,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    // Icons take only their own size (the clear button is 0 wide while the
    // field is empty).
    prefixIconConstraints: const BoxConstraints(),
    suffixIconConstraints: const BoxConstraints(),
  );
}

/// A field ([builder], given what it holds) that follows its text: it
/// rebuilds as it's typed in (so [entryFieldDecoration] centers what's
/// typed), and while it's empty shows [hint], faint, in the middle of the
/// field by its letters' ink. (A field's own placeholder would sit on the
/// typed text's line instead, a little off.)
class InkField extends StatelessWidget {
  const InkField({
    super.key,
    required this.controller,
    this.hint,
    required this.builder,
  });

  final TextEditingController controller;
  final String? hint;
  final Widget Function(String shown) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, InkMetrics.instance]),
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final empty = controller.text.isEmpty;
      // Always the same tree around the field (only the placeholder comes
      // and goes after it): a different one at the first letter or the
      // last erased would make a new field, which drops the focus and
      // closes the keyboard.
      return Stack(
        alignment: Alignment.center,
        children: [
          builder(controller.text),
          if (hint != null && empty)
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: InkText(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: .55),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// A red eraser, shown only while [controller] has text.
class ClearWhenFilled extends StatelessWidget {
  const ClearWhenFilled({
    super.key,
    required this.controller,
    required this.onClear,
  });
  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) {
        if (controller.text.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.tap(context);
            onClear();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            // An eraser, in the app's one red.
            child: const Center(
              child: ImageIcon(AppIcons.eraser, size: 20, color: kStrongRed),
            ),
          ),
        );
      },
    );
  }
}

/// A field's suggestion row and the gap after it, there only while the
/// field is empty or being typed in (the owner, 2026-10-25: a filled field
/// left alone needs none); otherwise just a row's gap. Its size eases.
class SuggestionsSlot extends StatelessWidget {
  const SuggestionsSlot({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.row,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget row;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, focusNode]),
    builder: (context, _) {
      final on = controller.text.trim().isEmpty || focusNode.hasFocus;
      return AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: on
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row,
                  const SizedBox(height: kSheetSectionGap),
                ],
              )
            : const SizedBox(height: kSheetRowGap, width: double.infinity),
      );
    },
  );
}

/// Horizontally scrolling chips under a field (like the category chips on
/// the Expenses page). Collapses when there's nothing to suggest.
class SuggestionChipsRow extends StatelessWidget {
  const SuggestionChipsRow({
    super.key,
    required this.labels,
    required this.onTap,
    required this.emptyText,
    this.onLongPress,
  });
  final List<String> labels;
  final ValueChanged<int> onTap;

  /// Long-pressing a chip (e.g. to stop suggesting it).
  final ValueChanged<int>? onLongPress;

  /// Shown (faint, centered) when nothing matches, so the row keeps its
  /// place instead of collapsing and shifting the form.
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 36,
        child: labels.isEmpty
            ? Center(
                child: InkText(
                  emptyText,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: .55),
                  ),
                ),
              )
            // More than fit: it shows that it scrolls ([ScrollHint]).
            : HintedScroll(
                id: ScrollHint.suggestions,
                builder: (context, scroll) => ListView.separated(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  itemCount: labels.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => onTap(i),
                    onLongPress: onLongPress == null
                        ? null
                        : () => onLongPress!(i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkText(
                        labels[i],
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Whether a suggestion of [source] is hidden: the user ignored it, or
/// turned suggestions off for the category it was last used in.
bool hiddenTitleSuggestion(
  SettingsProvider settings,
  SuggestSource source,
  String title,
  String? categoryGid,
) =>
    settings.isTitleIgnored(source, title) ||
    (categoryGid != null && settings.noSuggestCategories.contains(categoryGid));

/// Long-press on a suggestion of [source]: stop suggesting it, with undo.
void ignoreTitleSuggestion(
  BuildContext context,
  SuggestSource source,
  String title,
) {
  final l = AppLocalizations.of(context)!;
  final settings = context.read<SettingsProvider>();
  settings.ignoreTitle(source, title);
  showAppNotice(
    context,
    l.titleIgnored(title),
    kind: NoticeKind.success,
    actionLabel: l.undo,
    onAction: () => settings.unignoreTitle(source, title),
  );
}

/// "1,234.5" (any digits, separators) → minor units; null if not a number.
int? parseAmountMinor(String text) {
  final cleaned = faToEnDigits(text.trim()).replaceAll(RegExp(r'[,٬،\s]'), '');
  final d = double.tryParse(cleaned);
  return d == null ? null : (d * 100).round();
}

/// The amount field every sheet uses: the calculator button at the start
/// side (right in RTL), the field with its clear button at the end, and,
/// once something is typed, a "000" button by it (Settings > History; on in
/// Persian by default) that puts three zeros where the cursor is.
class AmountFieldRow extends StatelessWidget {
  const AmountFieldRow({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.error = false,
    this.zeros = true,
    this.onChanged,
    this.onCalculated,
    this.onFocused,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final bool error;

  /// The "000" button (when Settings has it): off for a number that isn't
  /// money (a percentage).
  final bool zeros;

  /// Typed text changed (also after clearing).
  final ValueChanged<String>? onChanged;

  /// The calculator put a result in the field.
  final VoidCallback? onCalculated;

  /// The field got focus (e.g. to scroll it into view).
  final void Function(BuildContext fieldContext)? onFocused;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Future<void> openCalculator() async {
      FocusScope.of(context).unfocus();
      final result = await showCalculatorSheet(
        context: context,
        initialValue: controller.text,
      );
      final minor = result == null ? null : parseAmountMinor(result);
      if (minor == null) return;
      final t = formatMinorWithCommas(minor);
      controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
      onCalculated?.call();
    }

    // Fixed to the field's natural height (stretching the row to match
    // pushed the field's text off center).
    final calculator = SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: openCalculator,
          child: Center(
            child: ImageIcon(
              AppIcons.calculator,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        calculator,
        const SizedBox(width: kSheetRowGap),
        Expanded(
          child: Builder(
            builder: (fieldCtx) => Focus(
              onFocusChange: (has) {
                if (has) onFocused?.call(fieldCtx);
              },
              child: InkField(
                controller: controller,
                hint: hint,
                builder: (shown) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textAlignVertical: TextAlignVertical.center,
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: rtl ? TextAlign.right : TextAlign.left,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    ThousandsSeparatorFormatter(separator: ','),
                  ],
                  onChanged: onChanged,
                  decoration: entryFieldDecoration(
                    context,
                    shown: shown,
                    error: error,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (zeros &&
                            context.watch<SettingsProvider>().quickZeros)
                          _ZerosButton(
                            controller: controller,
                            onAdded: () => onChanged?.call(controller.text),
                          ),
                        ClearWhenFilled(
                          controller: controller,
                          onClear: () {
                            controller.clear();
                            onChanged?.call('');
                            focusNode?.requestFocus();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "000" in a chip, there once the amount has something in it: three zeros
/// where the cursor is (at the end if there's none), grouped like typed
/// ones.
class _ZerosButton extends StatelessWidget {
  const _ZerosButton({required this.controller, required this.onAdded});
  final TextEditingController controller;
  final VoidCallback onAdded;

  void _add() {
    final v = controller.value;
    final sel = v.selection;
    final at = sel.isValid ? sel.end : v.text.length;
    final start = sel.isValid ? sel.start : at;
    final typed = v.text.replaceRange(start, at, '000');
    controller.value = ThousandsSeparatorFormatter(separator: ',')
        .formatEditUpdate(
          v,
          TextEditingValue(
            text: typed,
            selection: TextSelection.collapsed(offset: start + 3),
          ),
        );
    onAdded();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.text.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.tap(context);
            _add();
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              // Latin zeros in both languages: «۰۰۰» reads as three dots
              // (a "more" mark).
              child: InkText(
                '000',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Picks a date from an add/edit sheet. The keyboard goes away first and
/// stays away after: no field gets focus back when the picker closes
/// (whoever picks a date isn't about to retype the title). [pastOnly]: a
/// date isn't expected in the future; [futureOnly]: nor in the past (the
/// picker warns).
Future<DateTime?> pickSheetDate(
  BuildContext context,
  DateTime initial, {
  bool pastOnly = false,
  bool futureOnly = false,
}) async {
  // Unfocusing the scope itself leaves no field for it to hand focus back
  // to once the picker's route is gone.
  FocusScope.of(context).unfocus();
  final res = await pickDateForCalendar(
    context: context,
    initial: initial,
    calendar: context.read<SettingsProvider>().calendar,
    pastOnly: pastOnly,
    futureOnly: futureOnly,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  return res;
}

/// Cancel for an add/edit sheet: red, closes at once (what was typed is
/// kept for next time when "remember entered data" is on, [SheetDrafts]).
class CancelButton extends StatelessWidget {
  const CancelButton({super.key, required this.onCancel, this.height = 50});

  final VoidCallback onCancel;
  final double height;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: cancelButtonStyle(
      OutlinedButton.styleFrom(
        fixedSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    onPressed: onCancel,
    child: InkText(AppLocalizations.of(context)!.cancel),
  );
}

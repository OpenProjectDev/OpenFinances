import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/app_icons.dart';
import 'package:openfinances/shared/ui/joined_menu.dart';
import 'package:openfinances/shared/ui/surfaces.dart';

/// The app's compact dropdown: a 36dp tinted box as wide as it's given, its
/// menu joined to it like the category pickers' ([JoinedMenu]: the other
/// choices only, same tint, no shadow). A [leading] mark says what it picks
/// (e.g. the sort icon), pinned at the start; without one a chevron at the
/// end says it opens. Labels are centered in the space beside the mark, in
/// the button and in the menu alike, so a word never shifts. Used by the
/// Budget sort.
class TintedDropdown<T> extends StatelessWidget {
  const TintedDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.color,
    this.leading,
  });

  /// Pinned at the start (instead of the chevron at the end).
  final IconData? leading;

  final T value;

  /// value -> label, in display order.
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  /// Box tint; defaults to a step above what it sits in.
  final Color? color;

  static const double height = 36;

  /// The mark's size (its glyph fills its box) and its gap to the label.
  static const double _mark = 12, _gap = 6, _side = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? context.raised;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // From the text theme, so the app font carries into the menu too.
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    final others = [
      for (final e in items.entries)
        if (e.key != value) e,
    ];

    // A label in the room beside the mark (or before the chevron).
    Widget label(String text) => Expanded(
      child: InkText(text, textAlign: TextAlign.center, style: style),
    );
    final markSpace = leading == null
        ? const SizedBox.shrink()
        : const SizedBox(width: _mark + _gap);
    final chevronSpace = leading == null
        ? const SizedBox(width: 14 + _gap)
        : const SizedBox.shrink();

    return JoinedMenu(
      rowCount: others.length,
      rowHeight: height,
      background: tint,
      rows: (close) => [
        for (final e in others)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              close();
              onChanged(e.key);
            },
            child: Container(
              height: height,
              color: tint,
              padding: const EdgeInsets.symmetric(horizontal: _side),
              child: Row(children: [markSpace, label(e.value), chevronSpace]),
            ),
          ),
      ],
      button: (context, radius, toggle) => GestureDetector(
        onTap: toggle,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: _side),
          decoration: BoxDecoration(color: tint, borderRadius: radius),
          child: Row(
            children: [
              if (leading != null) ...[
                Transform.flip(
                  flipX: rtl,
                  child: Icon(leading, size: _mark, color: scheme.onSurface),
                ),
                const SizedBox(width: _gap),
              ],
              label(items[value] ?? ''),
              if (leading == null) ...[
                const SizedBox(width: _gap),
                ImageIcon(
                  AppIcons.chevronDown,
                  size: 14,
                  color: scheme.onSurface,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

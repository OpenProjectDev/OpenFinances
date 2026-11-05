import 'package:openfinances/shared/calendar_text.dart' show isFaUi;
import 'package:flutter/material.dart';
import 'package:openfinances/shared/ui/scroll_hint.dart';
import 'package:openfinances/app/theme.dart';
import 'package:openfinances/shared/ui/ink_text.dart';
import 'package:openfinances/shared/ui/uicons.g.dart';
import 'package:openfinances/shared/ui/app_notice.dart';
import 'package:openfinances/shared/ui/entry_fields.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/digits.dart';

/// Another category beside the colors: its [color], its icon on it
/// ([mark], given the color to draw in).
class ColorPickerCategory {
  const ColorPickerCategory(this.color, this.mark);
  final Color color;
  final Widget Function(Color ink, double size) mark;
}

/// Public, reusable color picker with 2 tabs: localized Main/Custom.
/// Returns a `Color` via `Navigator.pop(context, color)`.
class ColorPickerPage extends StatefulWidget {
  const ColorPickerPage({
    required this.initial,
    this.isThemeColor = false,
    this.mark,
    this.others = const [],
    super.key,
  });
  final Color initial;

  /// A category's color: its icon on the chosen color (instead of a check
  /// mark: a real preview; the owner, 2026-10-26).
  final Widget Function(Color ink, double size)? mark;

  /// The other categories, in a row over the buttons (both tabs): how they
  /// look, to pick a color that stands apart.
  final List<ColorPickerCategory> others;

  /// Picking the app's color: Save wears the color being picked (a preview
  /// of the new theme). Otherwise Save is in the theme color, like every
  /// Save.
  final bool isThemeColor;

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage>
    with SingleTickerProviderStateMixin {
  // Save and Cancel, sized like every sheet's action row.
  static final _actionStyle = OutlinedButton.styleFrom(
    overlayColor: Colors.transparent,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
  );
  late Color _current;

  int _to8(double c) => (c * 255.0).round() & 0xff; // 0..1 -> 0..255

  // 30 quick colors (6 rows of 5): distinct hues and tones, each one
  // usable for text on it and as a tint, from big companies' palettes
  // (Google Calendar's event colors, Apple's system colors, Microsoft
  // Fluent), in hue order: reds and pinks, oranges and yellows, greens,
  // blues, purples, then the quiet ones.
  static const List<Color> _main = [
    Color(0xFFAD1457), // Google Radicchio
    Color(0xFFD81B60), // Google Cherry blossom
    Color(0xFFFF2D55), // Apple pink
    Color(0xFFD50000), // Google Tomato
    Color(0xFFE67C73), // Google Flamingo
    Color(0xFFF4511E), // Google Tangerine
    Color(0xFFEF6C00), // Google Pumpkin
    Color(0xFFF09300), // Google Mango
    Color(0xFFF6BF26), // Google Banana
    Color(0xFFE4C441), // Google Citron
    Color(0xFFC0CA33), // Google Avocado
    Color(0xFF7CB342), // Google Pistachio
    Color(0xFF0B8043), // Google Basil
    Color(0xFF33B679), // Google Sage
    Color(0xFF0BA5A4), // teal (a new category's color)
    Color(0xFF00C7BE), // Apple mint
    Color(0xFF039BE5), // Google Peacock
    Color(0xFF0078D4), // Microsoft blue
    Color(0xFF2196F3), // Material blue (the app's default, the brand's)
    Color(0xFF3F51B5), // Google Blueberry
    Color(0xFF7986CB), // Google Lavender
    Color(0xFF5856D6), // Apple indigo
    Color(0xFFB39DDB), // Google Wisteria
    Color(0xFF9E69AF), // Google Amethyst
    Color(0xFF8E24AA), // Google Grape
    Color(0xFFB146C2), // Microsoft orchid
    Color(0xFF795548), // Google Cocoa
    Color(0xFFA2845E), // Apple brown
    Color(0xFFA79B8E), // Google Birch
    Color(0xFF616161), // Google Graphite
  ];

  // The same colors, the most chosen first: a short screen shows fewer rows
  // and leaves out the end of this list (the owner, 2026-10-26); they're
  // still shown in hue order. The clear, everyday hues come first, and the
  // muted ones and near-duplicates (a second pink, blue or brown) last.
  static const List<Color> _byPopularity = [
    Color(0xFF2196F3), // Material blue (the app's default)
    Color(0xFFD50000), // Tomato
    Color(0xFF0B8043), // Basil
    Color(0xFFF4511E), // Tangerine
    Color(0xFFF6BF26), // Banana
    Color(0xFF8E24AA), // Grape
    Color(0xFF0BA5A4), // teal (a new category's color)
    Color(0xFFD81B60), // Cherry blossom
    Color(0xFF3F51B5), // Blueberry
    Color(0xFF795548), // Cocoa
    Color(0xFF616161), // Graphite
    Color(0xFF33B679), // Sage
    Color(0xFF039BE5), // Peacock
    Color(0xFFEF6C00), // Pumpkin
    Color(0xFF7CB342), // Pistachio
    Color(0xFFE67C73), // Flamingo
    Color(0xFF7986CB), // Lavender
    Color(0xFFF09300), // Mango
    Color(0xFFFF2D55), // Apple pink
    Color(0xFF00C7BE), // Apple mint
    Color(0xFF9E69AF), // Amethyst
    Color(0xFFC0CA33), // Avocado
    Color(0xFFAD1457), // Radicchio
    Color(0xFF5856D6), // Apple indigo
    Color(0xFFB39DDB), // Wisteria
    Color(0xFFE4C441), // Citron
    Color(0xFF0078D4), // Microsoft blue
    Color(0xFFB146C2), // Microsoft orchid
    Color(0xFFA79B8E), // Birch
    Color(0xFFA2845E), // Apple brown
  ];

  /// The swatches for [count] places: the most chosen ones (and the color
  /// being edited, if it's one of them), in hue order.
  List<Color> _shown(int count) {
    if (count >= _main.length) return _main;
    final keep = _byPopularity.take(count).map((c) => c.toARGB32()).toSet();
    final cur = widget.initial.toARGB32();
    if (_main.any((c) => c.toARGB32() == cur) && !keep.contains(cur)) {
      keep
        ..remove(
          _byPopularity
              .take(count)
              .lastWhere((c) => c.toARGB32() != cur)
              .toARGB32(),
        )
        ..add(cur);
    }
    return [
      for (final c in _main)
        if (keep.contains(c.toARGB32())) c,
    ];
  }

  // Custom RGB
  late int _r, _g, _b;
  final _hexCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _r = _to8(_current.r);
    _g = _to8(_current.g);
    _b = _to8(_current.b);
    _hexCtrl.text = _toHex(_current);
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  // ---- locale digits helper (Persian for fa, otherwise Latin)
  bool get _isFa => isFaUi(context);
  String _toFaDigits(String s) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], fa[i]);
    }
    return s;
  }

  String _digits(String s) => faDigitsFor(_isFa) ? _toFaDigits(s) : s;

  /// The swatches' gap, and their size: five across the page (16 in from
  /// each side); the other categories' dots are as big.
  static const double _gap = 12;
  double _swatch(BuildContext context) =>
      (MediaQuery.sizeOf(context).width - 32 - 4 * _gap) / 5;

  String _toHex(Color c) {
    final r = _to8(c.r), g = _to8(c.g), b = _to8(c.b);
    String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${two(r)}${two(g)}${two(b)}';
  }

  bool _tryParseHex(String s) {
    final v = s.trim();
    final re = RegExp(r'^#?([0-9a-fA-F]{6})$');
    final m = re.firstMatch(v);
    if (m == null) return false;
    final hex = m.group(1)!;
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    setState(() {
      _r = r;
      _g = g;
      _b = b;
      _current = Color.fromARGB(0xFF, _r, _g, _b);
      _hexCtrl.text = _toHex(_current);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final changed = _current.toARGB32() != widget.initial.toARGB32();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: InkText(l.colorPickerTitle), // "انتخاب رنگ" / "Color picker"
          automaticallyImplyLeading: false,
          bottom: TabBar(
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l.colorPickerTabMain), // "اصلی" / "Main"
              Tab(text: l.colorPickerTabCustom), // "دلخواه" / "Custom"
            ],
          ),
        ),
        // The other categories, then Save (grey until the color changed)
        // and Cancel, at the bottom.
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.others.isNotEmpty) ...[
                  _OthersRow(others: widget.others, dot: _swatch(context)),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: saveButtonStyle(
                          context,
                          _actionStyle,
                          true,
                          widget.isThemeColor ? _current : null,
                        ),
                        onPressed: changed
                            ? () => Navigator.pop(context, _current)
                            : null,
                        child: InkText(l.save),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: cancelButtonStyle(_actionStyle),
                        onPressed: () => Navigator.pop(context),
                        child: InkText(l.cancel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // MAIN: as many rows of five as the height holds (never a
            // scroll; the other categories' row stays in view under it).
            LayoutBuilder(
              builder: (context, box) {
                final dot = _swatch(context);
                final room =
                    box.maxHeight - 16 - 24 - _PreviewSwatch.height - 16;
                final rows = ((room + _gap) / (dot + _gap)).floor().clamp(
                  1,
                  _main.length ~/ 5,
                );
                final colors = _shown(rows * 5);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      _PreviewSwatch(color: _current),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: _gap,
                              crossAxisSpacing: _gap,
                              childAspectRatio: 1,
                            ),
                        itemCount: colors.length,
                        itemBuilder: (_, i) {
                          final c = colors[i];
                          final sel = c.toARGB32() == _current.toARGB32();
                          return InkWell(
                            onTap: () => setState(() => _current = c),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: !sel
                                  ? null
                                  : widget.mark?.call(onColor(c), 24) ??
                                        Icon(UIcons.check, color: onColor(c)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            // CUSTOM
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _PreviewSwatch(color: _current),
                  const SizedBox(height: 12),
                  _RgbSlider(
                    label: 'R',
                    value: _r.toDouble(),
                    active: Colors.red,
                    digits: _digits,
                    onChanged: (v) {
                      setState(() {
                        _r = v.toInt();
                        _current = Color.fromARGB(0xFF, _r, _g, _b);
                        _hexCtrl.text = _toHex(_current);
                      });
                    },
                  ),
                  _RgbSlider(
                    label: 'G',
                    value: _g.toDouble(),
                    active: Colors.green,
                    digits: _digits,
                    onChanged: (v) {
                      setState(() {
                        _g = v.toInt();
                        _current = Color.fromARGB(0xFF, _r, _g, _b);
                        _hexCtrl.text = _toHex(_current);
                      });
                    },
                  ),
                  _RgbSlider(
                    label: 'B',
                    value: _b.toDouble(),
                    active: Colors.blue,
                    digits: _digits,
                    onChanged: (v) {
                      setState(() {
                        _b = v.toInt();
                        _current = Color.fromARGB(0xFF, _r, _g, _b);
                        _hexCtrl.text = _toHex(_current);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  InkField(
                    controller: _hexCtrl,
                    hint: l.hexLabelExample,
                    builder: (shown) => TextField(
                      controller: _hexCtrl,
                      textDirection: TextDirection.ltr, // HEX must be LTR
                      // Placeholder, not a label on the border (like every
                      // field in the app).
                      decoration: entryFieldDecoration(
                        context,
                        shown: shown,
                        suffixIcon: ClearWhenFilled(
                          controller: _hexCtrl,
                          onClear: _hexCtrl.clear,
                        ),
                      ),
                      onSubmitted: (t) {
                        final ok = _tryParseHex(t);
                        if (!ok) {
                          showAppNotice(
                            context,
                            l.invalidHexCode,
                            kind: NoticeKind.failure,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the other categories (their color, their icon on it), the
/// dots as big as the swatches: centered when they fit; else scrolling
/// sideways from the start edge, the gaps set so whole dots fill the row
/// edge to edge (no half dot: it shows that it scrolls by moving a little,
/// [ScrollHint]; the owner, 2026-10-31).
class _OthersRow extends StatelessWidget {
  const _OthersRow({required this.others, required this.dot});
  final List<ColorPickerCategory> others;
  final double dot;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: dot,
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final n = others.length;
        final fits = n * dot + (n - 1) * _gap <= w;
        // k whole dots from edge to edge: the k whose gap comes closest to
        // the usual one.
        var gap = _gap;
        if (!fits) {
          double gapFor(int k) => (w - k * dot) / (k - 1);
          final k0 = ((w + _gap) / (dot + _gap)).floor().clamp(2, n);
          final k1 = (k0 + 1).clamp(2, n);
          final g0 = gapFor(k0), g1 = gapFor(k1);
          gap = g1 >= 4 && (g1 - _gap).abs() < (g0 - _gap).abs() ? g1 : g0;
        }
        return HintedScroll(
          id: ScrollHint.colorRow,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, c) in others.indexed) ...[
                    if (i > 0) SizedBox(width: gap),
                    Container(
                      width: dot,
                      height: dot,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.color,
                        shape: BoxShape.circle,
                      ),
                      child: c.mark(onColor(c.color), 24),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _PreviewSwatch extends StatelessWidget {
  const _PreviewSwatch({required this.color});
  final Color color;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.active,
    required this.onChanged,
    required this.digits,
  });

  final String label;
  final double value;
  final Color active;
  final ValueChanged<double> onChanged;
  final String Function(String) digits;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = digits(value.toInt().toString());

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: InkText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ),
        Expanded(
          child: Slider.adaptive(
            min: 0,
            max: 255,
            divisions: 255,
            value: value.clamp(0, 255).toDouble(),
            onChanged: onChanged,
            activeColor: active,
          ),
        ),
        SizedBox(width: 44, child: InkText(shown, textAlign: TextAlign.center)),
      ],
    );
  }
}

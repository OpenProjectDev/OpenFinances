// lib/shared/ui/ink_text.dart
// Text whose letters sit in the middle of their box, whatever the font.
//
// A font's line box isn't centered on its letters: Shabnam leaves room
// below the line for Persian letters that dip, while digits and Latin
// letters sit high; another font (the user may pick the device's) does it
// its own way. So every font in use is measured once, character by
// character (each Persian letter in each of its joined forms), and a text
// is moved so its script's band sits in the middle: Latin letters and
// digits from the line up to a capital's top, Persian letters from the
// bottom of a «ر»'s tail up to an «ا»'s top (both, in a text with both). The
// band is the font's, not the text's: every word in one font and size sits
// on one line
// (the owner, 2026-10-26: by each word's own ink, "Budget", its «g»
// dipping, sat higher than "Desc" beside it, and «مدیریت» high). A text of
// signs only (a calculator's keys) is centered by its own ink. Icons need
// nothing: their glyphs are centered in the icon fonts (tool/gen_uicons.py)
// and the PNGs in their frames.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One character's ink, in ems above the baseline: its top and bottom, its
/// weight (ink area, ems²) and where that weight sits; and the line box its
/// font gives it.
class _Glyph {
  const _Glyph(
    this.top,
    this.bottom,
    this.mass,
    this.centroid,
    this.ascent,
    this.descent,
  );
  final double top, bottom, mass, centroid, ascent, descent;
}

/// Persian / Arabic letters that join only to the letter before them.
const String _rightJoining = 'اآأإٱدذرزژوؤة';

/// Letters that join on both sides (and the kashida).
const String _dualJoining = 'بپتثجچحخسشصضطظعغفقکكگلمنهیيئـ';

final Set<int> _dualSet = _dualJoining.runes.toSet();
final Set<int> _letterSet = {..._dualSet, ..._rightJoining.runes};

bool _joinsNext(int c) => _dualSet.contains(c);

bool _isLetter(int c) => _letterSet.contains(c);

/// Vowel marks: no say in joining.
bool _transparent(int c) => c >= 0x064B && c <= 0x065F || c == 0x0670;

const int _zwj = 0x200D;

/// What's measured: printable ASCII, Persian and Arabic digits and marks,
/// some symbols, and every letter in each form ('i'nitial, 'm'edial,
/// 'f'inal; isolated is the letter alone). A form is drawn joined to a
/// kashida painted clear ([_joiner]: a zero-width joiner after a letter
/// doesn't give its initial form in every font).
List<(String key, String text)> _sampleSet() {
  final out = <(String, String)>[];
  for (var c = 0x21; c <= 0x7E; c++) {
    final s = String.fromCharCode(c);
    out.add((s, s));
  }
  for (final s in '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩،؛؟«»٫٬٪−×÷·•…–—‘’“”€ءـ'.split('')) {
    out.add((s, s));
  }
  const j = _joiner;
  for (final s in (_dualJoining + _rightJoining).split('')) {
    if (s == 'ـ') continue;
    out.add((s, s));
    out.add(('$s|f', '$j$s'));
    if (_dualJoining.contains(s)) {
      out.add(('$s|i', '$s$j'));
      out.add(('$s|m', '$j$s$j'));
    }
  }
  return out;
}

/// Stands for a clear kashida in a sample (drawn as one, not seen).
const String _joiner = '';

/// [text] as drawn: its [_joiner]s as kashidas no one sees.
TextSpan _sampleSpan(String text, TextStyle style) => TextSpan(
  style: style,
  children: [
    for (final part in text.split(''))
      part == _joiner
          ? const TextSpan(
              text: 'ـ',
              style: TextStyle(color: Color(0x00000000)),
            )
          : TextSpan(text: part),
  ],
);

/// The key a text's character at [i] was measured under: a letter by the
/// form it takes there (joined to its neighbours or not).
String? _keyAt(List<int> runes, int i) {
  final c = runes[i];
  if (!_isLetter(c)) return String.fromCharCode(c);
  bool before() {
    for (var k = i - 1; k >= 0; k--) {
      final p = runes[k];
      if (_transparent(p)) continue;
      return p == _zwj || _joinsNext(p);
    }
    return false;
  }

  bool after() {
    if (!_joinsNext(c)) return false;
    for (var k = i + 1; k < runes.length; k++) {
      final n = runes[k];
      if (_transparent(n)) continue;
      return n == _zwj || _isLetter(n);
    }
    return false;
  }

  final s = String.fromCharCode(c);
  final b = before(), a = after();
  return b && a
      ? '$s|m'
      : b
      ? '$s|f'
      : a
      ? '$s|i'
      : s;
}

/// The measured fonts, and how far a text must move to sit centered.
class InkMetrics extends ChangeNotifier {
  InkMetrics._();
  static final InkMetrics instance = InkMetrics._();

  final Map<String, Map<String, _Glyph>> _fonts = {};
  final Set<String> _measuring = {};

  /// Recent texts' ink (center, ascent, descent in ems), per font.
  /// Per font, by text. Trimmed by its oldest quarter when it grows big.
  final Map<String, Map<String, (double, double, double)?>> _texts = {};

  static String _key(TextStyle s) =>
      '${s.fontFamily}|${(s.fontFamilyFallback ?? const []).join(',')}';

  /// Measures the font of [style] (family and fallbacks) unless known.
  /// Awaited at startup for the app's fonts, so the first frame has them.
  Future<void> prepare(TextStyle style) async {
    final key = _key(style);
    if (_fonts.containsKey(key) || !_measuring.add(key)) return;
    try {
      _fonts[key] = await _measure(style);
      notifyListeners();
    } catch (_) {
      // Unmeasurable (e.g. no rendering in tests): drawn as it comes.
    } finally {
      _measuring.remove(key);
    }
  }

  /// Where [text]'s middle is in [font] (ems above the baseline), and its
  /// line box. With letters or digits: the middle of its scripts' bands
  /// (see the top of this file). Signs only: halfway between the middle of
  /// their ink's bounds and its weight (a long tail or a dot pulls the
  /// first, not the second). Null: nothing in it was measured (e.g. emoji
  /// only).
  static (double, double, double)? _ink(String text, Map<String, _Glyph> font) {
    final runes = text.runes.toList();
    final band = _band(runes, font);
    double? top, bottom;
    var mass = 0.0, moment = 0.0, ascent = 0.0, descent = 0.0;
    for (var i = 0; i < runes.length; i++) {
      final g = font[_keyAt(runes, i)];
      if (g == null) continue;
      if (top == null || g.top > top) top = g.top;
      if (bottom == null || g.bottom < bottom) bottom = g.bottom;
      mass += g.mass;
      moment += g.mass * g.centroid;
      // The line takes the tallest of its fonts.
      if (g.ascent > ascent) ascent = g.ascent;
      if (g.descent > descent) descent = g.descent;
    }
    if (top == null || bottom == null || mass == 0) return null;
    if (band != null) return ((band.$1 + band.$2) / 2, ascent, descent);
    // A decimal point or comma alone (a calculator key) sits where it would
    // after a digit, not in the middle like a "·".
    if (runes.every((c) => '.,٫٬،'.contains(String.fromCharCode(c)))) {
      final zero = font['0'];
      if (zero != null) {
        return (
          ((zero.top + zero.bottom) / 2 + zero.centroid) / 2,
          ascent,
          descent,
        );
      }
    }
    return (((top + bottom) / 2 + moment / mass) / 2, ascent, descent);
  }

  /// The band (top, bottom; ems above the baseline) of the scripts in
  /// [runes]: Latin letters and digits from the baseline to «H»'s top,
  /// Persian digits to «۱»'s, Persian letters from the bottom of «ر»'s
  /// tail to «ا»'s top; several: all of them. Null: no letter or digit (or the font lacks
  /// the measuring letters).
  static (double, double)? _band(List<int> runes, Map<String, _Glyph> font) {
    var latin = false, faDigit = false, fa = false;
    for (final c in runes) {
      if (c >= 0x30 && c <= 0x39 ||
          c >= 0x41 && c <= 0x5A ||
          c >= 0x61 && c <= 0x7A) {
        latin = true;
      } else if (c >= 0x6F0 && c <= 0x6F9 || c >= 0x660 && c <= 0x669) {
        faDigit = true;
      } else if (_isLetter(c)) {
        fa = true;
      }
    }
    double? top, bottom;
    void take(String high, double? low) {
      final g = font[high];
      if (g == null) return;
      final b = low ?? 0;
      if (top == null || g.top > top!) top = g.top;
      if (bottom == null || b < bottom!) bottom = b;
    }

    if (latin) take('H', null);
    if (faDigit) take('۱', null);
    // All of the tail counts. (Half of it was tuned while the line's middle
    // was measured wrong, [_lineMiddle]; with that fixed, the whole of it
    // centers Persian words, as test/ink_center_test.dart checks.)
    if (fa) take('ا', font['ر']?.bottom ?? 0);
    final t = top, b = bottom;
    return t == null || b == null ? null : (t, b);
  }

  /// How tall [text]'s letters are in [style] (logical px, from its
  /// highest ink to its lowest); null until its font is measured.
  double? inkHeight(String text, TextStyle style, TextScaler scaler) {
    final fontSize = style.fontSize;
    final font = _fonts[_key(style)];
    if (fontSize == null || font == null) {
      if (font == null) prepare(style);
      return null;
    }
    final runes = text.runes.toList();
    double? top, bottom;
    for (var i = 0; i < runes.length; i++) {
      final g = font[_keyAt(runes, i)];
      if (g == null) continue;
      if (top == null || g.top > top) top = g.top;
      if (bottom == null || g.bottom < bottom) bottom = g.bottom;
    }
    if (top == null || bottom == null) return null;
    return (top - bottom) * scaler.scale(fontSize);
  }

  /// How far down (logical px, negative: up) [text] in [style] must move
  /// so its letters sit in the middle of its line box.
  double offset(
    String text,
    TextStyle style,
    TextScaler scaler, [
    StrutStyle? strut,
  ]) {
    final fontSize = style.fontSize;
    if (fontSize == null || text.isEmpty) return 0;
    final key = _key(style);
    final font = _fonts[key];
    if (font == null) {
      prepare(style); // known from the next frame on
      return 0;
    }
    final texts = _texts[key] ??= {};
    final ink = texts.containsKey(text)
        ? texts[text]
        : (texts[text] = _ink(text, font));
    if (texts.length > 4000) {
      final old = texts.keys.take(1000).toList();
      old.forEach(texts.remove);
    }
    if (ink == null) return 0;
    final size = scaler.scale(fontSize);
    // The line's own middle, from the text laid out as it's drawn (the
    // fonts' measured line boxes put Persian a little low: a line takes
    // more than its letters' fonts' boxes; the owner, 2026-10-26).
    final lineKey =
        '$size|${style.height}|${style.leadingDistribution}|'
        '${style.fontWeight}|${strut?.height}|$text';
    final lines = _lines[key] ??= {};
    final middle = lines[lineKey] ??= _lineMiddle(text, style, scaler, strut);
    if (lines.length > 4000) {
      final old = lines.keys.take(1000).toList();
      old.forEach(lines.remove);
    }
    return ink.$1 * size + middle;
  }

  /// Per font: how far below the baseline (logical px) a text's first line
  /// has its middle, by its size, height, weight and text.
  final Map<String, Map<String, double>> _lines = {};

  static double _lineMiddle(
    String text,
    TextStyle style,
    TextScaler scaler,
    StrutStyle? strut,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      strutStyle: strut,
    )..layout();
    // The first line's middle from where the baseline really is. Not from
    // the line's ascent and descent: under a strut those are still its
    // letters' fonts' (Shabnam's for a Persian word), while the strut's font
    // (the first in the list, a digit font) places the baseline. Persian sat
    // low with ManropeNum first, Latin high with VazirNum first (found by
    // OpenTracker in the code it took from here; developer, 2026-11-11).
    final lines = tp.computeLineMetrics();
    final height = tp.height;
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    tp.dispose();
    if (lines.isEmpty) return 0;
    return height / lines.length / 2 - baseline;
  }

  /// Draws every sample character once, in a grid on one picture, and
  /// finds each one's ink.
  static Future<Map<String, _Glyph>> _measure(TextStyle style) async {
    // Room around each one: a tail may reach past its box.
    const size = 48.0, pad = 16.0, rowWidth = 2048.0;
    final samples = _sampleSet();
    final painters = <TextPainter>[];
    final origins = <Offset>[];
    var x = 0.0, y = 0.0, rowHeight = 0.0;
    for (final (_, text) in samples) {
      final tp = TextPainter(
        text: _sampleSpan(
          text,
          style.copyWith(
            fontSize: size,
            height: null,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width.ceilToDouble() + 2 * pad;
      if (x + w > rowWidth) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      painters.add(tp);
      origins.add(Offset(x + pad, y + pad));
      x += w;
      final h = tp.height.ceilToDouble() + 2 * pad;
      if (h > rowHeight) rowHeight = h;
    }
    final width = rowWidth.toInt(), height = (y + rowHeight).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var i = 0; i < painters.length; i++) {
      painters[i].paint(canvas, origins[i]);
    }
    final img = await rec.endRecording().toImage(width, height);
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List(data.offsetInBytes);
    img.dispose();

    final out = <String, _Glyph>{};
    for (var i = 0; i < painters.length; i++) {
      final tp = painters[i];
      final line = tp.computeLineMetrics().first;
      final x0 = (origins[i].dx - pad).toInt(),
          y0 = (origins[i].dy - pad).toInt();
      final w = tp.width.ceil() + 2 * pad.toInt();
      final h = tp.height.ceil() + 2 * pad.toInt();
      final baseline = origins[i].dy + line.baseline;
      int? top, bottom;
      var weight = 0.0, moment = 0.0;
      for (var yy = y0; yy < y0 + h && yy < height; yy++) {
        var row = 0;
        for (var xx = x0; xx < x0 + w && xx < width; xx++) {
          row += bytes[(yy * width + xx) * 4 + 3];
        }
        if (row == 0) continue;
        top ??= yy;
        bottom = yy;
        weight += row;
        moment += row * (yy + .5);
      }
      tp.dispose();
      if (top == null || bottom == null) continue;
      out[samples[i].$1] = _Glyph(
        (baseline - top) / size,
        (baseline - bottom - 1) / size,
        weight / 255 / (size * size),
        (baseline - moment / weight) / size,
        line.ascent / size,
        line.descent / size,
      );
    }
    return out;
  }
}

/// [Text] whose letters sit in the middle of its box ([InkMetrics]): what
/// the app uses for all its text, so text lines up with icons and boxes
/// whatever the font. (A field's typed text isn't this; its placeholder
/// stays a plain [Text] so the two match.)
class InkText extends StatelessWidget {
  const InkText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// The line height a text without one gets (Material's body text's).
  static const double defaultHeight = 1.43;

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    // Every line of a style one height, whatever fonts its letters come from
    // (a line mixing Manrope, Vazirmatn and Shabnam took the tallest ascent
    // and the tallest descent among them: cards of the same kind differed by
    // a dp or two; the owner, 2026-10-28).
    final strut =
        strutStyle ??
        (resolved.fontSize == null
            ? null
            : StrutStyle(
                fontFamily: resolved.fontFamily,
                fontFamilyFallback: resolved.fontFamilyFallback,
                fontSize: resolved.fontSize,
                fontWeight: resolved.fontWeight,
                height: resolved.height ?? defaultHeight,
                leadingDistribution: resolved.leadingDistribution,
                forceStrutHeight: true,
              ));
    final text = Text(
      data,
      style: style,
      strutStyle: strut,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
    Widget placed(BuildContext context) {
      final dy = InkMetrics.instance.offset(
        data,
        resolved,
        textScaler ?? MediaQuery.textScalerOf(context),
        strut,
      );
      // Paint only: the layout keeps the box where it was.
      return dy == 0
          ? text
          : Transform.translate(offset: Offset(0, dy), child: text);
    }

    // Under the app's [InkMetricsScope] (one listener for all texts):
    // rebuilt when a font is measured. Elsewhere, its own listener.
    if (context.dependOnInheritedWidgetOfExactType<InkMetricsScope>() != null) {
      return placed(context);
    }
    return ListenableBuilder(
      listenable: InkMetrics.instance,
      builder: (context, _) => placed(context),
    );
  }
}

/// Above the app (MaterialApp's builder): every [InkText] under it rebuilds
/// when a font gets measured, through this one listener (not one each).
class InkMetricsScope extends InheritedNotifier<InkMetrics> {
  InkMetricsScope({super.key, required super.child})
    : super(notifier: InkMetrics.instance);
}
